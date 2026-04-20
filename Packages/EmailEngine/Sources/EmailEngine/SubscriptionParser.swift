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
    /// True when the email shows a card/PayPal/billing method on file and an
    /// automatic future charge. Gates `.trialStart` — "no credit card needed"
    /// trials (Granola/Loom/Zapier) never reach Detected.
    public let willAutoCharge: Bool
    public let sourceMessageID: String
    public let detectedAt: Date
    /// 0.0–1.0. ≥0.7 = "Detected" tier, 0.4–0.7 = "Review these" tier, <0.4 dropped.
    public let confidence: Double

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
        willAutoCharge: Bool,
        sourceMessageID: String,
        detectedAt: Date,
        confidence: Double
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
        self.willAutoCharge = willAutoCharge
        self.sourceMessageID = sourceMessageID
        self.detectedAt = detectedAt
        self.confidence = confidence
    }
}

public enum ClassificationRejection: String, Sendable {
    case noDomain
    case bankDomain
    case noiseSenderDomain
    case excludedSubject
    case newsletterPlatform
    case bankBodyContent
    case paypalPersonalPayment
    case oneTimeDonation
    case missingAmount
    case missingRecurrenceEvidence
    case missingTrialInfo
    case trialNoCardOnFile
}

public enum SubscriptionParser {
    public static func shouldFetchBody(_ message: GmailMessage) -> Bool {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let domain = senderDomain(from: from)

        if domain.isEmpty {
            logPreFilter(reason: "noDomain", subject: subject, domain: "", messageID: message.id)
            return false
        }
        if isExcludedBankDomain(domain) {
            logPreFilter(reason: "bankDomain", subject: subject, domain: domain, messageID: message.id)
            return false
        }
        if isNoiseSenderDomain(domain) {
            logPreFilter(reason: "noiseSenderDomain", subject: subject, domain: domain, messageID: message.id)
            return false
        }
        if isExcludedSubject(subject) {
            logPreFilter(reason: "excludedSubject", subject: subject, domain: domain, messageID: message.id)
            return false
        }
        if isNewsletterPlatform(domain) {
            logPreFilter(reason: "newsletterPlatform", subject: subject, domain: domain, messageID: message.id)
            return false
        }
        let passesSignal = hasSubscriptionSignal(subject) || hasSubscriptionSignal(message.snippet ?? "")
        if !passesSignal {
            logPreFilter(reason: "noSubscriptionSignal", subject: subject, domain: domain, messageID: message.id)
        }
        return passesSignal
    }

    public static func classify(_ message: GmailMessage, now: Date = Date()) -> ParsedSubscription? {
        switch classifyWithDiagnostics(message, now: now) {
        case .success(let parsed): return parsed
        case .rejected(let reason, let subject, let domain):
            logRejection(reason: reason, subject: subject, domain: domain, messageID: message.id)
            return nil
        }
    }

    public enum ClassifyResult {
        case success(ParsedSubscription)
        case rejected(reason: ClassificationRejection, subject: String, domain: String)
    }

