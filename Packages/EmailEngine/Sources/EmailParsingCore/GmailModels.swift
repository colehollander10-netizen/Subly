import Foundation

public enum GmailQuery {
    /// Full-email trial net. Casts a wide enough mesh that most real trial
    /// receipts show up; the confidence-tier parser is the actual arbiter for
    /// what becomes a tracked trial or a manual-review lead.
    public static let trialsRecent: String = {
        let terms = [
            "free trial",
            "your trial",
            "trial ends",
            "trial will end",
            "trial period",
            "start your free",
            "your free trial",
            "free trial ends",
            "free trial has started",
            "subscription will begin",
            "will be charged",
            "will automatically charge",
            "you'll be charged",
            "your payment of",
            "we've charged",
            "thank you for your order",
            "subscription confirmation",
            "your microsoft",
            "your subscription has started",
            "your subscription starts",
            "subscription renews",
            "your purchase of",
            "has been processed",
            "order confirmation",
            "receipt for your",
        ]
        let quoted = terms.map { "\"\($0)\"" }
        return "(\(quoted.joined(separator: " OR "))) newer_than:364d"
    }()
}

public struct MessageListResponse: Decodable, Sendable {
    public let messages: [MessageRef]?
    public let nextPageToken: String?
    public let resultSizeEstimate: Int?
}

public struct MessageRef: Decodable, Sendable {
    public let id: String
    public let threadId: String
}

public struct GmailMessage: Decodable, Sendable {
    public let id: String
    public let threadId: String
    public let payload: MessagePayload?
    public let snippet: String?
    public let internalDate: String?

    public var sentDate: Date? {
        guard let internalDate, let ms = Double(internalDate) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    public init(
        id: String,
        threadId: String,
        payload: MessagePayload?,
        snippet: String?,
        internalDate: String?
    ) {
        self.id = id
        self.threadId = threadId
        self.payload = payload
        self.snippet = snippet
        self.internalDate = internalDate
    }
}

public struct MessagePayload: Decodable, Sendable {
    public let headers: [MessageHeader]?
    public let body: MessageBody?
    public let parts: [MessagePayload]?

    public init(headers: [MessageHeader]?, body: MessageBody?, parts: [MessagePayload]?) {
        self.headers = headers
        self.body = body
        self.parts = parts
    }
}

public struct MessageHeader: Decodable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct MessageBody: Decodable, Sendable {
    public let data: String?
    public let size: Int

    public init(data: String?, size: Int) {
        self.data = data
        self.size = size
    }
}
