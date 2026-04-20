import Foundation

public struct ParsedSubscription: Sendable, Equatable {
    public enum EventKind: String, Sendable {
        case welcome
        case trialStart
        case renewal
        case receipt
        case canceled
        case paused
        case unknown
    }

    public enum BillingInterval: String, Sendable {
        case monthly, annual, unknown
    }

    public let serviceName: String
    public let senderDomain: String
    /// Account identifier within the sender — @handle, billed-to email, or
    /// last-4 of card. Used to split multi-account subs on the same service.
    /// Empty string when nothing distinguishes the account.
    public let accountIdentifier: String
    public let event: EventKind
    public let amount: Decimal?
    public let regularAmount: Decimal?
    public let introPriceEndDate: Date?
    public let billing: BillingInterval
    public let trialEndDate: Date?
    public let sourceMessageID: String
    public let detectedAt: Date

    public init(
        serviceName: String,
        senderDomain: String,
        accountIdentifier: String,
        event: EventKind,
        amount: Decimal?,
        regularAmount: Decimal?,
        introPriceEndDate: Date?,
        billing: BillingInterval,
        trialEndDate: Date?,
        sourceMessageID: String,
        detectedAt: Date
    ) {
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.accountIdentifier = accountIdentifier
        self.event = event
        self.amount = amount
        self.regularAmount = regularAmount
        self.introPriceEndDate = introPriceEndDate
        self.billing = billing
        self.trialEndDate = trialEndDate
        self.sourceMessageID = sourceMessageID
        self.detectedAt = detectedAt
    }
}

public enum SubscriptionParser {
    public static func shouldFetchBody(_ message: GmailMessage) -> Bool {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let domain = senderDomain(from: from)

        if domain.isEmpty { return false }
        if isExcludedBankDomain(domain) { return false }
        if isNoiseSenderDomain(domain) { return false }
        if isExcludedSubject(subject) { return false }
        if isNewsletterPlatform(domain) { return false }
        return hasSubscriptionSignal(subject) || hasSubscriptionSignal(message.snippet ?? "")
    }

    public static func classify(_ message: GmailMessage, now: Date = Date()) -> ParsedSubscription? {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let body = decodedBody(message.payload) ?? message.snippet ?? ""

        let domain = senderDomain(from: from)
        guard !domain.isEmpty else { return nil }
        if isExcludedBankDomain(domain) { return nil }
        if isNoiseSenderDomain(domain) { return nil }
        if isExcludedSubject(subject) { return nil }
        if isNewsletterPlatform(domain) { return nil }
        if isBankBodyContent(body) { return nil }
        if isPaypalPersonalPayment(body: body, subject: subject) { return nil }
        if isDonationContent(body: body) { return nil }

        let event = classifyEvent(subject: subject, body: body)
        let amount = extractPrimaryAmount(body)
        let sentDate = message.sentDate ?? now
        let intro = extractIntroPricing(body: body, sentDate: sentDate)
        let billing = parseBilling(body)
        let trialEnd = parseTrialEndDate(body, reference: now)
        let accountID = extractAccountIdentifier(body: body, domain: domain)

        switch event {
        case .canceled, .paused:
            break
        case .trialStart:
            guard trialEnd != nil || amount != nil else { return nil }
        case .welcome, .renewal, .receipt, .unknown:
            guard let found = amount, found > 0 else { return nil }
        }

        return ParsedSubscription(
            serviceName: serviceName(fromDomain: domain, from: from),
            senderDomain: domain,
            accountIdentifier: accountID,
            event: event,
            amount: amount,
            regularAmount: intro.regularAmount,
            introPriceEndDate: intro.endDate,
            billing: billing,
            trialEndDate: trialEnd,
            sourceMessageID: message.id,
            detectedAt: now
        )
    }
}

// MARK: - Header helpers

private func header(_ headers: [MessageHeader], _ name: String) -> String? {
    headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
}

