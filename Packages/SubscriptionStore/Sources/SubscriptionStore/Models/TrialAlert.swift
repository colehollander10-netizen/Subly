import Foundation
import SwiftData

/// Public alert-kind enum used by the engine and UI. Not stored directly on
/// the SwiftData model — SwiftData's built-in coder trips on `Codable` enums
/// with associated values, so `TrialAlert` persists flat scalars and exposes
/// `alertType` as a computed property.
public enum AlertType: Sendable, Equatable, Hashable {
    case threeDaysBefore
    case dayOf
    case dayBefore
    case custom(days: Int)

    public var storageKind: String {
        switch self {
        case .threeDaysBefore: return "threeDaysBefore"
        case .dayOf: return "dayOf"
        case .dayBefore: return "dayBefore"
        case .custom: return "custom"
        }
    }

    public var storageDays: Int? {
        if case .custom(let d) = self { return d }
        return nil
    }

    public static func from(kind: String, days: Int?) -> AlertType {
        switch kind {
        case "threeDaysBefore": return .threeDaysBefore
        case "dayOf": return .dayOf
        case "dayBefore": return .dayBefore
        case "custom": return .custom(days: days ?? 0)
        default: return .dayOf
        }
    }
}

@Model
public final class TrialAlert {
    public var id: UUID
    /// The Trial this alert belongs to.
    public var trialID: UUID
    public var triggerDate: Date
    /// Raw kind string — do not set directly; use `alertType`.
    public var alertKind: String
    /// Days offset for `.custom`; nil for other kinds.
    public var alertDays: Int?
    public var delivered: Bool

    public var alertType: AlertType {
        get { AlertType.from(kind: alertKind, days: alertDays) }
        set {
            alertKind = newValue.storageKind
            alertDays = newValue.storageDays
        }
    }

    public init(
        id: UUID,
        trialID: UUID,
        triggerDate: Date,
        alertType: AlertType,
        delivered: Bool
    ) {
        self.id = id
        self.trialID = trialID
        self.triggerDate = triggerDate
        self.alertKind = alertType.storageKind
        self.alertDays = alertType.storageDays
        self.delivered = delivered
    }
}
