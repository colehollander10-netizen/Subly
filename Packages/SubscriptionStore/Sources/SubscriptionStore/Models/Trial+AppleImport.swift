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
            existing.chargeDate = chargeDate
            existing.chargeAmount = chargeAmount
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