private func senderDomain(from: String) -> String {
    guard let at = from.lastIndex(of: "@") else { return "" }
    let tail = from[from.index(after: at)...]
    let cleaned = tail.trimmingCharacters(in: CharacterSet(charactersIn: "<>\" "))
    return cleaned.lowercased()
}

private func isNoiseSenderDomain(_ domain: String) -> Bool {
    let personal = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "me.com"]
    return personal.contains(domain)
}

private func serviceName(fromDomain domain: String, from: String) -> String {
    if let displayName = parseDisplayName(from) { return displayName }
    let root = domain
        .replacingOccurrences(of: "mail.", with: "")
        .replacingOccurrences(of: "e.", with: "")
        .replacingOccurrences(of: "email.", with: "")
        .replacingOccurrences(of: "notifications.", with: "")
        .replacingOccurrences(of: "noreply.", with: "")
    let label = root.split(separator: ".").first.map(String.init) ?? root
    return label.prefix(1).uppercased() + label.dropFirst()
}

private func parseDisplayName(_ from: String) -> String? {
    guard let angle = from.firstIndex(of: "<") else { return nil }
    let name = from[..<angle]
        .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    return name.isEmpty ? nil : name
}

// MARK: - Bank / card exclusions

/// Domains that are always excluded — any email from here is guaranteed not a subscription receipt.
private let bankDomainSuffixes: [String] = [
    "chase.com",
    "bankofamerica.com",
    "americanexpress.com", "aexp.com",
    "citi.com", "citibank.com",
    "capitalone.com", "capitalone.email",
    "discover.com",
    "wellsfargo.com",
    "usbank.com",
    "ally.com",
    "sofi.com",
    "schwab.com",
    "fidelity.com", "fmr.com",
    "venmo.com",
    "cu.org", "fcu.org", "creditunion.org",
]

/// Brokerages / processors that LOOK bank-like but actually route real subscription receipts.
/// Don't blanket-exclude these by domain — let subject/body filters handle the real bank alerts.
private let bankAdjacentDomains: Set<String> = [
    "paypal.com", "service.paypal.com",
    "stripe.com",
    "robinhood.com",
    "chime.com",
    "apple.com", "email.apple.com",
]

private func isExcludedBankDomain(_ domain: String) -> Bool {
    if bankAdjacentDomains.contains(domain) { return false }
    return bankDomainSuffixes.contains { domain == $0 || domain.hasSuffix("." + $0) }
}

private let newsletterPlatformDomains: Set<String> = [
    "substack.com", "beehiiv.com", "mailchimp.com", "mc.sendgrid.net",
    "constantcontact.com", "convertkit.com", "campaignmonitor.com",
    "mailerlite.com", "moosend.com",
]

private func isNewsletterPlatform(_ domain: String) -> Bool {
    newsletterPlatformDomains.contains { domain == $0 || domain.hasSuffix("." + $0) }
}

private let bankSubjectPatterns: [String] = [
    #"statement is (now )?available"#,
    #"statement is ready"#,
    #"your .+ statement"#,
    #"transaction (alert|notification|posted)"#,
    #"(purchase|debit|credit|withdrawal|deposit) alert"#,
    #"payment (received|posted|scheduled|due)"#,
    #"your (minimum )?payment is due"#,
    #"autopay (scheduled|processed)"#,
    #"balance (alert|summary|notification)"#,
    #"low balance|available balance"#,
    #"direct deposit (received|posted)"#,
    #"card (was )?(used|charged|declined)"#,
    #"unusual (activity|sign.?in)"#,
    #"account (activity|summary|alert)"#,
    #"(wire|ach|zelle) (transfer|payment|received|sent)"#,
    #"fraud alert|security alert"#,
    #"new (sign.?in|device|login)"#,
    // Shipping
    #"has shipped|shipping confirmation|out for delivery|tracking number|package arrived"#,
    // Donations
    #"donation receipt|gift receipt|thank you for your (donation|gift)"#,
]

private let compiledBankSubjectRegex: NSRegularExpression? = {
    let combined = bankSubjectPatterns.joined(separator: "|")
    return try? NSRegularExpression(pattern: combined, options: [.caseInsensitive])
}()

