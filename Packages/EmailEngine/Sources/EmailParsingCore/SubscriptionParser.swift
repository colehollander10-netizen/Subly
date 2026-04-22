import Foundation
import OSLog

private let parserLog = Logger(subsystem: "com.subly.Subly", category: "parser")

// MARK: - Detected trial (value type)

/// A trial detected from a Gmail message with high-confidence evidence:
/// trial/welcome language, a future end date, billing method context,
/// auto-charge language, and a real post-trial amount.
public struct DetectedTrial: Sendable, Equatable {
    public let serviceName: String
    public let senderDomain: String
    public let trialEndDate: Date
    public let chargeAmount: Decimal?
    public let sourceMessageID: String
    public let detectedAt: Date

    public init(
        serviceName: String,
        senderDomain: String,
        trialEndDate: Date,
        chargeAmount: Decimal?,
        sourceMessageID: String,
        detectedAt: Date
    ) {
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.trialEndDate = trialEndDate
        self.chargeAmount = chargeAmount
        self.sourceMessageID = sourceMessageID
        self.detectedAt = detectedAt
    }
}

// MARK: - Low-confidence lead (welcome email, no charge amount)

/// A trial *lead*: we found a plausible welcome / trial-started email, but the
/// evidence is incomplete, so the user needs to confirm details manually.
public struct DetectedLead: Sendable, Equatable {
    public let serviceName: String
    public let senderDomain: String
    public let sourceMessageID: String
    public let detectedAt: Date

    public init(
        serviceName: String,
        senderDomain: String,
        sourceMessageID: String,
        detectedAt: Date
    ) {
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.sourceMessageID = sourceMessageID
        self.detectedAt = detectedAt
    }
}

// MARK: - Parser

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
    case noDomain
    case noiseDomain
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

public enum SenderCategory: String, Sendable {
    case knownService
    case bank
    case marketplace
    case unknown
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
    public let senderCategory: SenderCategory
}

public struct TrialMessageClassification: Sendable, Equatable {
    public let serviceName: String
    public let senderDomain: String
    public let sourceMessageID: String
    public let detectedAt: Date
    public let trialEndDate: Date?
    public let chargeAmount: Decimal?
    public let confidence: TrialConfidenceTier
    public let event: TrialMessageEvent
    public let willAutoCharge: Bool
    public let rejectionReason: TrialRejectionReason?
    public let signals: TrialMessageSignals
}

public struct TrialBatchClassification: Sendable {
    public let classifications: [TrialMessageClassification]
    public let detectedTrials: [DetectedTrial]
    public let detectedLeads: [DetectedLead]

    public init(
        classifications: [TrialMessageClassification],
        detectedTrials: [DetectedTrial],
        detectedLeads: [DetectedLead]
    ) {
        self.classifications = classifications
        self.detectedTrials = detectedTrials
        self.detectedLeads = detectedLeads
    }
}

public enum TrialParser {
    /// Cheap metadata check — skip bodies that obviously aren't free trials
    /// with a card on file. Keeps the full-body fetch count low.
    public static func shouldFetchBody(_ message: GmailMessage) -> Bool {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = (header(headers, "Subject") ?? "").lowercased()

        let domain = senderDomain(from: from)
        if domain.isEmpty { return false }
        if isNoiseDomain(domain) { return false }

        // Also pass through purchase/subscription confirmations that never use
        // the word "trial" (e.g. MS 365: "Your purchase of … has been processed").
        let purchaseKeywords = [
            "trial", "free",
            "purchase", "subscription", "receipt",
            "order confirmation", "has been processed",
        ]
        return purchaseKeywords.contains { subject.contains($0) }
    }

