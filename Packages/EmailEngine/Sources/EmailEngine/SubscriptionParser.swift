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
    /// Metadata-only pre-filter. Returns true when the email is worth pulling
    /// the body for. Keeps ScanCoordinator from wasting API calls on obvious junk.
    public static func shouldFetchBody(_ message: GmailMessage) -> Bool {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let domain = senderDomain(from: from)
        if domain.isEmpty || isNoiseSenderDomain(domain) { return false }
        if isExcludedCategory(subject: subject, domain: domain, body: nil) { return false }
        return hasSubscriptionSignal(subject) || hasSubscriptionSignal(message.snippet ?? "")
    }

    /// Full classification. Returns nil when the email doesn't meet the bar
    /// for being surfaced as a real subscription (no amount, excluded category,
    /// phantom trial, etc.). Caller treats nil as "drop silently."
    public static func classify(_ message: GmailMessage, now: Date = Date()) -> ParsedSubscription? {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let body = decodedBody(message.payload) ?? message.snippet ?? ""

        let domain = senderDomain(from: from)
        guard !domain.isEmpty, !isNoiseSenderDomain(domain) else { return nil }
        if isExcludedCategory(subject: subject, domain: domain, body: body) { return nil }

        let event = classifyEvent(subject: subject, body: body)
        let amount = extractPrimaryAmount(body)
        let (regularAmount, introEnd) = extractIntroPricing(body, reference: now)
        let billing = parseBilling(body)
        let trialEnd = parseTrialEndDate(body, reference: now)

        // Hard rule: require evidence of a real paid subscription.
        // Either a charge amount, or a trial that clearly has end dating.
        switch event {
        case .canceled, .paused:
            break // Keep — needed to update existing rows even without a new charge
        case .trialStart:
            guard trialEnd != nil || amount != nil else { return nil }
        case .welcome, .renewal, .receipt, .unknown:
            guard let found = amount, found > 0 else { return nil }
        }

        return ParsedSubscription(
            serviceName: serviceName(fromDomain: domain, from: from),
            senderDomain: domain,
            event: event,
            amount: amount,
            regularAmount: regularAmount,
            introPriceEndDate: introEnd,
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

// MARK: - Category exclusions

private let bankNewsletterDomains: Set<String> = [
    // Newsletter platforms
    "substack.com", "beehiiv.com", "mailchimp.com", "mc.sendgrid.net",
    "constantcontact.com", "convertkit.com", "campaignmonitor.com",
    "mailerlite.com", "moosend.com",
]

private let excludedSubjectPhrases: [String] = [
    // Bank / card transaction alerts
    "transaction alert", "fraud alert", "account alert", "deposit alert",
    "withdrawal alert", "purchase alert", "balance alert", "debit alert",
    "your card was used", "payment posted", "statement available",
    "credit card statement", "minimum payment", "payment due",
    // Shipping
    "has shipped", "shipping confirmation", "delivery update",
    "out for delivery", "tracking number", "package arrived",
    // Donations
    "donation receipt", "tithe", "contribution receipt", "gift receipt",
    "thank you for your donation", "thank you for your gift",
]

private let excludedSenderHints: [String] = [
    "newsletter@", "digest@", "daily@", "weekly@",
]

private func isExcludedCategory(subject: String, domain: String, body: String?) -> Bool {
    let subjectLower = subject.lowercased()
    let domainLower = domain.lowercased()

    if bankNewsletterDomains.contains(domainLower) { return true }
    if excludedSenderHints.contains(where: { subjectLower.contains($0) }) { return true }
    if excludedSubjectPhrases.contains(where: { subjectLower.contains($0) }) { return true }

    if let body {
        let bodyLower = body.lowercased()
        let donationSignals = ["donation", "tithe", "501(c)", "nonprofit", "charitable contribution"]
        if donationSignals.contains(where: { bodyLower.contains($0) }) { return true }

        // Bank statement / credit card bill — if body talks about "available balance"
        // or "interest charge" without a subscription amount line, drop it.
        let bankSignals = ["available balance", "posted to your account", "current balance",
                          "interest charged", "minimum payment due", "statement closing date"]
        let bankHitCount = bankSignals.filter { bodyLower.contains($0) }.count
        if bankHitCount >= 2 { return true }
    }

    return false
}

// MARK: - Signals

private let subscriptionSignalTerms: [String] = [
    "subscription", "subscribed", "renewal", "renew", "auto-renew", "auto renew",
    "receipt", "invoice", "payment", "billing", "billed", "charged",
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

// MARK: - Amount extraction

/// Finds the primary charged amount. Prefers labeled totals over the first
/// dollar sign in the body. Ignores lines that look like subtotals, tax, credits,
/// or savings.
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

    // Pass 1: labeled totals
    for line in lines {
        let lower = line.lowercased()
        guard preferredLabels.contains(where: { lower.contains($0) }) else { continue }
        if avoidLabels.contains(where: { lower.contains($0) }) { continue }
        if let amount = firstDollarAmount(line), amount > 0 { return amount }
    }

    // Pass 2: any line with a per-month/per-year cadence signal
    for line in lines {
        let lower = line.lowercased()
        if avoidLabels.contains(where: { lower.contains($0) }) { continue }
        let cadenceSignal = ["/month", "/mo", "per month", "/year", "/yr", "per year", "monthly", "yearly"]
        guard cadenceSignal.contains(where: { lower.contains($0) }) else { continue }
        if let amount = firstDollarAmount(line), amount > 0 { return amount }
    }

    // No confident anchor — return nil rather than guessing.
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

// MARK: - Intro pricing

private func extractIntroPricing(_ body: String, reference: Date) -> (regularAmount: Decimal?, endDate: Date?) {
    let lower = body.lowercased()
    let promoSignals = ["first month", "first 2 months", "first two months", "for the first",
                       "introductory price", "promotional rate", "intro price", "then $",
                       "after that", "afterwards"]
    guard promoSignals.contains(where: { lower.contains($0) }) else { return (nil, nil) }

    // Try to find "then $X/month" — that's the regular price.
    let thenPattern = #"then\s+(?:US\$|USD\s*|\$)\s*(\d+(?:\.\d{1,2})?)"#
    let regular: Decimal? = {
        guard let regex = try? NSRegularExpression(pattern: thenPattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: body)
        else { return nil }
        return Decimal(string: String(body[valueRange]))
    }()

    // End date: use the first future date in the body as a heuristic.
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let endDate = detector?.matches(in: body, options: [], range: range)
        .compactMap { $0.date }
        .first { $0 > reference }

    return (regular, endDate)
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
