import Foundation
import SubscriptionStore

struct ImportableSubscription: Identifiable, Equatable {
    let id: String
    let displayName: String
    let amount: Decimal
    let billingCycle: BillingCycle
    let nextBillingDate: Date?
    let appleOriginalTransactionID: String?
}
