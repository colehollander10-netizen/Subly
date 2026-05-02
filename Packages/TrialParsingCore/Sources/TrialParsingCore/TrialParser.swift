import Foundation

// MARK: - Classification types

public enum TrialConfidenceTier: String, Sendable {
    case high
    case medium
    case low
}

public enum TrialMessageEvent: String, Sendable {
    case trialConfirmation
    case trialStarted
    case promoMarketing
    case informational
    case unknown
}

public enum TrialRejectionReason: String, Sendable {
    case noBody
    case marketingOffer
    case noTrialSignal
    case noEndDate
    case dateInPast
    case noCardOnFile
    case noAutoCharge
    case noAmount
    case weakEvidence
}

public struct TrialMessageSignals: Sendable, Equatable {
    public let isTrialStart: Bool
    public let isWelcomeMessage: Bool
    public let hasEndDate: Bool
    public let hasFutureEndDate: Bool
    public let hasCardLanguage: Bool
    public let hasAutoChargeLanguage: Bool
    public let hasReceiptMarker: Bool
    public let hasChargeAmount: Bool
    public let isPromoMarketing: Bool
}

public struct TrialMessageClassification: Sendable, Equatable {
    public let serviceName: String
    public let sourceID: String
    public let detectedAt: Date
    public let trialEndDate: Date?
    public let chargeAmount: Decimal?
    public let trialLengthDays: Int?
    public let confidence: TrialConfidenceTier
    public let event: TrialMessageEvent
    public let willAutoCharge: Bool
    public let rejectionReason: TrialRejectionReason?
    public let signals: TrialMessageSignals

    public init(
        serviceName: String,
        sourceID: String,
        detectedAt: Date,
        trialEndDate: Date?,
        chargeAmount: Decimal?,
        trialLengthDays: Int?,
        confidence: TrialConfidenceTier,
        event: TrialMessageEvent,
        willAutoCharge: Bool,
        rejectionReason: TrialRejectionReason?,
        signals: TrialMessageSignals
    ) {
        self.serviceName = serviceName
        self.sourceID = sourceID
        self.detectedAt = detectedAt
        self.trialEndDate = trialEndDate
        self.chargeAmount = chargeAmount
        self.trialLengthDays = trialLengthDays
        self.confidence = confidence
        self.event = event
        self.willAutoCharge = willAutoCharge
        self.rejectionReason = rejectionReason
        self.signals = signals
    }
}

public struct SubscriptionFieldExtraction: Sendable, Equatable {
    public let serviceName: String
    public let nextChargeDate: Date?
    public let chargeAmount: Decimal?
    public let billingCycle: SubscriptionBillingCycle?

    public init(
        serviceName: String,
        nextChargeDate: Date?,
        chargeAmount: Decimal?,
        billingCycle: SubscriptionBillingCycle?
    ) {
        self.serviceName = serviceName
        self.nextChargeDate = nextChargeDate
        self.chargeAmount = chargeAmount
        self.billingCycle = billingCycle
    }
}

public enum SubscriptionBillingCycle: String, Sendable, Equatable {
    case monthly
    case yearly
    case weekly
    case custom
}

// MARK: - How the text reached us

public enum TrialTextSource: Sendable {
    /// OCR output from a screenshot: one unstructured blob, no subject/from.
    case screenshot
    /// Email text shared from Mail/Gmail app: may have a subject line at the top.
    case sharedEmail
    /// User pasted raw text from somewhere.
    case pastedText
    /// User typed fields manually — classification mostly a formality.
    case manualEntry
}

// MARK: - Public parser