    public static func classifyWithDiagnostics(_ message: GmailMessage, now: Date = Date()) -> TrialMessageClassification {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = (header(headers, "Subject") ?? "")
        let domain = senderDomain(from: from)
        let service = domain.isEmpty
            ? (parseDisplayName(from) ?? "Unknown")
            : serviceName(fromDomain: domain, from: from)
        let sentDate = message.sentDate ?? now
        guard !domain.isEmpty else {
            return TrialMessageClassification(
                serviceName: service,
                senderDomain: "",
                sourceMessageID: message.id,
                detectedAt: sentDate,
                trialEndDate: nil,
                chargeAmount: nil,
                confidence: .low,
                event: .unknown,
                willAutoCharge: false,
                rejectionReason: .noDomain,
                signals: TrialMessageSignals(
                    isTrialStart: false,
                    isWelcomeMessage: false,
                    hasEndDate: false,
                    hasFutureEndDate: false,
                    hasCardLanguage: false,
                    hasAutoChargeLanguage: false,
                    hasReceiptMarker: false,
                    hasChargeAmount: false,
                    isPromoMarketing: false,
                    senderCategory: .unknown
                )
            )
        }
        guard !isNoiseDomain(domain) else {
            return TrialMessageClassification(
                serviceName: service,
                senderDomain: domain,
                sourceMessageID: message.id,
                detectedAt: sentDate,
                trialEndDate: nil,
                chargeAmount: nil,
                confidence: .low,
                event: .unknown,
                willAutoCharge: false,
                rejectionReason: .noiseDomain,
                signals: TrialMessageSignals(
                    isTrialStart: false,
                    isWelcomeMessage: false,
                    hasEndDate: false,
                    hasFutureEndDate: false,
                    hasCardLanguage: false,
                    hasAutoChargeLanguage: false,
                    hasReceiptMarker: false,
                    hasChargeAmount: false,
                    isPromoMarketing: false,
                    senderCategory: .unknown
                )
            )
        }
        guard let bodyRaw = decodedBody(message.payload) else {
            return TrialMessageClassification(
                serviceName: service,
                senderDomain: domain,
                sourceMessageID: message.id,
                detectedAt: sentDate,
                trialEndDate: nil,
                chargeAmount: nil,
                confidence: .low,
                event: .unknown,
                willAutoCharge: false,
                rejectionReason: .noBody,
                signals: TrialMessageSignals(
                    isTrialStart: false,
                    isWelcomeMessage: false,
                    hasEndDate: false,
                    hasFutureEndDate: false,
                    hasCardLanguage: false,
                    hasAutoChargeLanguage: false,
                    hasReceiptMarker: false,
                    hasChargeAmount: false,
                    isPromoMarketing: false,
                    senderCategory: categorizeSender(domain)
                )
            )
        }

        let subjectLower = subject.lowercased()
        let body = bodyRaw.lowercased()
        let welcomeMessage = isWelcomeOrTrialStarted(subject: subjectLower, body: body)
        let trialStart = mentionsTrial(subject: subjectLower, body: body) || welcomeMessage
        let trialEndDate = extractTrialEndDate(body: bodyRaw, sentDate: sentDate)
        let hasFutureEndDate = trialEndDate.map { $0 > now } ?? false
        let cardLanguage = hasCardOnFile(body: body)
        let autoChargeLanguage = hasAutoChargeLanguage(body: body)
        let chargeAmount = extractAmount(body: bodyRaw)
        let receiptMarker = hasReceiptMarker(subject: subjectLower, body: body)
        let promoMarketing = isMarketingSubject(subject) || hasMarketingLanguage(subject: subjectLower, body: body)
        let senderCategory = categorizeSender(domain)
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
            isPromoMarketing: promoMarketing,
            senderCategory: senderCategory
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
        } else if trialStart &&
                    hasFutureEndDate &&
                    cardLanguage &&
                    autoChargeLanguage &&
                    chargeAmount != nil &&
                    (receiptMarker || senderCategory == .knownService) {
            confidence = .high
            rejectionReason = nil
        } else if trialStart && (welcomeMessage || cardLanguage || autoChargeLanguage || receiptMarker) {
            confidence = .medium
            if trialEndDate == nil {
                rejectionReason = .noEndDate
            } else if trialEndDate != nil && !hasFutureEndDate {
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
            } else if !cardLanguage {
                rejectionReason = .noCardOnFile
            } else if !autoChargeLanguage {
                rejectionReason = .noAutoCharge
            } else if chargeAmount == nil {
                rejectionReason = .noAmount
            } else {
                rejectionReason = .weakEvidence
            }
        }

