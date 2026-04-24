import Foundation
import StoreKit
import SubscriptionStore

actor StoreKitImport {
    func fetchCurrentEntitlements() async throws -> [ImportableSubscription] {
        var subscriptions: [ImportableSubscription] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productType == .autoRenewable else { continue }

            let products = try await Product.products(for: [transaction.productID])
            guard let product = products.first else { continue }
            guard let subscriptionPeriod = product.subscription?.subscriptionPeriod else { continue }

            var nextBillingDate: Date?
            if let status = await transaction.subscriptionStatus,
               case .verified(let renewalInfo) = status.renewalInfo {
                nextBillingDate = renewalInfo.renewalDate
            }

            subscriptions.append(
                ImportableSubscription(
                    id: transaction.productID,
                    displayName: product.displayName,
                    amount: product.price,
                    billingCycle: Self.billingCycle(from: subscriptionPeriod.unit),
                    nextBillingDate: nextBillingDate
                )
            )
        }

        return subscriptions
    }

    static func billingCycle(from unit: Product.SubscriptionPeriod.Unit) -> BillingCycle {
        switch unit {
        case .day:
            return .weekly
        case .week:
            return .weekly
        case .month:
            return .monthly
        case .year:
            return .yearly
        @unknown default:
            return .monthly
        }
    }
}