public enum TrialParser {
    /// Plain-text classifier. Takes a blob of text plus a hint about where it
    /// came from, and runs rule-based extractors to pull out merchant, trial
    /// end date, trial length, and charge amount.
    ///
    /// Designed for manual-capture flows: share extension, paste, screenshot
    /// OCR, manual form. No email/network dependencies.
    public static func classifyText(
        _ text: String,
        now: Date = Date(),
        source: TrialTextSource = .sharedEmail
    ) -> TrialMessageClassification {
        let normalized = normalizeText(text)
        let (subjectGuess, body) = splitSubjectAndBody(normalized, source: source)
        let senderGuess = inferSenderName(from: normalized, subject: subjectGuess)
        let sourceID = "manual-\(UUID().uuidString)"
        let detectedAt = now

        guard !body.isEmpty else {
            return emptyClassification(
                serviceName: senderGuess ?? "Unknown",
                sourceID: sourceID,
                detectedAt: detectedAt,
                reason: .noBody
            )
        }

        let subjectLower = subjectGuess.lowercased()
        let bodyLower = body.lowercased()

        let welcomeMessage = isWelcomeOrTrialStarted(subject: subjectLower, body: bodyLower)
        let trialStart = mentionsTrial(subject: subjectLower, body: bodyLower) || welcomeMessage
        let trialEndDate = extractTrialEndDate(body: body, sentDate: detectedAt)
        let hasFutureEndDate = trialEndDate.map { $0 > now } ?? false
        let cardLanguage = hasCardOnFile(body: bodyLower)
        let autoChargeLanguage = hasAutoChargeLanguage(body: bodyLower)
        let chargeAmount = extractAmount(body: body)
        let explicitLength = extractTrialLengthDays(body: bodyLower, subject: subjectLower)
        let inferredLength: Int? = trialEndDate.flatMap { end in
            let days = Calendar.current.dateComponents([.day], from: detectedAt, to: end).day
            return days.flatMap { closestCanonicalTrialLength($0) }
        }
        let trialLengthDays = explicitLength ?? inferredLength
        let receiptMarker = hasReceiptMarker(subject: subjectLower, body: bodyLower)
        let promoMarketing = isMarketingSubject(subjectGuess)
            || hasMarketingLanguage(subject: subjectLower, body: bodyLower)
        let willAutoCharge = cardLanguage && autoChargeLanguage && chargeAmount != nil

        let signals = TrialMessageSignals(
            isTrialStart: trialStart,
            isWelcomeMessage: welcomeMessage,
            hasEndDate: trialEndDate != nil,
            hasFutureEndDate: hasFutureEndDate,
            hasCardLanguage: cardLanguage,
            hasAutoChargeLanguage: autoChargeLanguage,
            hasReceiptMarker: receiptMarker,
            hasChargeAmount: chargeAmount != nil,
            isPromoMarketing: promoMarketing
        )

        let event: TrialMessageEvent
        if promoMarketing {
            event = .promoMarketing
        } else if trialStart && willAutoCharge {
            event = .trialConfirmation
        } else if trialStart {
            event = .trialStarted
        } else if receiptMarker || cardLanguage || autoChargeLanguage {
            event = .informational
        } else {
            event = .unknown
        }

        let confidence: TrialConfidenceTier
        let rejectionReason: TrialRejectionReason?
        if promoMarketing {
            confidence = .low
            rejectionReason = .marketingOffer
        } else if trialStart && hasFutureEndDate && cardLanguage && autoChargeLanguage && chargeAmount != nil {
            confidence = .high
            rejectionReason = nil
        } else if trialStart && (welcomeMessage || cardLanguage || autoChargeLanguage || receiptMarker || hasFutureEndDate) {
            confidence = .medium
            if trialEndDate == nil {
                rejectionReason = .noEndDate
            } else if !hasFutureEndDate {
                rejectionReason = .dateInPast
            } else if !cardLanguage {
                rejectionReason = .noCardOnFile
            } else if !autoChargeLanguage {
                rejectionReason = .noAutoCharge
            } else if chargeAmount == nil {
                rejectionReason = .noAmount
            } else {
                rejectionReason = .weakEvidence
            }
        } else {
            confidence = .low
            if !trialStart {
                rejectionReason = .noTrialSignal
            } else if trialEndDate == nil {
                rejectionReason = .noEndDate
            } else if !hasFutureEndDate {
                rejectionReason = .dateInPast
            } else {
                rejectionReason = .weakEvidence
            }
        }

        return TrialMessageClassification(
            serviceName: senderGuess ?? "Unknown",
            sourceID: sourceID,
            detectedAt: detectedAt,
            trialEndDate: trialEndDate,
            chargeAmount: chargeAmount,
            trialLengthDays: trialLengthDays,
            confidence: confidence,
            event: event,
            willAutoCharge: willAutoCharge,
            rejectionReason: rejectionReason,
            signals: signals
        )
    }

