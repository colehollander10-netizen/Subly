import Foundation
import OSLog
import StoreKit
import SubscriptionStore
import SwiftData

@MainActor
final class AutoImportService {
    private let log = Logger(subsystem: "com.subly.Subly", category: "auto-import")
    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func sync(context: ModelContext) async {
        let subs = await StoreKitImport.fetchCurrent()

        for sub in subs {
            guard let originalID = sub.appleOriginalTransactionID else { continue }

            do {
                _ = try Trial.upsertAppleSubscription(
                    originalTransactionID: originalID,
                    serviceName: sub.displayName,
                    chargeDate: sub.nextBillingDate ?? fallbackChargeDate(),
                    chargeAmount: sub.amount,
                    billingCycle: sub.billingCycle,
                    in: context
                )
            } catch {
                log.error("Auto-import upsert failed for \(sub.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        do {
            try context.save()
        } catch {
            log.error("Auto-import save failed: \(String(describing: error), privacy: .public)")
        }

        UserDefaults.standard.set(Date(), forKey: "lastAppleSync")
    }

    func startTransactionUpdates(context: ModelContext) {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.process(update: update, context: context)
            }
        }
    }

    private func process(update: VerificationResult<Transaction>, context: ModelContext) async {
        guard case .verified(let transaction) = update else { return }

        if let sub = await StoreKitImport.importableSubscription(from: transaction),
           !sub.id.isEmpty,
           let originalID = sub.appleOriginalTransactionID {
            do {
                _ = try Trial.upsertAppleSubscription(
                    originalTransactionID: originalID,
                    serviceName: sub.displayName,
                    chargeDate: sub.nextBillingDate ?? fallbackChargeDate(),
                    chargeAmount: sub.amount,
                    billingCycle: sub.billingCycle,
                    in: context
                )
                try context.save()
            } catch {
                log.error("Transaction update upsert failed for \(sub.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        await transaction.finish()
    }

    private func fallbackChargeDate() -> Date {
        Date().addingTimeInterval(60 * 60 * 24 * 30)
    }
}
