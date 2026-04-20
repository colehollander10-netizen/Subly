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

    public init(
        id: UUID,
        serviceName: String,
        senderDomain: String,
        logoURL: URL?,
        status: SubscriptionStatus,
        amount: Decimal?,
        billingCycle: BillingCycle?,
        detectedAt: Date,
        sourceEmailID: String,
        trialEndDate: Date?,
        regularAmount: Decimal? = nil,
        introPriceEndDate: Date? = nil,
        userDismissed: Bool = false
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
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
    }
}
