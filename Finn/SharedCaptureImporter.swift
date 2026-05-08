import Foundation
import OSLog
import SubscriptionStore
import SwiftData
import TrialParsingCore

private let shareCaptureLog = Logger(subsystem: "com.colehollander.finn", category: "share-capture")

@MainActor
enum SharedCaptureImporter {
    static func importPendingEntries(context: ModelContext) -> [ImportedShareEntry] {
        let entries: [PendingShareEntry]
        do {
            entries = try ShareHandoffStore.pendingEntries()
        } catch {
            shareCaptureLog.error("Could not read pending share entries: \(String(describing: error), privacy: .public)")
            return []
        }

        guard !entries.isEmpty else { return [] }

        var inserted = 0
        var importedEntries: [ImportedShareEntry] = []
        var processedIDs: Set<UUID> = []
        for entry in entries {
            guard let trial = makeTrial(from: entry) else {
                shareCaptureLog.info("Ignored pending share entry with insufficient parse signal: \(entry.id.uuidString, privacy: .public)")
                processedIDs.insert(entry.id)
                continue
            }
            context.insert(trial)
            inserted += 1
            importedEntries.append(ImportedShareEntry(trial: trial))
            processedIDs.insert(entry.id)
        }

        guard inserted > 0 else {
            removeProcessedPendingEntries(processedIDs)
            return []
        }

        do {
            try context.save()
            removeProcessedPendingEntries(processedIDs)
            return importedEntries
        } catch {
            shareCaptureLog.error("Could not save pending share entries: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    private static func makeTrial(from entry: PendingShareEntry) -> Trial? {
        switch entry.kind {
        case .freeTrial:
            return makeFreeTrial(from: entry)
        case .subscription:
            return makeSubscription(from: entry)
        }
    }

    private static func makeFreeTrial(from entry: PendingShareEntry) -> Trial? {
        let extracted = PastedTrialExtractor.extract(from: entry.recognizedText, source: .screenshot)
        guard let serviceName = extracted.serviceName,
              let chargeDate = extracted.trialEndDate else {
            return nil
        }

        return Trial(
            serviceName: serviceName,
            senderDomain: BrandDirectory.logoDomain(for: serviceName, senderDomain: nil) ?? "",
            chargeDate: chargeDate,
            chargeAmount: extracted.chargeAmount.flatMap { Decimal(string: $0) },
            detectedAt: entry.createdAt,
            entryType: .freeTrial
        )
    }

    private static func makeSubscription(from entry: PendingShareEntry) -> Trial? {
        let fields = TrialParser.extractSubscriptionFields(
            entry.recognizedText,
            now: entry.createdAt,
            source: .screenshot
        )
        guard let serviceName = normalizedServiceName(fields.serviceName),
              let chargeDate = fields.nextChargeDate ?? fallbackChargeDate(from: entry.createdAt),
              fields.chargeAmount != nil || fields.nextChargeDate != nil else {
            return nil
        }

        return Trial(
            serviceName: serviceName,
            senderDomain: BrandDirectory.logoDomain(for: serviceName, senderDomain: nil) ?? "",
            chargeDate: chargeDate,
            chargeAmount: fields.chargeAmount,
            detectedAt: entry.createdAt,
            entryType: .subscription,
            billingCycle: billingCycle(from: fields.billingCycle) ?? .monthly
        )
    }

    private static func normalizedServiceName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Unknown" else { return nil }
        return trimmed
    }

    private static func fallbackChargeDate(from date: Date) -> Date? {
        Calendar.current.date(byAdding: .month, value: 1, to: date)
    }

    private static func billingCycle(from parsed: SubscriptionBillingCycle?) -> BillingCycle? {
        switch parsed {
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        case .weekly:
            return .weekly
        case .custom:
            return .custom
        case .none:
            return nil
        }
    }

    private static func removeProcessedPendingEntries(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        do {
            try ShareHandoffStore.removePendingEntries(ids: ids)
        } catch {
            shareCaptureLog.error("Could not clear processed share entries: \(String(describing: error), privacy: .public)")
        }
    }
}

struct ImportedShareEntry: Equatable, Identifiable {
    let id: UUID
    let entryType: EntryType
    let serviceName: String
    let chargeDate: Date
    let chargeAmount: Decimal?

    init(trial: Trial) {
        self.id = trial.id
        self.entryType = trial.entryType
        self.serviceName = trial.serviceName
        self.chargeDate = trial.chargeDate
        self.chargeAmount = trial.chargeAmount
    }
}
