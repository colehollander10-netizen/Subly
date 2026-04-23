import Foundation
import SwiftData

/// Pre-pivot model shapes. These are frozen — DO NOT modify after the
/// subscription-pivot migration has shipped, because `SublyMigrationPlan`
/// reads FROM these types when migrating legacy on-disk data.
///
/// The types are distinct classes (`TrialV1`, `TrialAlertV1`) so SwiftData
/// can load a V1 store independently of the current live schema (`Trial`,
/// `TrialAlert` in the top-level module).

@Model
public final class TrialV1 {
    @Attribute(.unique) public var id: UUID
    public var serviceName: String
    public var senderDomain: String
    public var trialEndDate: Date
    public var chargeAmount: Decimal?
    public var detectedAt: Date
    public var userDismissed: Bool
    public var trialLengthDays: Int? = nil

    public init(
        id: UUID = UUID(),
        serviceName: String,
        senderDomain: String = "",
        trialEndDate: Date,
        chargeAmount: Decimal?,
        detectedAt: Date = Date(),
        userDismissed: Bool = false,
        trialLengthDays: Int? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.trialEndDate = trialEndDate
        self.chargeAmount = chargeAmount
        self.detectedAt = detectedAt
        self.userDismissed = userDismissed
        self.trialLengthDays = trialLengthDays
    }
}

@Model
public final class TrialAlertV1 {
    public var id: UUID
    public var trialID: UUID
    public var triggerDate: Date
    public var alertKind: String
    public var alertDays: Int?
    public var delivered: Bool

    public init(
        id: UUID,
        trialID: UUID,
        triggerDate: Date,
        alertKind: String,
        alertDays: Int?,
        delivered: Bool
    ) {
        self.id = id
        self.trialID = trialID
        self.triggerDate = triggerDate
        self.alertKind = alertKind
        self.alertDays = alertDays
        self.delivered = delivered
    }
}

public enum SublySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [TrialV1.self, TrialAlertV1.self]
    }
}