private func isExcludedSubject(_ subject: String) -> Bool {
    guard let regex = compiledBankSubjectRegex else { return false }
    let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
    return regex.firstMatch(in: subject, options: [], range: range) != nil
}

/// Single-hit body phrases that indicate a bank alert, not a subscription.
private let bankBodySingleHitPhrases: [String] = [
    "available balance",
    "current balance as of",
    "minimum payment due",
    "statement closing date",
    "statement balance",
    "posted to your account",
    "autopay is scheduled",
    "has been deposited into your",
    "was withdrawn from your",
    "interest charge",
    "routing number",
    "wire transfer",
    "zelle payment",
    "ach transfer",
    "direct deposit",
    "credit limit",
    "available credit",
    "transaction posted",
    "pending transaction",
]

private func isBankBodyContent(_ body: String) -> Bool {
    let lower = body.lowercased()
    return bankBodySingleHitPhrases.contains { lower.contains($0) }
}

/// PayPal / Venmo personal payments — "You sent $X to Jane Doe" / "You received $X from John".
/// Subscription receipts through PayPal have markers like "Invoice ID" or "Subscription ID".
private func isPaypalPersonalPayment(body: String, subject: String) -> Bool {
    let lower = body.lowercased()
    let subjLower = subject.lowercased()

    let hasSubscriptionMarker = lower.contains("invoice id") ||
        lower.contains("subscription id") ||
        lower.contains("recurring payment") ||
        lower.contains("automatic payment to") ||
        lower.contains("billing agreement")
    if hasSubscriptionMarker { return false }

    let personalMarkers = [
        "you sent ", "you received ", "you requested ",
        "note from sender", "request money",
    ]
    return personalMarkers.contains { subjLower.contains($0) || lower.contains($0) }
}

private func isDonationContent(body: String) -> Bool {
    let lower = body.lowercased()
    let hits = ["donation", "tithe", "501(c)", "nonprofit", "charitable contribution"]
    return hits.contains { lower.contains($0) }
}

// MARK: - Subscription signals

private let subscriptionSignalTerms: [String] = [
    "subscription", "subscribed", "renewal", "renew", "auto-renew", "auto renew",
    "receipt", "invoice", "billing", "billed", "charged",
    "membership", "premium", "plan", "upgrade",
    "welcome", "confirmation", "trial", "free trial",
    "canceled", "cancelled", "paused",
    "thanks for subscribing", "your order",
]

private func hasSubscriptionSignal(_ text: String) -> Bool {
    let lower = text.lowercased()
    return subscriptionSignalTerms.contains { lower.contains($0) }
}

private func classifyEvent(subject: String, body: String) -> ParsedSubscription.EventKind {
    let text = (subject + " " + body).lowercased()
    if text.contains("cancel") { return .canceled }
    if text.contains("paused") || text.contains("on hold") { return .paused }
    if text.contains("free trial") || text.contains("trial started") ||
       text.contains("your trial") || text.contains("trial period") {
        return .trialStart
    }
    if text.contains("renew") || text.contains("auto-renew") || text.contains("auto renew") {
        return .renewal
    }
    if text.contains("receipt") || text.contains("invoice") || text.contains("payment received") ||
       text.contains("you paid") || text.contains("amount charged") || text.contains("billed") {
        return .receipt
    }
    if text.contains("welcome") || text.contains("thanks for subscribing") || text.contains("confirmation") {
        return .welcome
    }
    return .unknown
}

// MARK: - Body decoding

private func decodedBody(_ payload: MessagePayload?) -> String? {
    guard let payload else { return nil }
    if let data = payload.body?.data, let decoded = base64URLDecode(data) { return decoded }
    if let parts = payload.parts {
        for part in parts {
            if let nested = decodedBody(part) { return nested }
        }
    }
    return nil
}

private func base64URLDecode(_ input: String) -> String? {
    var s = input.replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s.append("=") }
    guard let data = Data(base64Encoded: s) else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Account identifier extraction

