import Foundation
import SwiftData

public enum SubscriptionStatus: String, Codable, Sendable {
    case active, trial, paused, canceled
}

public enum BillingCycle: String, Codable, Sendable {
    case monthly, annual, unknown
}

@Model
public final class Subscription {
    public var id: UUID
    public var serviceName: String
    public var senderDomain: String
    /// Per-account identifier within a sender (handle, billed-to email, or last-4).
    /// Empty string when nothing distinguishes accounts on the same service.
    public var accountIdentifier: String
    public var logoURL: URL?
    public var status: SubscriptionStatus
    public var amount: Decimal?
    public var billingCycle: BillingCycle?
    public var detectedAt: Date
    public var sourceEmailID: String
    public var trialEndDate: Date?

    /// If this sub has an introductory/promo price, the real ongoing price
    /// after the intro window ends. Nil when there's no promo.
    public var regularAmount: Decimal?
    /// When the promotional pricing ends and regularAmount kicks in.
    public var introPriceEndDate: Date?

    /// User flagged this row as "not a subscription" during onboarding review.
    /// Hidden from the main list but kept so we don't re-detect the same email.
    public var userDismissed: Bool

    /// Parser's confidence this row is a real active subscription (0.0–1.0).
    /// ≥0.7 = shown in "Detected"; 0.4–0.7 = shown in "Review these".
    public var confidence: Double

    /// User's verdict. nil = untouched, true = thumbed up (promote to Detected),
    /// false = thumbed down (same as userDismissed — kept separate so we can
    /// distinguish explicit rejection from pre-confirmation state).
    public var userConfirmed: Bool?

    /// True when the source email shows a card/PayPal on file and an automatic
    /// future charge. Drives the "Will charge $X on [date]" warning in the UI
    /// and the cancel-before-charge reminder. Defaults to false so existing
    /// SwiftData rows from before this field migrate cleanly.
    public var willAutoCharge: Bool = false

    public init(
        id: UUID,
        serviceName: String,
        senderDomain: String,
        accountIdentifier: String = "",
        logoURL: URL?,
        status: SubscriptionStatus,
        amount: Decimal?,
        billingCycle: BillingCycle?,
        detectedAt: Date,
        sourceEmailID: String,
        trialEndDate: Date?,
        regularAmount: Decimal? = nil,
        introPriceEndDate: Date? = nil,
        userDismissed: Bool = false,
        confidence: Double = 0.5,
        userConfirmed: Bool? = nil,
        willAutoCharge: Bool = false
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.accountIdentifier = accountIdentifier
        self.logoURL = logoURL
        self.status = status
        self.amount = amount
        self.billingCycle = billingCycle
        self.detectedAt = detectedAt
        self.sourceEmailID = sourceEmailID
        self.trialEndDate = trialEndDate
        self.regularAmount = regularAmount
        self.introPriceEndDate = introPriceEndDate
        self.userDismissed = userDismissed
        self.confidence = confidence
        self.userConfirmed = userConfirmed
        self.willAutoCharge = willAutoCharge
    }
}