    /// Lightweight extraction path for subscription receipts and renewal
    /// screenshots. Unlike `classifyText`, this intentionally skips the
    /// trial-signal gates so share-extension users can choose Subscription
    /// first and let the parser pull fields from ordinary billing copy.
    public static func extractSubscriptionFields(
        _ text: String,
        now: Date = Date(),
        source: TrialTextSource = .screenshot
    ) -> SubscriptionFieldExtraction {
        let normalized = normalizeText(text)
        let (subjectGuess, body) = splitSubjectAndBody(normalized, source: source)
        let serviceName = cleanExtractedServiceName(inferSenderName(from: normalized, subject: subjectGuess))
            ?? inferLeadingServiceName(from: body)
            ?? "Unknown"
        let nextChargeDate = extractTrialEndDate(body: body, sentDate: now)
        let amount = extractAmount(body: body)
        let billingCycle = extractSubscriptionBillingCycle(from: body.lowercased())

        return SubscriptionFieldExtraction(
            serviceName: serviceName,
            nextChargeDate: nextChargeDate,
            chargeAmount: amount,
            billingCycle: billingCycle
        )
    }
}

private func cleanExtractedServiceName(_ name: String?) -> String? {
    guard let name else { return nil }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".:;,- "))
    return cleaned.isEmpty ? nil : cleaned
}

private func inferLeadingServiceName(from body: String) -> String? {
    let ignoredPrefixes = [
        "your ",
        "thanks ",
        "thank ",
        "welcome ",
        "receipt",
        "invoice",
        "payment",
        "order",
    ]
    let lines = body
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    guard let first = lines.first, first.count <= 40 else { return nil }
    let lower = first.lowercased()
    guard !ignoredPrefixes.contains(where: lower.hasPrefix),
          !first.contains("$"),
          !first.contains(":"),
          !first.contains(".") else {
        return nil
    }
    return first
}

private func emptyClassification(
    serviceName: String,
    sourceID: String,
    detectedAt: Date,
    reason: TrialRejectionReason
) -> TrialMessageClassification {
    TrialMessageClassification(
        serviceName: serviceName,
        sourceID: sourceID,
        detectedAt: detectedAt,
        trialEndDate: nil,
        chargeAmount: nil,
        trialLengthDays: nil,
        confidence: .low,
        event: .unknown,
        willAutoCharge: false,
        rejectionReason: reason,
        signals: TrialMessageSignals(
            isTrialStart: false,
            isWelcomeMessage: false,
            hasEndDate: false,
            hasFutureEndDate: false,
            hasCardLanguage: false,
            hasAutoChargeLanguage: false,
            hasReceiptMarker: false,
            hasChargeAmount: false,
            isPromoMarketing: false
        )
    )
}

// MARK: - Text preprocessing