    public static func classifyWithDiagnostics(_ message: GmailMessage, now: Date = Date()) -> ClassifyResult {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let body = decodedBody(message.payload) ?? message.snippet ?? ""

        let domain = senderDomain(from: from)
        guard !domain.isEmpty else {
            return .rejected(reason: .noDomain, subject: subject, domain: "")
        }
        if isExcludedBankDomain(domain) {
            return .rejected(reason: .bankDomain, subject: subject, domain: domain)
        }
        if isNoiseSenderDomain(domain) {
            return .rejected(reason: .noiseSenderDomain, subject: subject, domain: domain)
        }
        if isExcludedSubject(subject) {
            return .rejected(reason: .excludedSubject, subject: subject, domain: domain)
        }
        if isNewsletterPlatform(domain) {
            return .rejected(reason: .newsletterPlatform, subject: subject, domain: domain)
        }
        if isBankBodyContent(body) {
            return .rejected(reason: .bankBodyContent, subject: subject, domain: domain)
        }
        if isPaypalPersonalPayment(body: body, subject: subject) {
            return .rejected(reason: .paypalPersonalPayment, subject: subject, domain: domain)
        }

        let event = classifyEvent(subject: subject, body: body, trialEndDate: parseTrialEndDate(body, reference: now))
        let amount = extractPrimaryAmount(body)
        let sentDate = message.sentDate ?? now
        let intro = extractIntroPricing(body: body, sentDate: sentDate)
        let billing = parseBilling(body)
        let trialEnd = parseTrialEndDate(body, reference: now)
        let accountID = extractAccountIdentifier(body: body, domain: domain)
        let strongCharge = hasChargeConfirmation(subject: subject, body: body)
        let weakRecurrence = hasRecurrenceEvidence(subject: subject, body: body)
        let marketingCTA = isMarketingCTA(subject: subject)
        let willAutoCharge = detectAutoCharge(subject: subject, body: body)

        // One-time donation receipts are filtered; recurring donations (like a
        // monthly sponsorship) have recurrence markers and are kept.
        if isDonationContent(body: body) && !strongCharge {
            return .rejected(reason: .oneTimeDonation, subject: subject, domain: domain)
        }

        // Pure marketing CTAs ("Get Premium for $9.99", "Unlock Pro") are killed
        // even if the body mentions "/mo" or "cancel anytime" — those phrases
        // show up in upgrade footers too.
        if marketingCTA && !strongCharge {
            return .rejected(reason: .missingRecurrenceEvidence, subject: subject, domain: domain)
        }

        switch event {
        case .canceled, .paused:
            break
        case .trialStart:
            guard trialEnd != nil || amount != nil else {
                return .rejected(reason: .missingTrialInfo, subject: subject, domain: domain)
            }
            // Subly is ONLY interested in trials that will charge the user if
            // they don't cancel. "No credit card needed" trials (Granola/Loom/
            // Zapier) get dropped here — they're not recurring revenue risks.
            guard willAutoCharge else {
                return .rejected(reason: .trialNoCardOnFile, subject: subject, domain: domain)
            }
        case .renewal:
            guard let found = amount, found > 0 else {
                return .rejected(reason: .missingAmount, subject: subject, domain: domain)
            }
        case .welcome, .receipt, .unknown:
            guard let found = amount, found > 0 else {
                return .rejected(reason: .missingAmount, subject: subject, domain: domain)
            }
            // Require either a strong charge-confirmation phrase, OR weak
            // recurrence evidence combined with a receipt-shaped subject.
            // MLB / Kahoot / MyPanera marketing emails fail this gate because
            // their subjects are CTAs ("Try Premium for $X") — not receipts.
            let subjectLooksLikeReceipt = receiptSubjectSignal(subject)
            guard strongCharge || (weakRecurrence && subjectLooksLikeReceipt) else {
                return .rejected(reason: .missingRecurrenceEvidence, subject: subject, domain: domain)
            }
        }

        let confidence = scoreConfidence(
            event: event,
            strongCharge: strongCharge,
            weakRecurrence: weakRecurrence,
            marketingCTA: marketingCTA,
            receiptSubject: receiptSubjectSignal(subject),
            hasAmount: amount != nil,
            hasTrialEnd: trialEnd != nil,
            hasAccountID: !accountID.isEmpty,
            knownSender: isKnownSubscriptionSender(domain)
        )

        let parsed = ParsedSubscription(
            serviceName: serviceName(fromDomain: domain, from: from),
            senderDomain: domain,
            accountIdentifier: accountID,
            event: event,
            amount: amount,
            regularAmount: intro.regularAmount,
            introPriceEndDate: intro.endDate,
            billing: billing,
            trialEndDate: trialEnd,
            willAutoCharge: willAutoCharge,
            sourceMessageID: message.id,
            detectedAt: now,
            confidence: confidence
        )
        logAccept(
            domain: domain,
            subject: subject,
            event: "\(event)",
            amount: amount.map { "\($0)" } ?? "nil",
            messageID: message.id
        )
        return .success(parsed)
    }
}

private func logRejection(reason: ClassificationRejection, subject: String, domain: String, messageID: String) {
    let trimmedSubject = subject.prefix(80)
    print("[Subly parser] rejected id=\(messageID) domain=\(domain) reason=\(reason.rawValue) subject=\"\(trimmedSubject)\"")
}

private func logPreFilter(reason: String, subject: String, domain: String, messageID: String) {
    let trimmedSubject = subject.prefix(80)
    print("[Subly pre-filter] skipped id=\(messageID) domain=\(domain) reason=\(reason) subject=\"\(trimmedSubject)\"")
}

private func logAccept(domain: String, subject: String, event: String, amount: String, messageID: String) {
    let trimmedSubject = subject.prefix(80)
    print("[Subly parser] accepted id=\(messageID) domain=\(domain) event=\(event) amount=\(amount) subject=\"\(trimmedSubject)\"")
}