        return TrialMessageClassification(
            serviceName: service,
            senderDomain: domain,
            sourceMessageID: message.id,
            detectedAt: sentDate,
            trialEndDate: trialEndDate,
            chargeAmount: chargeAmount,
            confidence: confidence,
            event: event,
            willAutoCharge: willAutoCharge,
            rejectionReason: rejectionReason,
            signals: signals
        )
    }

    public static func analyze(_ messages: [GmailMessage], now: Date = Date()) -> TrialBatchClassification {
        let classifications = messages.map { classifyWithDiagnostics($0, now: now) }
        let grouped = Dictionary(grouping: classifications.filter { !$0.senderDomain.isEmpty }, by: \.senderDomain)

        var detectedTrials: [DetectedTrial] = []
        var detectedLeads: [DetectedLead] = []

        for (_, domainClassifications) in grouped {
            let aggregate = aggregate(classifications: domainClassifications, now: now)
            if let detected = aggregate.detectedTrial {
                detectedTrials.append(detected)
            } else if let lead = aggregate.detectedLead {
                detectedLeads.append(lead)
            }
        }

        return TrialBatchClassification(
            classifications: classifications,
            detectedTrials: detectedTrials.sorted { $0.detectedAt > $1.detectedAt },
            detectedLeads: detectedLeads.sorted { $0.detectedAt > $1.detectedAt }
        )
    }

    /// Try to produce a low-confidence `DetectedLead` from a single message.
    public static func detectLead(_ message: GmailMessage, now: Date = Date()) -> DetectedLead? {
        let classification = classifyWithDiagnostics(message, now: now)
        if let lead = classification.asDetectedLead {
            parserLog.info("lead[\(message.id, privacy: .public)] service=\(lead.serviceName, privacy: .public) domain=\(lead.senderDomain, privacy: .public) confidence=\(classification.confidence.rawValue, privacy: .public)")
            return lead
        }
        if let reason = classification.rejectionReason {
            parserLog.debug("lead-reject[\(message.id, privacy: .public)] domain=\(classification.senderDomain, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
        }
        return nil
    }

    /// Parse a full Gmail message into a `DetectedTrial` or reject it.
    public static func detect(_ message: GmailMessage, now: Date = Date()) -> DetectedTrial? {
        let classification = classifyWithDiagnostics(message, now: now)
        if let detected = classification.asDetectedTrial {
            parserLog.info("accept[\(message.id, privacy: .public)] service=\(detected.serviceName, privacy: .public) domain=\(detected.senderDomain, privacy: .public) confidence=\(classification.confidence.rawValue, privacy: .public)")
            return detected
        }
        if let reason = classification.rejectionReason {
            parserLog.debug("reject[\(message.id, privacy: .public)] domain=\(classification.senderDomain, privacy: .public) confidence=\(classification.confidence.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
        }
        return nil
    }
}

private extension TrialMessageClassification {
    var asDetectedTrial: DetectedTrial? {
        guard confidence == .high, let trialEndDate, let chargeAmount else { return nil }
        return DetectedTrial(
            serviceName: serviceName,
            senderDomain: senderDomain,
            trialEndDate: trialEndDate,
            chargeAmount: chargeAmount,
            sourceMessageID: sourceMessageID,
            detectedAt: detectedAt
        )
    }

    var asDetectedLead: DetectedLead? {
        guard confidence == .medium else { return nil }
        return DetectedLead(
            serviceName: serviceName,
            senderDomain: senderDomain,
            sourceMessageID: sourceMessageID,
            detectedAt: detectedAt
        )
    }
}

private extension TrialParser {
    struct AggregateOutcome {
        let detectedTrial: DetectedTrial?
        let detectedLead: DetectedLead?
    }

    static func aggregate(classifications: [TrialMessageClassification], now: Date) -> AggregateOutcome {
        guard !classifications.isEmpty else {
            return AggregateOutcome(detectedTrial: nil, detectedLead: nil)
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: now) ?? now
        let scoped = classifications.filter { $0.detectedAt >= cutoff }
        let window = scoped.isEmpty ? classifications : scoped

        let ordered = window.sorted { lhs, rhs in
            let lhsScore = aggregateScore(lhs)
            let rhsScore = aggregateScore(rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.detectedAt > rhs.detectedAt
        }

        if let high = ordered.first(where: { $0.confidence == .high }),
           let detected = high.asDetectedTrial {
            return AggregateOutcome(detectedTrial: detected, detectedLead: nil)
        }

        if let medium = ordered.first(where: { $0.confidence == .medium }),
           let lead = medium.asDetectedLead {
            return AggregateOutcome(detectedTrial: nil, detectedLead: lead)
        }

        return AggregateOutcome(detectedTrial: nil, detectedLead: nil)
    }

    static func aggregateScore(_ classification: TrialMessageClassification) -> Int {
        var score = 0
        switch classification.confidence {
        case .high:
            score += 100
        case .medium:
            score += 50
        case .low:
            break
        }
        if classification.signals.hasReceiptMarker { score += 20 }
        if classification.chargeAmount != nil { score += 12 }
        if classification.signals.hasAutoChargeLanguage { score += 8 }
        if classification.signals.hasCardLanguage { score += 6 }
        if classification.signals.hasEndDate { score += 4 }
        if classification.signals.senderCategory == .knownService { score += 4 }
        return score
    }
}

// MARK: - Gates

/// A trial *confirmation* reads like "Your trial has started" — possessive,
/// past-tense, about the user's existing account. A marketing/promo email
/// reads like "Claim a 2 month free trial" — imperative, inviting, about an
/// offer the user hasn't accepted yet. We only care about confirmations.
private func isMarketingSubject(_ subject: String) -> Bool {
    let lower = subject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if lower.isEmpty { return false }

    // Leading imperative verbs / promo openers that signal an offer, not a
    // confirmation.
    let promoVerbs = [
        "claim",
        "unlock",
        "score",
        "grab",
        "get ",              // "get 2 months free" — trailing space avoids "getting started"
        "try ",
        "start your",        // "Start your free trial today" = promo CTA
        "don't miss",
        "dont miss",
        "last chance",
        "limited time",
        "save ",
        "introducing",
        "meet ",
        "just for you",      // "Just for you: 2 months of Uber One free trial"
        "you're invited",
        "youre invited",
        "we'd love to",
        "wed love to",
    ]
    if promoVerbs.contains(where: { lower.hasPrefix($0) }) { return true }

    // Promo phrases that can appear anywhere in the subject.
    let promoMarkers = [
        "limited time",
        "for a limited",
        "offer ends",
        "% off",
        "months free",           // "5 months free" / "2 months free" = promo
        "free months",
        "exclusive offer",
        "free trial 🥰",         // emoji-tagged marketing subject
        "of free trial",         // "2 months of free trial" — offer phrasing
        "of uber one free",      // very Uber-specific promo template
    ]
    if promoMarkers.contains(where: { lower.contains($0) }) { return true }

    // Compound pattern: "N months of ... free trial" is almost always a promo.
    // Catches "Just for you: 2 months of Uber One free trial" even without
    // the specific markers above.
    if lower.contains("months of") && lower.contains("free trial") { return true }

    return false
}

private func isWelcomeOrTrialStarted(subject: String, body: String) -> Bool {
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

private func mentionsTrial(subject: String, body: String) -> Bool {
    // Explicit trial phrasing.
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
    // Some services (MS 365, others) run free trials without ever using the
    // word "trial". We infer trial-equivalence from a $0 charge NOW + a future
    // charge with a real amount. That's the user-visible contract of a free
    // trial: "you pay nothing today, but we'll charge you on date X."
    let zeroChargeMarkers = [
        "charged usd 0.00",
        "charged $0.00",
        "total: $0.00",
        "total: usd 0.00",
        "amount: $0.00",
        "amount: usd 0.00",
        "free for",                 // "free for the first month"
    ]
    let futureChargeMarkers = [
        "will be charged",
        "starting ",                // "Starting Monday, October 19, 2026"
        "your payment of",
        "renewal date",
        "auto-renew",
    ]
    let hasZero = zeroChargeMarkers.contains { body.contains($0) }
    let hasFuture = futureChargeMarkers.contains { body.contains($0) }
    return hasZero && hasFuture
}

private func hasCardOnFile(body: String) -> Bool {
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
        "ending in",           // "card ending in 1234" / "•••• 1234"
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

private func hasAutoChargeLanguage(body: String) -> Bool {
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

private func hasReceiptMarker(subject: String, body: String) -> Bool {
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

private func hasMarketingLanguage(subject: String, body: String) -> Bool {
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

private func categorizeSender(_ domain: String) -> SenderCategory {
    guard !domain.isEmpty else { return .unknown }

    let bankMarkers = [
        "chase", "bankofamerica", "capitalone", "americanexpress",
        "citi", "wellsfargo", "discover",
    ]
    if bankMarkers.contains(where: { domain.contains($0) }) {
        return .bank
    }

    let marketplaceMarkers = [
        "uber.com", "amazon.com", "paypal.com", "stripe.com", "squareup.com",
    ]
    if marketplaceMarkers.contains(where: { domain.contains($0) }) {
        return .marketplace
    }

    return .knownService
}

// MARK: - End date extraction

/// Extracts the trial end date. Handles:
///   - Explicit dates: "trial ends on November 5" / "ends 11/5/2025"
///   - Relative durations: "7-day free trial", "your 14 day trial" → sentDate + N days
private func extractTrialEndDate(body: String, sentDate: Date) -> Date? {
    if let explicit = extractExplicitDate(body: body) { return explicit }
    if let relative = extractRelativeDuration(body: body, base: sentDate) { return relative }
    return nil
}

private func extractExplicitDate(body: String) -> Date? {
    // NSDataDetector handles "November 5", "11/5/2025", etc.
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        return nil
    }
    // Narrow the search to sentences that mention a date-relevant keyword —
    // avoids grabbing unrelated dates (shipping estimates, event dates, etc.).
    let dateKeywords = ["trial", "ends", "charge", "renew", "billing", "next payment", "starting"]
    let lines = body.components(separatedBy: .newlines)
    for line in lines where dateKeywords.contains(where: { line.lowercased().contains($0) }) {
        let range = NSRange(line.startIndex..., in: line)
        if let match = detector.matches(in: line, options: [], range: range).first,
           let date = match.date {
            return date
        }
        if let parsed = parseDateSnippet(in: line) {
            return parsed
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
                return date
            }
        }
    }

    return nil
}

private func makeDateFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = format
    return formatter
}

private func extractRelativeDuration(body: String, base: Date) -> Date? {
    // Patterns like "7-day free trial", "14 day trial", "30 days free".
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

private func extractAmount(body: String) -> Decimal? {
    // Match either "$12.99" or "USD 12.99" / "USD 12" styles. Return the
    // largest extracted amount — trial emails frequently list a $0.00 charge
    // before the real future amount ("We've charged USD 0.00… your payment of
    // USD 4.99 will be charged every month"). Picking the max avoids showing
    // a misleading $0.00 alert.
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

// MARK: - Sender helpers

private func header(_ headers: [MessageHeader], _ name: String) -> String? {
    headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
}

private func senderDomain(from: String) -> String {
    guard let at = from.lastIndex(of: "@") else { return "" }
    let after = from[from.index(after: at)...]
    let cleaned = after.trimmingCharacters(in: CharacterSet(charactersIn: "> \t\n\r"))
    return cleaned.lowercased()
}

private func isNoiseDomain(_ domain: String) -> Bool {
    let noisy = [
        "mail.gmail.com",
        "gmail.com",
        "googlemail.com",
        "noreply.google.com",
    ]
    return noisy.contains(domain)
}

private func serviceName(fromDomain domain: String, from: String) -> String {
    if let display = parseDisplayName(from) { return display }
    // Fall back to second-level domain: "billing.cursor.com" → "Cursor".
    let parts = domain.split(separator: ".")
    let root = parts.count >= 2 ? parts[parts.count - 2] : parts.first ?? ""
    return root.capitalized
}

private func parseDisplayName(_ from: String) -> String? {
    // "The Cursor Team <team@cursor.com>" → "The Cursor Team"
    guard let lt = from.firstIndex(of: "<") else { return nil }
    let name = from[..<lt].trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    return name.isEmpty ? nil : name
}

// MARK: - Body decode

private func decodedBody(_ payload: MessagePayload?) -> String? {
    guard let payload else { return nil }
    // Prefer text/plain — no stripping needed, phrases match cleanly.
    if let plain = extractPart(payload, mimeType: "text/plain") { return plain }
    // Fall back to text/html with tags stripped so phrase matchers work on
    // HTML-only emails (e.g. Microsoft 365 billing receipts).
    if let html = extractPart(payload, mimeType: "text/html") { return stripHTML(html) }
    // Legacy: single-part body with no MIME type declared. Strip HTML if needed.
    if let encoded = payload.body?.data, let decoded = base64URLDecode(encoded) {
        let looksLikeHTML = decoded.hasPrefix("<") || decoded.contains("<html") || decoded.contains("<td")
        return looksLikeHTML ? stripHTML(decoded) : decoded
    }
    return nil
}

/// Walk the MIME tree depth-first and return the first decoded part matching
/// the given MIME type. Handles nested multipart/* containers.
private func extractPart(_ payload: MessagePayload, mimeType: String) -> String? {
    // Direct body on this node (leaf part).
    if let encoded = payload.body?.data,
       payload.parts == nil || payload.parts!.isEmpty,
       let decoded = base64URLDecode(encoded) {
        // If a mimeType was declared on this node via a Content-Type header,
        // check it; otherwise accept it only for text/plain (safe default).
        let ct = (payload.headers?.first { $0.name.lowercased() == "content-type" }?.value ?? "").lowercased()
        // Accept if Content-Type matches, or if no type declared (let caller decide).
        if ct.hasPrefix(mimeType) || ct.isEmpty {
            return decoded
        }
    }
    // Recurse into sub-parts.
    for part in payload.parts ?? [] {
        if let found = extractPart(part, mimeType: mimeType) { return found }
    }
    return nil
}

/// Collapse HTML to plain text: replace block-level tags with newlines, strip
/// all remaining tags, decode common entities. Good enough for phrase matching.
private func stripHTML(_ html: String) -> String {
    // Block tags → newline so sentences don't run together.
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
    // Strip all remaining tags.
    if let re = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
        text = re.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
    }
    // Decode common HTML entities.
    text = text
        .replacingOccurrences(of: "&amp;",  with: "&")
        .replacingOccurrences(of: "&lt;",   with: "<")
        .replacingOccurrences(of: "&gt;",   with: ">")
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&#39;",  with: "'")
        .replacingOccurrences(of: "&quot;", with: "\"")
    // Collapse runs of whitespace/newlines left by tag removal.
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

private func base64URLDecode(_ input: String) -> String? {
    var s = input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s += "=" }
    guard let data = Data(base64Encoded: s) else { return nil }
    return String(data: data, encoding: .utf8)
}