/// Collapse runs of whitespace, strip HTML if any slipped in, normalize quotes
/// and bullet noise. OCR output often has triple-spaces and broken lines.
internal func normalizeText(_ input: String) -> String {
    var text = input
    if text.contains("<") && (text.contains("</") || text.contains("<br") || text.contains("<p>") || text.contains("<td")) {
        text = stripHTML(text)
    }
    text = text
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{2022}", with: " ")
        .replacingOccurrences(of: "\u{2013}", with: "-")
        .replacingOccurrences(of: "\u{2014}", with: "-")
        .replacingOccurrences(of: "\u{2018}", with: "'")
        .replacingOccurrences(of: "\u{2019}", with: "'")
        .replacingOccurrences(of: "\u{201C}", with: "\"")
        .replacingOccurrences(of: "\u{201D}", with: "\"")
    if let re = try? NSRegularExpression(pattern: #"[ \t]{2,}"#) {
        text = re.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

internal func splitSubjectAndBody(_ text: String, source: TrialTextSource) -> (subject: String, body: String) {
    switch source {
    case .screenshot, .manualEntry:
        return ("", text)
    case .sharedEmail, .pastedText:
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstNonEmpty = lines.first(where: { !$0.isEmpty }) else {
            return ("", text)
        }
        let looksLikeSubject = firstNonEmpty.count <= 120
            && !firstNonEmpty.contains("$")
            && !firstNonEmpty.hasSuffix(".")
            && !firstNonEmpty.hasSuffix("!")
        if looksLikeSubject {
            return (firstNonEmpty, text)
        }
        return ("", text)
    }
}

internal func inferSenderName(from text: String, subject: String) -> String? {
    let haystack = subject.isEmpty ? text : subject
    let patterns: [String] = [
        #"[Yy]our\s+([A-Z][A-Za-z0-9\.\&\-]+(?:\s+[A-Z][A-Za-z0-9\.\&\-]+)?)\s+(?:free\s+)?trial"#,
        #"[Ww]elcome\s+to\s+([A-Z][A-Za-z0-9\.\&\-]+(?:\s+[A-Z][A-Za-z0-9\.\&\-]+)?)"#,
        #"[Yy]our\s+purchase\s+of\s+([A-Z][A-Za-z0-9\.\&\-]+(?:\s+[A-Z][A-Za-z0-9\.\&\-]+)?)"#,
        #"[Tt]hanks?\s+for\s+subscribing\s+to\s+([A-Z][A-Za-z0-9\.\&\-]+(?:\s+[A-Z][A-Za-z0-9\.\&\-]+)?)"#,
    ]
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let range = NSRange(haystack.startIndex..., in: haystack)
        if let match = regex.firstMatch(in: haystack, options: [], range: range),
           match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: haystack) {
            return String(haystack[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

// MARK: - Gates

internal func isMarketingSubject(_ subject: String) -> Bool {
    let lower = subject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if lower.isEmpty { return false }

    let promoVerbs = [
        "claim",
        "unlock",
        "score",
        "grab",
        "get ",
        "try ",
        "start your",
        "don't miss",
        "dont miss",
        "last chance",
        "limited time",
        "save ",
        "introducing",
        "meet ",
        "just for you",
        "you're invited",
        "youre invited",
        "we'd love to",
        "wed love to",
    ]
    if promoVerbs.contains(where: { lower.hasPrefix($0) }) { return true }

    let promoMarkers = [
        "limited time",
        "for a limited",
        "offer ends",
        "% off",
        "months free",
        "free months",
        "exclusive offer",
        "free trial 🥰",
        "of free trial",
        "of uber one free",
    ]
    if promoMarkers.contains(where: { lower.contains($0) }) { return true }

    if lower.contains("months of") && lower.contains("free trial") { return true }

    return false
}

internal func isWelcomeOrTrialStarted(subject: String, body: String) -> Bool {
    let welcomeSubjectPhrases = [
        "welcome to",
        "you're in",
        "youre in",
        "you've started",
        "youve started",
        "your trial has started",
        "your free trial has started",
        "your subscription has started",
        "get started with",
        "your free trial",
        "free trial starts now",
        "trial starts now",
        "trial activated",
        "trial confirmed",
    ]
    if welcomeSubjectPhrases.contains(where: { subject.contains($0) }) { return true }

    let welcomeBodyPhrases = [
        "welcome to",
        "your trial has started",
        "your free trial has started",
        "your trial is now active",
        "your subscription has started",
        "you're now subscribed",
        "youre now subscribed",
        "thanks for subscribing",
        "thank you for subscribing",
        "trial period begins",
        "trial begins today",
        "free trial starts now",
        "trial starts now",
    ]
    return welcomeBodyPhrases.contains { body.contains($0) }
}

internal func mentionsTrial(subject: String, body: String) -> Bool {
    let trialPhrases = [
        "free trial",
        "your trial",
        "trial ends",
        "trial will",
        "trial period",
        "start your free",
        "days of free",
        "day free trial",
        "days free",
    ]
    if trialPhrases.contains(where: { subject.contains($0) || body.contains($0) }) {
        return true
    }
    let zeroChargeMarkers = [
        "charged usd 0.00",
        "charged $0.00",
        "total: $0.00",
        "total: usd 0.00",
        "amount: $0.00",
        "amount: usd 0.00",
        "free for",
    ]
    let futureChargeMarkers = [
        "will be charged",
        "starting ",
        "your payment of",
        "renewal date",
        "auto-renew",
    ]
    let hasZero = zeroChargeMarkers.contains { body.contains($0) }
    let hasFuture = futureChargeMarkers.contains { body.contains($0) }
    return hasZero && hasFuture
}

internal func hasCardOnFile(body: String) -> Bool {
    let negativePhrases = [
        "no credit card",
        "no card required",
        "card not required",
        "without a credit card",
        "no payment info",
        "no payment information",
        "no payment method",
    ]
    if negativePhrases.contains(where: { body.contains($0) }) {
        return false
    }

    let phrases = [
        "card ending",
        "card on file",
        "ending in",
        "credit card",
        "payment method",
        "billing method",
        "paypal",
        "apple pay",
        "google pay",
        "we will charge",
        "we'll charge",
        "you will be charged",
        "you'll be charged",
        "your card will",
        "will be billed",
    ]
    return phrases.contains { body.contains($0) }
}

internal func hasAutoChargeLanguage(body: String) -> Bool {
    let phrases = [
        "will be charged",
        "will be billed",
        "we'll charge",
        "we will charge",
        "automatically charged",
        "automatically renew",
        "automatic renewal",
        "cancel before",
        "cancel anytime before",
        "to avoid being charged",
        "after your trial",
        "after the trial",
        "once the trial",
        "when the trial ends",
        "trial converts",
    ]
    return phrases.contains { body.contains($0) }
}

internal func hasReceiptMarker(subject: String, body: String) -> Bool {
    let phrases = [
        "receipt",
        "invoice",
        "invoice id",
        "invoice number",
        "order number",
        "order details",
        "payment processed",
        "tax",
        "subtotal",
        "charged usd",
        "charged $",
        "plan price",
        "payment of",
    ]
    return phrases.contains { subject.contains($0) || body.contains($0) }
}

internal func hasMarketingLanguage(subject: String, body: String) -> Bool {
    let phrases = [
        "claim your free trial",
        "claim a free trial",
        "unlock free",
        "score free",
        "exclusive offer",
        "limited time",
        "just for you",
        "start your free trial",
        "don't miss",
        "offer ends",
    ]
    return phrases.contains { subject.contains($0) || body.contains($0) }
}

// MARK: - End date extraction

internal func extractTrialEndDate(body: String, sentDate: Date) -> Date? {
    if let explicit = extractExplicitDate(body: body) { return explicit }
    if let relative = extractRelativeDuration(body: body, base: sentDate) { return relative }
    return nil
}

private func extractExplicitDate(body: String) -> Date? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        return nil
    }
    let dateKeywords = ["trial", "ends", "charge", "renew", "billing", "next payment", "starting"]
    let lines = body.components(separatedBy: .newlines)
    for line in lines where dateKeywords.contains(where: { line.lowercased().contains($0) }) {
        if let parsed = parseDateSnippet(in: line) {
            return parsed
        }
        let range = NSRange(line.startIndex..., in: line)
        if let match = detector.matches(in: line, options: [], range: range).first,
           let date = match.date {
            return date
        }
    }
    return nil
}

private func parseDateSnippet(in line: String) -> Date? {
    let patterns = [
        #"(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2},\s*\d{4}"#,
        #"(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+\d{1,2},\s*\d{4}"#,
        #"\d{1,2}/\d{1,2}/\d{2,4}"#,
    ]

    let formatters: [DateFormatter] = [
        makeDateFormatter("MMMM d, yyyy"),
        makeDateFormatter("MMM d, yyyy"),
        makeDateFormatter("MMM. d, yyyy"),
        makeDateFormatter("M/d/yyyy"),
        makeDateFormatter("M/d/yy"),
    ]

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            continue
        }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let snippetRange = Range(match.range, in: line) else {
            continue
        }
        let snippet = String(line[snippetRange])
        for formatter in formatters {
            if let date = formatter.date(from: snippet) {
                return normalizedDateOnly(date)
            }
        }
    }

    return nil
}

private func makeDateFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = format
    return formatter
}