/// **Strong** evidence of an actual charge. These phrases virtually never appear
/// in marketing emails — they appear in receipts, renewal confirmations, and
/// payment notifications. A single hit here is enough to classify as a real sub.
private func hasChargeConfirmation(subject: String, body: String) -> Bool {
    let text = (subject + " " + body).lowercased()
    let phrases = [
        "you were charged", "you've been charged", "you have been charged",
        "payment of $", "payment of us$", "payment of usd",
        "your card was charged", "your card has been charged",
        "successfully charged", "charge of $", "charged $",
        "receipt for your subscription", "receipt from",
        "subscription renewed", "has been renewed",
        "auto-renewed", "automatically renewed",
        "payment received", "payment confirmation",
        "thanks for your payment", "thank you for your payment",
        "invoice paid", "invoice for",
        "your subscription has renewed", "your membership has renewed",
        "next billing date", "next charge date",
        "order confirmation for your subscription",
    ]
    return phrases.contains { text.contains($0) }
}

/// True when the email shows a billing method on file and an automatic future
/// charge. Used to gate `.trialStart` — Subly only cares about trials that
/// will charge the user if they forget to cancel.
///
/// Accept signals (any → true, unless a hard negative trips first):
///   - "will be charged to [card/PayPal/your card]"
///   - "starting [date], your payment of $X will be charged"
///   - "we'll charge [card/the card on file]"
///   - "automatically [every N] month(s)/year(s)" or "every 1 month"
///   - "your subscription will continue until you cancel"
///   - A receipt that was already charged (strongCharge==true is handled by
///     the receipt path, not here — this function is for trial/welcome gating).
/// Hard negatives (any → false, overrides positives):
///   - "no credit card needed", "no credit card required", "no payment info"
///   - "automatically switch to free", "downgrade to free"
///   - "add payment details by [date] to continue"
///   - "add a payment method" / "add payment method to keep" (card NOT on file)
///
/// Fixture expectations (for the future test target):
///   M365 Personal — "Starting Monday, October 19, 2026, your payment of
///     USD 4.99 … will be charged to PayPal automatically every 1 month."
///     → TRUE
///   Anthropic Stripe receipt $20 Mar 11 → TRUE (strongCharge path also hits)
///   Google Cloud $300 credit trial — card-on-file + auto-charge after trial
///     → TRUE
///   Granola Business — "The trial ends automatically when it expires, no
///     credit card needed." → FALSE
///   Loom — "no payment info required" → FALSE
///   Zapier — free trial with no card → FALSE
private func detectAutoCharge(subject: String, body: String) -> Bool {
    let text = (subject + " " + body).lowercased()

    let hardNegatives = [
        "no credit card needed", "no credit card required",
        "no payment info", "no payment info required",
        "no payment method required", "no payment required",
        "without a credit card",
        "automatically switch to free", "automatically switch to the free",
        "downgrade to free", "downgrade to the free",
        "will switch to the free plan", "will switch to free plan",
        "revert to the free plan", "revert to free plan",
        "add payment details by", "add payment method by",
        "add a payment method to continue", "add a payment method to keep",
        "add a payment method to avoid",
        "to continue using", // "add payment method to continue using" territory
    ]
    // "to continue using" is fuzzy on its own — only treat as negative when
    // paired with an add-payment prompt.
    let addPaymentPhrases = [
        "add a payment method", "add payment method",
        "add a credit card", "add a card",
    ]
    let hasAddPaymentPrompt = addPaymentPhrases.contains { text.contains($0) }
    if hasAddPaymentPrompt { return false }

    for neg in hardNegatives where neg != "to continue using" {
        if text.contains(neg) { return false }
    }

    let positives = [
        "will be charged to", "will be automatically charged",
        "we'll charge", "we will charge",
        "your card will be charged", "your card on file will be charged",
        "charged to paypal automatically",
        "charged automatically every",
        "automatically every 1 month", "automatically every month",
        "automatically every 1 year", "automatically every year",
        "billed automatically",
        "continue until you cancel", "until you cancel",
        "your payment of $", "your payment of us$", "your payment of usd",
        "starting ", // weak on its own — paired below with a charge verb
    ]

    // "starting " is too weak alone (newsletters say "starting next week").
    // Require it to co-occur with a charge verb in the same body.
    let startingPaired = text.contains("starting ") &&
        (text.contains("will be charged") ||
         text.contains("your payment of") ||
         text.contains("charged to"))
    if startingPaired { return true }

    for pos in positives where pos != "starting " {
        if text.contains(pos) { return true }
    }
    return false
}