private let handleDomains: Set<String> = [
    "x.com", "twitter.com", "reddit.com", "substack.com", "github.com",
    "spotify.com", "discord.com", "twitch.tv", "medium.com",
]

private func extractAccountIdentifier(body: String, domain: String) -> String {
    let isHandleDomain = handleDomains.contains { domain == $0 || domain.hasSuffix("." + $0) }

    if isHandleDomain, let handle = extractHandle(body) {
        return handle.lowercased()
    }
    if let email = extractBilledToEmail(body, excluding: domain) {
        return email.lowercased()
    }
    if let last4 = extractLast4(body) {
        return last4
    }
    return ""
}

private func extractHandle(_ body: String) -> String? {
    let pattern = #"(?<![A-Z0-9._%+\-])@([A-Z0-9_]{2,15})\b(?!\.[A-Z])"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    guard let match = regex.firstMatch(in: body, options: [], range: range),
          match.numberOfRanges > 1,
          let handleRange = Range(match.range(at: 1), in: body)
    else { return nil }
    return String(body[handleRange])
}

private func extractBilledToEmail(_ body: String, excluding senderDomain: String) -> String? {
    let pattern = #"(?:billed\s*to|account|for|email|subscriber|member|apple\s*id|google\s*account)\s*[:\-]?\s*([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let matches = regex.matches(in: body, options: [], range: range)
    for match in matches {
        guard match.numberOfRanges > 1,
              let emailRange = Range(match.range(at: 1), in: body) else { continue }
        let email = String(body[emailRange])
        // Skip the merchant's own domain (noreply@x.com etc.)
        let emailDomain = email.split(separator: "@").last.map(String.init)?.lowercased() ?? ""
        if emailDomain != senderDomain && !senderDomain.hasSuffix(emailDomain) {
            return email
        }
    }
    return nil
}

private func extractLast4(_ body: String) -> String? {
    let pattern = #"(?:ending\s*(?:in|with)|•••• ?|\*{2,}\s*)(\d{4})\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    guard let match = regex.firstMatch(in: body, options: [], range: range),
          match.numberOfRanges > 1,
          let last4Range = Range(match.range(at: 1), in: body)
    else { return nil }
    return String(body[last4Range])
}

// MARK: - Amount extraction

private func extractPrimaryAmount(_ body: String) -> Decimal? {
    let lines = body.components(separatedBy: .newlines)
    let preferredLabels = [
        "total charged", "amount charged", "total paid", "you paid",
        "grand total", "amount due", "order total", "total amount", "total:",
        "charged to your card", "payment amount",
    ]
    let avoidLabels = [
        "subtotal", "tax", "discount", "credit", "savings", "refund",
        "you saved", "promo", "shipping",
    ]

    for line in lines {
        let lower = line.lowercased()
        guard preferredLabels.contains(where: { lower.contains($0) }) else { continue }
        if avoidLabels.contains(where: { lower.contains($0) }) { continue }
        if let amount = firstDollarAmount(line), amount > 0 { return amount }
    }

    for line in lines {
        let lower = line.lowercased()
        if avoidLabels.contains(where: { lower.contains($0) }) { continue }
        let cadenceSignal = ["/month", "/mo", "per month", "/year", "/yr", "per year", "monthly", "yearly"]
        guard cadenceSignal.contains(where: { lower.contains($0) }) else { continue }
        if let amount = firstDollarAmount(line), amount > 0 { return amount }
    }

    return nil
}

private func firstDollarAmount(_ text: String) -> Decimal? {
    let pattern = #"(?:US\$|USD\s*|\$)\s*(\d+(?:\.\d{1,2})?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: text)
    else { return nil }
    return Decimal(string: String(text[valueRange]))
}

// MARK: - Intro pricing (duration-based primary, explicit-date secondary)