private func normalizedDateOnly(_ date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = Calendar.current.timeZone
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: components.year,
        month: components.month,
        day: components.day,
        hour: 12
    )) ?? date
}

private func extractRelativeDuration(body: String, base: Date) -> Date? {
    let pattern = #"(\d{1,3})[ -]?day"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
        return nil
    }
    let range = NSRange(body.startIndex..., in: body)
    for match in regex.matches(in: body, options: [], range: range) {
        if match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: body),
           let days = Int(body[r]),
           (1...60).contains(days) {
            return Calendar.current.date(byAdding: .day, value: days, to: base)
        }
    }
    return nil
}

// MARK: - Amount extraction

internal func extractAmount(body: String) -> Decimal? {
    let patterns = [
        #"\$\s?(\d{1,4}(?:\.\d{2})?)"#,
        #"USD\s?(\d{1,4}(?:\.\d{2})?)"#,
    ]
    var amounts: [Decimal] = []
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            continue
        }
        let range = NSRange(body.startIndex..., in: body)
        for match in regex.matches(in: body, options: [], range: range) {
            if match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: body),
               let value = Decimal(string: String(body[r])),
               value > 0 {
                amounts.append(value)
            }
        }
    }
    return amounts.max()
}

internal func extractSubscriptionBillingCycle(from body: String) -> SubscriptionBillingCycle? {
    let yearlyMarkers = [
        "per year",
        "per annum",
        "yearly",
        "annual",
        "annually",
        "/year",
        "/yr",
    ]
    if yearlyMarkers.contains(where: body.contains) { return .yearly }

    let weeklyMarkers = [
        "per week",
        "weekly",
        "/week",
        "/wk",
    ]
    if weeklyMarkers.contains(where: body.contains) { return .weekly }

    let monthlyMarkers = [
        "per month",
        "monthly",
        "/month",
        "/mo",
        "renews every month",
    ]
    if monthlyMarkers.contains(where: body.contains) { return .monthly }

    return nil
}