/// **Weak** recurrence markers. These appear in BOTH real subscription receipts
/// AND marketing emails. Never accept on weak alone — combine with a
/// receipt-shaped subject or a strong charge-confirmation phrase.
private func hasRecurrenceEvidence(subject: String, body: String) -> Bool {
    let text = (subject + " " + body).lowercased()
    let markers = [
        "auto-renew", "auto renew", "will renew", "renews on", "renews automatically",
        "next billing", "next charge", "next payment", "next renewal",
        "recurring", "recurring payment", "recurring billing",
        "subscription renews", "your subscription will",
        "billed monthly", "billed annually", "billed yearly",
        "per month", "per year", "/month", "/year", "/mo", "/yr",
        "monthly subscription", "annual subscription", "yearly subscription",
        "membership fee", "monthly membership", "annual membership",
        "trial period", "trial ends",
        "cancel your subscription", "manage your subscription",
    ]
    return markers.contains { text.contains($0) }
}

/// True when the subject line looks like a real receipt/renewal/welcome —
/// not a marketing CTA. Gate combines with weak recurrence markers.
private func receiptSubjectSignal(_ subject: String) -> Bool {
    let subj = subject.lowercased()
    let signals = [
        "receipt", "invoice", "renewal", "renewed", "auto-renew", "auto renew",
        "payment", "you paid", "amount charged", "thanks for your payment",
        "subscription confirmation", "subscription renewed",
        "welcome to", "thanks for subscribing", "you're now subscribed",
        "your order", "order confirmation",
    ]
    return signals.contains { subj.contains($0) }
}

/// True when the subject is a pure marketing/upgrade CTA. These should be
/// rejected even if the body contains recurrence markers.
private func isMarketingCTA(subject: String) -> Bool {
    let subj = subject.lowercased()
    let ctaPhrases = [
        "get premium", "try premium", "unlock premium",
        "get pro", "try pro", "unlock pro", "go pro",
        "upgrade to", "upgrade now", "upgrade today",
        "join premium", "join pro", "join now",
        "save ", "save up to", "limited time",
        "don't miss", "last chance", "ends soon",
        "for only $", "for just $", "only $",
        "free for", "try free", "start free",
        "special offer", "exclusive offer", "member exclusive",
        // Fantasy / contest / newsletter CTAs
        "morning lineup", "daily fantasy", "pick 'em", "contest",
        // Loyalty promos
        "your coffee for", "free drink", "buy one get",
    ]
    let hasCTA = ctaPhrases.contains { subj.contains($0) }
    // Receipt-shaped subjects override marketing suspicion ("Your receipt for
    // premium" isn't a CTA even though it contains "premium").
    return hasCTA && !receiptSubjectSignal(subject)
}

/// Known subscription senders — boosts confidence. Not a whitelist; unknown
/// senders can still reach Detected with a strong charge-confirmation phrase.
private let knownSubscriptionDomains: Set<String> = [
    "apple.com", "email.apple.com", "itunes.com",
    "google.com", "mail.google.com", "accounts.google.com", "payments.google.com",
    "amazon.com", "primevideo.com", "kindle.com",
    "netflix.com",
    "spotify.com",
    "hulu.com",
    "disneyplus.com", "disney.com",
    "youtube.com",
    "anthropic.com",
    "openai.com",
    "perplexity.ai",
    "nytimes.com", "wsj.com", "economist.com",
    "stripe.com", "paddle.com", "paddle.net",
    "paypal.com", "service.paypal.com",
    "github.com",
    "dropbox.com",
    "notion.so",
    "linear.app",
    "1password.com", "agilebits.com",
    "adobe.com",
    "microsoft.com", "office.com",
]

private func isKnownSubscriptionSender(_ domain: String) -> Bool {
    knownSubscriptionDomains.contains { domain == $0 || domain.hasSuffix("." + $0) }
}

