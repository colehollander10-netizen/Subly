import Foundation

/// Result of classifying a Gmail message. Everything optional because
/// real-world email is messy — callers decide whether a partial hit is enough.
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
    public let billing: BillingInterval
    public let trialEndDate: Date?
    public let sourceMessageID: String
    public let detectedAt: Date

    public init(
        serviceName: String,
        senderDomain: String,
        event: EventKind,
        amount: Decimal?,
        billing: BillingInterval,
        trialEndDate: Date?,
        sourceMessageID: String,
        detectedAt: Date
    ) {
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.event = event
        self.amount = amount
        self.billing = billing
        self.trialEndDate = trialEndDate
        self.sourceMessageID = sourceMessageID
        self.detectedAt = detectedAt
    }
}

public enum SubscriptionParser {
    /// Fast metadata-only pass. Returns nil when nothing about the sender or
    /// subject looks subscription-shaped; otherwise returns a ParsedSubscription
    /// with whatever could be inferred from headers alone (no amount yet).
    public static func classifyMetadata(_ message: GmailMessage, now: Date = Date()) -> ParsedSubscription? {
        let headers = message.payload?.headers ?? []
        let from = header(headers, "From") ?? ""
        let subject = header(headers, "Subject") ?? ""
        let snippet = message.snippet ?? ""

        let domain = senderDomain(from: from)
        guard !domain.isEmpty, !isNoiseDomain(domain) else { return nil }

        let event = classifyEvent(subject: subject, snippet: snippet)
        let isSubjectSignal = hasSubscriptionSignal(subject) || hasSubscriptionSignal(snippet)
        guard event != .unknown || isSubjectSignal else { return nil }

        return ParsedSubscription(
            serviceName: serviceName(fromDomain: domain, from: from),
            senderDomain: domain,
            event: event,
            amount: nil,
            billing: .unknown,
            trialEndDate: nil,
            sourceMessageID: message.id,
            detectedAt: now
        )
    }

    /// Full-body pass. Extracts amount + billing interval + trial end where possible.
    /// Falls back to metadata-level info if the body doesn't add anything.
    public static func classifyFull(_ message: GmailMessage, now: Date = Date()) -> ParsedSubscription? {
        guard let base = classifyMetadata(message, now: now) else { return nil }
        let body = decodedBody(message.payload) ?? message.snippet ?? ""
        let amount = parseAmount(body)
        let billing = parseBilling(body)
        let trialEnd = parseTrialEndDate(body, reference: now)

        return ParsedSubscription(
            serviceName: base.serviceName,
            senderDomain: base.senderDomain,
            event: base.event,
            amount: amount,
            billing: billing,
            trialEndDate: trialEnd,
            sourceMessageID: base.sourceMessageID,
            detectedAt: base.detectedAt
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

private func isNoiseDomain(_ domain: String) -> Bool {
    let noise = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "me.com"]
    return noise.contains(domain)
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
    // "Netflix <info@netflix.com>" → "Netflix"
    guard let angle = from.firstIndex(of: "<") else { return nil }
    let name = from[..<angle]
        .trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    return name.isEmpty ? nil : name
}

// MARK: - Subject/snippet classification

private let subscriptionSignalTerms: [String] = [
    "subscription", "subscribed", "renewal", "renew", "auto-renew", "auto renew",
    "receipt", "invoice", "payment", "billing", "billed", "charge",
    "membership", "premium", "plan", "upgrade", "downgrade",
    "welcome", "confirmation", "confirmed", "trial", "free trial",
    "canceled", "cancelled", "paused", "refund",
    "thanks for subscribing", "your order",
]

private func hasSubscriptionSignal(_ text: String) -> Bool {
    let lower = text.lowercased()
    return subscriptionSignalTerms.contains { lower.contains($0) }
}

private func classifyEvent(subject: String, snippet: String) -> ParsedSubscription.EventKind {
    let text = (subject + " " + snippet).lowercased()
    if text.contains("cancel") { return .canceled }
    if text.contains("paused") || text.contains("on hold") { return .paused }
    if text.contains("free trial") || text.contains("trial started") || text.contains("your trial") {
        return .trialStart
    }
    if text.contains("renew") || text.contains("auto-renew") || text.contains("auto renew") {
        return .renewal
    }
    if text.contains("welcome") || text.contains("thanks for subscribing") || text.contains("confirmation") {
        return .welcome
    }
    if text.contains("receipt") || text.contains("invoice") || text.contains("payment") || text.contains("billed") {
        return .receipt
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

// MARK: - Amount / billing / trial extraction

private func parseAmount(_ body: String) -> Decimal? {
    // Matches $12, $12.99, US$12.99, USD 12.99
    let pattern = #"(?:US\$|USD\s*|\$)\s*(\d+(?:\.\d{1,2})?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    guard let match = regex.firstMatch(in: body, options: [], range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: body)
    else { return nil }
    return Decimal(string: String(body[valueRange]))
}

private func parseBilling(_ body: String) -> ParsedSubscription.BillingInterval {
    let lower = body.lowercased()
    if lower.contains("per year") || lower.contains("/year") || lower.contains("annual") || lower.contains("yearly") {
        return .annual
    }
    if lower.contains("per month") || lower.contains("/month") || lower.contains("monthly") {
        return .monthly
    }
    return .unknown
}

private func parseTrialEndDate(_ body: String, reference: Date) -> Date? {
    // Look for "trial ends on Mar 15" / "free until 2026-04-30" — good-enough heuristic for v1.
    let lower = body.lowercased()
    guard lower.contains("trial") || lower.contains("free until") else { return nil }

    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    let matches = detector?.matches(in: body, options: [], range: range) ?? []
    return matches.compactMap { $0.date }.first { $0 > reference }
}