private func extractIntroPricing(
    body: String,
    sentDate: Date
) -> (regularAmount: Decimal?, endDate: Date?) {
    let lower = body.lowercased()
    let promoSignals = [
        "first month", "first 2 months", "first two months", "first 3 months",
        "first three months", "first 6 months", "first six months",
        "first 12 months", "first twelve months", "first year",
        "for the first", "introductory price", "promotional rate",
        "intro price", "then $", "after that your price", "after your trial",
    ]
    guard promoSignals.contains(where: { lower.contains($0) }) else { return (nil, nil) }

    let regular = extractThenAmount(body)
    let endDate = extractIntroEndDate(body: body, sentDate: sentDate)
    return (regular, endDate)
}

private func extractThenAmount(_ body: String) -> Decimal? {
    let pattern = #"then\s+(?:US\$|USD\s*|\$)\s*(\d+(?:\.\d{1,2})?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    guard let match = regex.firstMatch(in: body, options: [], range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: body)
    else { return nil }
    return Decimal(string: String(body[valueRange]))
}

/// Tries (in order): duration offset from sent date, then explicit end-date regex,
/// then gives up. No more "first future date in the whole body" heuristic.
private func extractIntroEndDate(body: String, sentDate: Date) -> Date? {
    if let offset = extractPromoDuration(body) {
        return Calendar.current.date(byAdding: offset.component, value: offset.value, to: sentDate)
    }
    return extractExplicitEndDate(body)
}

private struct DurationOffset {
    let component: Calendar.Component
    let value: Int
}

private func extractPromoDuration(_ body: String) -> DurationOffset? {
    let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12,
    ]

    let pattern = #"(?:for\s+the\s+)?first\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(day|week|month|year)s?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    guard let match = regex.firstMatch(in: body, options: [], range: range),
          match.numberOfRanges > 2,
          let numRange = Range(match.range(at: 1), in: body),
          let unitRange = Range(match.range(at: 2), in: body)
    else { return nil }

    let numStr = String(body[numRange]).lowercased()
    let value = Int(numStr) ?? numberWords[numStr] ?? 0
    guard value > 0 else { return nil }

    let component: Calendar.Component
    switch String(body[unitRange]).lowercased() {
    case "day": component = .day
    case "week": component = .weekOfYear
    case "month": component = .month
    case "year": component = .year
    default: return nil
    }
    return DurationOffset(component: component, value: value)
}

private func extractExplicitEndDate(_ body: String) -> Date? {
    let anchorPatterns: [String] = [
        #"(?:intro(?:ductory)?|promotional|discounted)\s+(?:price|pricing|rate|offer)\s+(?:ends?|expires?)\s+(?:on\s+)?(.{0,40})"#,
        #"until\s+(.{0,40}?),?\s+then"#,
        #"after\s+(.{0,40}?)\s+(?:your|the)\s+(?:price|rate|subscription)"#,
    ]

    for pattern in anchorPatterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, options: [], range: range),
              match.numberOfRanges > 1,
              let tailRange = Range(match.range(at: 1), in: body) else { continue }
        let tail = String(body[tailRange])
        if let date = detectFirstDate(in: tail) { return date }
    }
    return nil
}

private func detectFirstDate(in text: String) -> Date? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector?.matches(in: text, options: [], range: range).compactMap { $0.date }.first
}

// MARK: - Billing / trial

private func parseBilling(_ body: String) -> ParsedSubscription.BillingInterval {
    let lower = body.lowercased()
    if lower.contains("per year") || lower.contains("/year") || lower.contains("/yr") ||
       lower.contains("annual") || lower.contains("yearly") {
        return .annual
    }
    if lower.contains("per month") || lower.contains("/month") || lower.contains("/mo") ||
       lower.contains("monthly") {
        return .monthly
    }
    return .unknown
}

private func parseTrialEndDate(_ body: String, reference: Date) -> Date? {
    let lower = body.lowercased()
    guard lower.contains("trial") || lower.contains("free until") else { return nil }

    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let matches = detector?.matches(in: body, options: [], range: range) ?? []
    return matches.compactMap { $0.date }.first { $0 > reference }
}
