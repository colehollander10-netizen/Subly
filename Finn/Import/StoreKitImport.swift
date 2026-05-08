import Foundation
import OSLog
import StoreKit
import SubscriptionStore

actor StoreKitImport {
    private static let log = Logger(subsystem: "com.colehollander.finn", category: "storekit-import")

    /// Convenience for callers that only want the importable rows.
    static func fetchCurrent() async -> [ImportableSubscription] {
        await fetchCurrentOutcomes().compactMap { outcome in
            if case .importable(let sub) = outcome.result { return sub }
            return nil
        }
    }

    /// Returns the full per-transaction outcome list so callers can show
    /// concrete skip reasons instead of treating skipped items as silent
    /// `nil`s. This is what `AutoImportService` uses to build a UI summary.
    static func fetchCurrentOutcomes() async -> [ImportOutcome] {
        await StoreKitImport().loadCurrentEntitlementOutcomes()
    }

    func loadCurrentEntitlementOutcomes() async -> [ImportOutcome] {
        var outcomes: [ImportOutcome] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            let outcome = await Self.importOutcome(from: transaction)
            outcomes.append(outcome)
        }

        return outcomes
    }

    /// Backwards-compatible wrapper retained for `AutoImportService.process(update:)`.
    static func importableSubscription(from transaction: Transaction) async -> ImportableSubscription? {
        let outcome = await importOutcome(from: transaction)
        if case .importable(let sub) = outcome.result { return sub }
        return nil
    }

    /// Map a verified `Transaction` to an `ImportOutcome`. Returns
    /// `.skipped(_)` rather than `nil` so the caller can attribute every
    /// non-imported row to a concrete cause.
    static func importOutcome(from transaction: Transaction) async -> ImportOutcome {
        let originalID = String(transaction.originalID)
        let productID = transaction.productID

        guard transaction.revocationDate == nil else {
            return ImportOutcome(productID: productID, originalTransactionID: originalID, result: .skipped(.revoked))
        }
        guard transaction.productType == .autoRenewable else {
            return ImportOutcome(productID: productID, originalTransactionID: originalID, result: .skipped(.nonAutoRenewable))
        }

        let product: Product?
        do {
            product = try await Product.products(for: [productID]).first
        } catch {
            log.error("StoreKit product lookup failed for \(productID, privacy: .public): \(String(describing: error), privacy: .public)")
            return ImportOutcome(
                productID: productID,
                originalTransactionID: originalID,
                result: .skipped(.productLookupFailed(error.localizedDescription))
            )
        }

        // No product back from StoreKit can happen in sandbox/StoreKit Config
        // when a product is mid-rollout or not configured locally. Skip
        // rather than fabricate metadata.
        guard let product else {
            return ImportOutcome(
                productID: productID,
                originalTransactionID: originalID,
                result: .skipped(.productLookupFailed("Product not returned by Apple"))
            )
        }
        guard let subscriptionPeriod = product.subscription?.subscriptionPeriod else {
            return ImportOutcome(
                productID: productID,
                originalTransactionID: originalID,
                result: .skipped(.missingSubscriptionPeriod)
            )
        }

        var nextBillingDate: Date?
        if let status = await transaction.subscriptionStatus,
           case .verified(let renewalInfo) = status.renewalInfo {
            nextBillingDate = renewalInfo.renewalDate
        }

        // Display name fallback: some StoreKit configurations return a
        // product without a localized display name. Falling back to the
        // productID keeps the row visible instead of a blank label.
        let displayName = product.displayName.isEmpty ? productID : product.displayName

        let sub = ImportableSubscription(
            id: productID,
            displayName: displayName,
            amount: product.price,
            billingCycle: billingCycle(from: subscriptionPeriod.unit),
            nextBillingDate: nextBillingDate,
            appleOriginalTransactionID: originalID
        )
        return ImportOutcome(productID: productID, originalTransactionID: originalID, result: .importable(sub))
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