/// Scores the parsed row on 0.0–1.0. Tuned so that:
///   ≥0.7 = Detected (trustworthy without review)
///   0.4–0.7 = Review these (user confirms)
///   <0.4 = parser should reject upstream; never reached here
private func scoreConfidence(
    event: ParsedSubscription.EventKind,
    strongCharge: Bool,
    weakRecurrence: Bool,
    marketingCTA: Bool,
    receiptSubject: Bool,
    hasAmount: Bool,
    hasTrialEnd: Bool,
    hasAccountID: Bool,
    knownSender: Bool
) -> Double {
    var score = 0.0

    // Lifecycle events are high-confidence when subject-driven.
    switch event {
    case .canceled, .paused:
        score += 0.8
    case .trialStart:
        score += hasTrialEnd ? 0.7 : 0.5
    case .renewal:
        score += 0.6
    case .receipt:
        score += 0.5
    case .welcome:
        score += 0.4
    case .unknown:
        score += 0.2
    }

    if strongCharge { score += 0.3 }
    if receiptSubject { score += 0.1 }
    if hasAmount { score += 0.1 }
    if hasAccountID { score += 0.05 }
    if knownSender { score += 0.15 }

    // Weak recurrence alone is not a plus — it's the minimum bar. But weak WITH
    // strong charge is redundant, so don't double-count.
    if weakRecurrence && !strongCharge { score += 0.05 }

    // Marketing CTA subjects cap out in Review territory even if everything
    // else lines up — we want the user to confirm these.
    if marketingCTA { score = min(score, 0.65) }

    return min(1.0, max(0.0, score))
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

/// Subject line is the most reliable lifecycle signal — "Your subscription was
/// canceled" in the subject means canceled; "cancel anytime" in the footer of
/// a renewal receipt does not. Subject wins, body is only a fallback with
/// phrase-anchored matches.
private func classifyEvent(subject: String, body: String, trialEndDate: Date?) -> ParsedSubscription.EventKind {
    let subj = subject.lowercased()
    let bod = body.lowercased()

    // --- Subject-driven lifecycle (highest confidence) ---
    let canceledSubjectPhrases = [
        "has been canceled", "has been cancelled",
        "was canceled", "was cancelled",
        "subscription canceled", "subscription cancelled",
        "membership canceled", "membership cancelled",
        "cancellation confirmation", "cancellation confirmed",
        "you've canceled", "you have canceled",
        "we've canceled", "we have canceled",
    ]
    if canceledSubjectPhrases.contains(where: { subj.contains($0) }) { return .canceled }

    let pausedSubjectPhrases = [
        "has been paused", "was paused", "subscription paused",
        "membership paused", "on hold",
    ]
    if pausedSubjectPhrases.contains(where: { subj.contains($0) }) { return .paused }

    // Trial classifier: require ACTIVE trial wording in the subject (not just
    // the phrase "free trial" which shows up in upgrade CTA footers), OR the
    // body explicitly references a trial end date. Prevents Perplexity-type
    // false trials where the user is already paying monthly.
    let activeTrialSubjectPhrases = [
        "your free trial has started", "trial started", "your free trial",
        "trial has started", "welcome to your trial",
        "your trial activated", "trial activated",
        "free trial begins", "trial period begins",
    ]
    if activeTrialSubjectPhrases.contains(where: { subj.contains($0) }) { return .trialStart }
    if trialEndDate != nil && bod.contains("trial") { return .trialStart }

    let renewalSubjectPhrases = [
        "auto-renew", "auto renew", "renewal", "subscription renewed",
        "your subscription renews", "will renew", "has been renewed",
    ]
    if renewalSubjectPhrases.contains(where: { subj.contains($0) }) { return .renewal }

    let receiptSubjectPhrases = [
        "receipt", "invoice", "payment received", "you paid",
        "amount charged", "thanks for your payment", "payment confirmation",
    ]
    if receiptSubjectPhrases.contains(where: { subj.contains($0) }) { return .receipt }

    let welcomeSubjectPhrases = [
        "welcome to", "thanks for subscribing", "subscription confirmation",
        "your new subscription", "you're now subscribed",
    ]
    if welcomeSubjectPhrases.contains(where: { subj.contains($0) }) { return .welcome }

    // --- Body fallback (phrase-anchored, avoid "cancel anytime" footer trap) ---
    let canceledBodyPhrases = [
        "has been canceled", "has been cancelled",
        "subscription is canceled", "subscription is cancelled",
        "we've canceled your", "we have canceled your",
        "your cancellation is confirmed", "cancellation is complete",
        "you will no longer be charged",
    ]
    if canceledBodyPhrases.contains(where: { bod.contains($0) }) { return .canceled }

    let trialBodyPhrases = [
        "your free trial has started", "your trial has started",
        "welcome to your free trial", "your trial period begins",
        "trial activated",
    ]
    if trialBodyPhrases.contains(where: { bod.contains($0) }) { return .trialStart }

    if bod.contains("auto-renew") || bod.contains("auto renew") ||
       bod.contains("will renew on") || bod.contains("renews on") {
        return .renewal
    }
    if bod.contains("payment received") || bod.contains("you paid") ||
       bod.contains("amount charged") || bod.contains("thanks for your payment") {
        return .receipt
    }
    if bod.contains("thanks for subscribing") || bod.contains("you're now subscribed") {
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
        "/hour", "/hr", "per hour", "hourly rate",
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
