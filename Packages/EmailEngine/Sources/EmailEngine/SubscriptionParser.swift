import Foundation
import OSLog

private let parserLog = Logger(subsystem: "com.subly.Subly", category: "parser")

// MARK: - Detected trial (value type)

/// A trial detected from a Gmail message that meets all four gates:
///  1. Mentions a free trial.
///  2. Has a known trial end date.
///  3. Has a card (or equivalent billing method) on file.
///  4. References an auto-charge after the trial ends.
///
/// `TrialParser` returns `nil` for any message that fails a gate — we
/// deliberately do not surface low-confidence trials or "free forever"
/// freemium signup emails.
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

// MARK: - Parser

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

        let hasTrialMention = subject.contains("trial") || subject.contains("free")
        return hasTrialMention
    }

    /// Parse a full Gmail message into a `DetectedTrial` or reject it.
    /// All four gates must pass: trial mention, end date, card-on-file,
    /// and auto-charge language.
    public static func detect(_ message: GmailMessage, now: Date = Date()) -> DetectedTrial? {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = (header(headers, "Subject") ?? "")
        let domain = senderDomain(from: from)
        let msgID = message.id
        if domain.isEmpty {
            parserLog.debug("reject[\(msgID, privacy: .public)] gate0=no-domain from=\(from, privacy: .public)")
            return nil
        }
        if isNoiseDomain(domain) {
            parserLog.debug("reject[\(msgID, privacy: .public)] gate0=noise-domain domain=\(domain, privacy: .public)")
            return nil
        }

        // Gate 0.5: marketing/promo subject — reject emails inviting the user to
        // *start* a trial (vs. confirming one started). These otherwise slip
        // through gates 1-4 because the body is full of "will be charged",
        // "payment method", and "X day" phrasing describing the future offer.
        if isMarketingSubject(subject) {
            parserLog.info("reject[\(msgID, privacy: .public)] gate0.5=marketing-subject domain=\(domain, privacy: .public) subject=\(subject, privacy: .public)")
            return nil
        }

        guard let bodyRaw = decodedBody(message.payload) else {
            parserLog.debug("reject[\(msgID, privacy: .public)] gate0=no-body domain=\(domain, privacy: .public) subject=\(subject, privacy: .public)")
            return nil
        }
        let body = bodyRaw.lowercased()
        let subjectLower = subject.lowercased()
        let newlineCount = bodyRaw.filter { $0 == "\n" }.count
        let bodyLen = bodyRaw.count

        // Gate 1: must mention a trial somewhere.
        guard mentionsTrial(subject: subjectLower, body: body) else {
            parserLog.info("reject[\(msgID, privacy: .public)] gate1=no-trial-mention domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) bodyLen=\(bodyLen, privacy: .public) newlines=\(newlineCount, privacy: .public)")
            return nil
        }

        // Gate 2: trial end date must be extractable.
        let sentDate = message.sentDate ?? now
        guard let trialEndDate = extractTrialEndDate(body: bodyRaw, sentDate: sentDate) else {
            let preview = String(bodyRaw.prefix(500))
            parserLog.info("reject[\(msgID, privacy: .public)] gate2=no-end-date domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) bodyLen=\(bodyLen, privacy: .public) newlines=\(newlineCount, privacy: .public) preview=\(preview, privacy: .public)")
            return nil
        }
        guard trialEndDate > now else {
            parserLog.info("reject[\(msgID, privacy: .public)] gate2=date-in-past domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) endDate=\(trialEndDate, privacy: .public)")
            return nil
        }

        // Gate 3: card / billing method on file.
        guard hasCardOnFile(body: body) else {
            let preview = String(bodyRaw.prefix(500))
            parserLog.info("reject[\(msgID, privacy: .public)] gate3=no-card-on-file domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) bodyLen=\(bodyLen, privacy: .public) preview=\(preview, privacy: .public)")
            return nil
        }

        // Gate 4: auto-charge language.
        guard hasAutoChargeLanguage(body: body) else {
            let preview = String(bodyRaw.prefix(500))
            parserLog.info("reject[\(msgID, privacy: .public)] gate4=no-auto-charge domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) bodyLen=\(bodyLen, privacy: .public) preview=\(preview, privacy: .public)")
            return nil
        }

        let chargeAmount = extractAmount(body: bodyRaw)
        let service = serviceName(fromDomain: domain, from: from)
        let acceptPreview = String(bodyRaw.prefix(3000))
        parserLog.info("accept[\(msgID, privacy: .public)] service=\(service, privacy: .public) domain=\(domain, privacy: .public) subject=\(subject, privacy: .public) endDate=\(trialEndDate, privacy: .public) bodyLen=\(bodyLen, privacy: .public) preview=\(acceptPreview, privacy: .public)")

        return DetectedTrial(
            serviceName: service,
            senderDomain: domain,
            trialEndDate: trialEndDate,
            chargeAmount: chargeAmount,
            sourceMessageID: message.id,
            detectedAt: sentDate
        )
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

    // Leading imperative verbs that signal an offer, not a confirmation.
    let promoVerbs = [
        "claim",
        "unlock",
        "score",
        "grab",
        "get ",        // "get 2 months free" — trailing space avoids "getting started"
        "try ",
        "start your",  // "Start your free trial today" = promo CTA
        "don't miss",
        "dont miss",
        "last chance",
        "limited time",
        "save ",
        "introducing",
        "meet ",
    ]
    if promoVerbs.contains(where: { lower.hasPrefix($0) }) { return true }

    // Promo phrases that can appear anywhere in the subject.
    let promoMarkers = [
        "limited time",
        "for a limited",
        "offer ends",
        "% off",
        "months free",       // "5 months free" / "2 months free" = promo
        "free months",
        "exclusive offer",
    ]
    return promoMarkers.contains { lower.contains($0) }
}

private func mentionsTrial(subject: String, body: String) -> Bool {
    let phrases = [
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
    return phrases.contains { subject.contains($0) || body.contains($0) }
}

private func hasCardOnFile(body: String) -> Bool {
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
    // Narrow the search to sentences that mention "trial" — avoids grabbing
    // unrelated dates (shipping estimates, event dates, etc.).
    let lines = body.components(separatedBy: .newlines)
    for line in lines where line.lowercased().contains("trial") || line.lowercased().contains("ends") || line.lowercased().contains("charge") {
        let range = NSRange(line.startIndex..., in: line)
        if let match = detector.matches(in: line, options: [], range: range).first,
           let date = match.date {
            return date
        }
    }
    return nil
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
    let pattern = #"\$\s?(\d{1,4}(?:\.\d{2})?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return nil
    }
    let range = NSRange(body.startIndex..., in: body)
    guard let match = regex.matches(in: body, options: [], range: range).first,
          match.numberOfRanges >= 2,
          let r = Range(match.range(at: 1), in: body)
    else { return nil }
    return Decimal(string: String(body[r]))
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
    if let encoded = payload.body?.data, let decoded = base64URLDecode(encoded) {
        return decoded
    }
    // Walk parts depth-first, concatenating everything we can decode.
    var pieces: [String] = []
    for part in payload.parts ?? [] {
        if let sub = decodedBody(part) { pieces.append(sub) }
    }
    return pieces.isEmpty ? nil : pieces.joined(separator: "\n")
}

private func base64URLDecode(_ input: String) -> String? {
    var s = input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while s.count % 4 != 0 { s += "=" }
    guard let data = Data(base64Encoded: s) else { return nil }
    return String(data: data, encoding: .utf8)
}
