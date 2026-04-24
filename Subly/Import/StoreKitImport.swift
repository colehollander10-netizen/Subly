import Foundation
import OSLog
import StoreKit
import SubscriptionStore

actor StoreKitImport {
    private static let log = Logger(subsystem: "com.subly.Subly", category: "storekit-import")

    static func fetchCurrent() async -> [ImportableSubscription] {
        await StoreKitImport().fetchCurrentEntitlements()
    }

    func fetchCurrentEntitlements() async -> [ImportableSubscription] {
        var subscriptions: [ImportableSubscription] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let subscription = await Self.importableSubscription(from: transaction) else { continue }
            subscriptions.append(subscription)
        }

        return subscriptions
    }

    static func importableSubscription(from transaction: Transaction) async -> ImportableSubscription? {
        guard transaction.revocationDate == nil else { return nil }
        guard transaction.productType == .autoRenewable else { return nil }

        do {
            let products = try await Product.products(for: [transaction.productID])
            guard let product = products.first else { return nil }
            guard let subscriptionPeriod = product.subscription?.subscriptionPeriod else { return nil }

            var nextBillingDate: Date?
            if let status = await transaction.subscriptionStatus,
               case .verified(let renewalInfo) = status.renewalInfo {
                nextBillingDate = renewalInfo.renewalDate
            }

            return ImportableSubscription(
                id: transaction.productID,
                displayName: product.displayName,
                amount: product.price,
                billingCycle: billingCycle(from: subscriptionPeriod.unit),
                nextBillingDate: nextBillingDate,
                appleOriginalTransactionID: String(transaction.originalID)
            )
        } catch {
            log.error("StoreKit product lookup failed for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
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