// MARK: - Trial length

internal let canonicalTrialLengths: [Int] = [3, 5, 7, 14, 21, 30, 60, 90, 180, 365]

internal func closestCanonicalTrialLength(_ days: Int) -> Int? {
    guard days > 0, days <= 400 else { return nil }
    return canonicalTrialLengths.min(by: { abs($0 - days) < abs($1 - days) })
}

internal func extractTrialLengthDays(body: String, subject: String) -> Int? {
    let haystack = subject + " " + body
    let patterns: [(String, (Double) -> Double)] = [
        (#"(\d{1,3})[\s-]*day(?:s)?\s+(?:free\s+)?trial"#, { $0 }),
        (#"(\d{1,2})[\s-]*week(?:s)?\s+(?:free\s+)?trial"#, { $0 * 7 }),
        (#"(\d{1,2})[\s-]*month(?:s)?\s+(?:free\s+)?trial"#, { $0 * 30 }),
        (#"(\d{1,2})[\s-]*year(?:s)?\s+(?:free\s+)?trial"#, { $0 * 365 }),
        (#"(?:free\s+)?trial\s+(?:of\s+|for\s+)?(\d{1,3})[\s-]*day"#, { $0 }),
        (#"free\s+for\s+(\d{1,3})[\s-]*day"#, { $0 }),
        (#"free\s+for\s+(\d{1,2})[\s-]*week"#, { $0 * 7 }),
        (#"free\s+for\s+(\d{1,2})[\s-]*month"#, { $0 * 30 }),
        (#"free\s+for\s+(?:a|one)\s+month"#, { _ in 30 }),
        (#"free\s+for\s+(?:a|one)\s+year"#, { _ in 365 }),
        (#"(?:a|one)\s+month\s+free"#, { _ in 30 }),
        (#"(?:a|one)\s+year\s+free"#, { _ in 365 }),
    ]
    for (pattern, transform) in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            continue
        }
        let range = NSRange(haystack.startIndex..., in: haystack)
        guard let match = regex.matches(in: haystack, options: [], range: range).first else {
            continue
        }
        let raw: Double
        if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: haystack) {
            raw = Double(haystack[r]) ?? 0
        } else {
            raw = 0
        }
        let days = Int(transform(raw).rounded())
        if let canonical = closestCanonicalTrialLength(days) {
            return canonical
        }
    }
    return nil
}

// MARK: - HTML helper (for pasted HTML-email text)

internal func stripHTML(_ html: String) -> String {
    let blockPattern = #"</(p|div|td|th|br|li|tr|h[1-6])[^>]*>"#
    var text = html
    if let re = try? NSRegularExpression(pattern: blockPattern, options: .caseInsensitive) {
        text = re.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "\n"
        )
    }
    if let re = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
        text = re.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
    }
    text = text
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&quot;", with: "\"")
    if let re = try? NSRegularExpression(pattern: #"\n{3,}"#) {
        text = re.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "\n\n"
        )
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
