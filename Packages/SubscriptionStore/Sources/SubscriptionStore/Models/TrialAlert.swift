import Foundation
import SwiftData

public enum AlertType: Codable, Sendable, Equatable {
    case dayBefore
    case custom(days: Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case days
    }

    private enum Kind: String, Codable {
        case dayBefore
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .dayBefore:
            self = .dayBefore
        case .custom:
            self = .custom(days: try container.decode(Int.self, forKey: .days))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .dayBefore:
            try container.encode(Kind.dayBefore, forKey: .kind)
        case .custom(let days):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(days, forKey: .days)
        }
    }
}

@Model
public final class TrialAlert {
    public var id: UUID
    public var subscriptionID: UUID
    public var triggerDate: Date
    public var alertType: AlertType
    public var delivered: Bool

    public init(
        id: UUID,
        subscriptionID: UUID,
        triggerDate: Date,
        alertType: AlertType,
        delivered: Bool
    ) {
        self.id = id
        self.subscriptionID = subscriptionID
        self.triggerDate = triggerDate
        self.alertType = alertType
        self.delivered = delivered
    }
}
