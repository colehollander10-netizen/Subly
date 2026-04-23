import Foundation
import SwiftData

/// A user-tracked financial event — a free trial or a recurring subscription.
///
/// The class is named `Trial` for backwards compatibility with the pre-pivot
/// codebase; the `entryType` field disambiguates at every read site. A rename
/// to `SublyEntry` is deferred to v1.1 to keep the pivot's churn bounded.
///
/// Field lineage (schema v2):
/// - `chargeDate` replaces `trialEndDate` — the SwiftData `originalName`
///   attribute tells SwiftData to carry the old column into the new one
///   on lightweight migration.
/// - `entryTypeRaw`, `statusRaw`, `billingCycleRaw`, `notificationOffset`,
///   and `cancelledAt` are new.
@Model
public final class Trial {
    @Attribute(.unique) public var id: UUID
    public var serviceName: String
    /// Optional hint for logo lookup. Empty string when unknown.
    public var senderDomain: String

    /// When money is scheduled to leave the user's account. For trials this is
    /// the trial end date; for subscriptions this is the next billing date.
    @Attribute(originalName: "trialEndDate")
    public var chargeDate: Date

    public var chargeAmount: Decimal?
    public var detectedAt: Date
    public var userDismissed: Bool
    /// Length of the trial in whole days, when known. 7, 14, 30, 90, 365 are common.
    /// Only meaningful when `entryType == .freeTrial`.
    public var trialLengthDays: Int? = nil

    // --- Subscription pivot (schema v2) ---

    /// Raw backing field for `entryType`. SwiftData prefers stored scalars
    /// over computed/transformable enum storage, so the enum is exposed via
    /// a computed property. Default: `EntryType.freeTrial.rawValue`.
    public var entryTypeRaw: String

    /// Raw backing field for `status`. Default: `EntryStatus.active.rawValue`.
    public var statusRaw: String

    /// Raw backing field for `billingCycle`. Nil when `entryType == .freeTrial`.
    public var billingCycleRaw: String?

    /// Per-entry override for notification lead time, in days before chargeDate.
    /// Nil falls back to the global default for this entry's `entryType`.
    public var notificationOffset: Int?

    /// Set once when `status` flips to `.cancelled`. Used to compute
    /// "Caught $X this month" on HomeView.
    public var cancelledAt: Date?

    public var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .freeTrial }
        set { entryTypeRaw = newValue.rawValue }
    }

    public var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public var billingCycle: BillingCycle? {
        get { billingCycleRaw.flatMap(BillingCycle.init(rawValue:)) }
        set { billingCycleRaw = newValue?.rawValue }
    }

    public init(
        id: UUID = UUID(),
        serviceName: String,
        senderDomain: String = "",
        chargeDate: Date,
        chargeAmount: Decimal?,
        detectedAt: Date = Date(),
        userDismissed: Bool = false,
        trialLengthDays: Int? = nil,
        entryType: EntryType = .freeTrial,
        status: EntryStatus = .active,
        billingCycle: BillingCycle? = nil,
        notificationOffset: Int? = nil,
        cancelledAt: Date? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.chargeDate = chargeDate
        self.chargeAmount = chargeAmount
        self.detectedAt = detectedAt
        self.userDismissed = userDismissed
        self.trialLengthDays = trialLengthDays
        self.entryTypeRaw = entryType.rawValue
        self.statusRaw = status.rawValue
        self.billingCycleRaw = billingCycle?.rawValue
        self.notificationOffset = notificationOffset
        self.cancelledAt = cancelledAt
    }
}
