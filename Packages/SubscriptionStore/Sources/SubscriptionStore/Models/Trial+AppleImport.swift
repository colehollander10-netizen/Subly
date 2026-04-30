import Foundation
import SwiftData

public extension Trial {
    static func upsertAppleSubscription(
        originalTransactionID: String,
        serviceName: String,
        chargeDate: Date,
        chargeAmount: Decimal?,
        billingCycle: BillingCycle,
        status: EntryStatus = .active,
        in context: ModelContext
    ) throws -> (trial: Trial, inserted: Bool) {
        var descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate { trial in
                trial.appleOriginalTransactionID == originalTransactionID
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            // Refresh every Apple-sourced field so changes pushed by Apple
            // (renames, plan upgrades that flip the cadence, price increases)
            // land on the existing row instead of stale-imported metadata
            // sticking around forever. Fields Apple does not own
            // (notificationOffset, senderDomain) are intentionally left
            // untouched.
            if !serviceName.isEmpty {
                existing.serviceName = serviceName
            }
            existing.chargeDate = chargeDate
            existing.chargeAmount = chargeAmount
            existing.billingCycle = billingCycle
            existing.entryType = .subscription
            existing.status = status
            return (existing, false)
        }

        let trial = Trial(
            serviceName: serviceName,
            senderDomain: "",
            chargeDate: chargeDate,
            chargeAmount: chargeAmount,
            entryType: .subscription,
            status: status,
            billingCycle: billingCycle,
            appleOriginalTransactionID: originalTransactionID
        )
        context.insert(trial)
        return (trial, true)
    }
}
