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
    public var logoURL: URL?
    public var status: SubscriptionStatus
    public var amount: Decimal?
    public var billingCycle: BillingCycle?
    public var detectedAt: Date
    public var sourceEmailID: String
    public var trialEndDate: Date?

    public init(
        id: UUID,
        serviceName: String,
        logoURL: URL?,
        status: SubscriptionStatus,
        amount: Decimal?,
        billingCycle: BillingCycle?,
        detectedAt: Date,
        sourceEmailID: String,
        trialEndDate: Date?
    ) {
        self.id = id
        self.serviceName = serviceName
        self.logoURL = logoURL
        self.status = status
        self.amount = amount
        self.billingCycle = billingCycle
        self.detectedAt = detectedAt
        self.sourceEmailID = sourceEmailID
        self.trialEndDate = trialEndDate
    }
}
