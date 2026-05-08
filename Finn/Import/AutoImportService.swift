import Foundation
import NotificationEngine
import Observation
import OSLog
import StoreKit
import SubscriptionStore
import SwiftData

/// Coordinates StoreKit-driven subscription imports.
///
/// Single source of truth for:
/// - Pulling current entitlements (cold start, foregrounding, manual sync).
/// - Live `Transaction.updates` ingestion.
/// - Manual selective import via `ImportConfirmationSheet`.
///
/// `@Observable` so SwiftUI views (Settings) can react to `lastSummary` and
/// `isSyncing` without UserDefaults round-trips. A single instance is owned
/// by `FinnApp` and injected into the environment so Settings + onboarding
/// share the same in-memory state.
@MainActor
@Observable
final class AutoImportService {
    @ObservationIgnored private let log = Logger(subsystem: "com.colehollander.finn", category: "auto-import")
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    /// Coalesces overlapping sync calls (cold start `.task`, scene-active
    /// `.onChange`, and manual "Sync now" can fire within seconds of each
    /// other on a real device). Without this guard each caller walks the same
    /// entitlements list and races on `context.save()`.
    @ObservationIgnored private var inFlightSync: Task<ImportSummary, Never>?

    /// Most recent sync outcome. `nil` until the first sync completes in
    /// this app launch. UI also reads `UserDefaults["lastAppleSync"]` for
    /// cross-launch continuity.
    private(set) var lastSummary: ImportSummary?
    private(set) var isSyncing: Bool = false

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Public surface

    /// Runs a full sync. Concurrent callers share the same in-flight task so
    /// `Settings` "Sync now" never collides with the launch-time sync.
    @discardableResult
    func sync(context: ModelContext) async -> ImportSummary {
        if let existing = inFlightSync {
            return await existing.value
        }

        let task = Task<ImportSummary, Never> { @MainActor [weak self] in
            guard let self else { return ImportSummary(fetchError: "Service deallocated") }
            self.isSyncing = true
            defer {
                self.isSyncing = false
                self.inFlightSync = nil
            }
            return await self.performSync(context: context)
        }
        inFlightSync = task
        return await task.value
    }

    /// Used by `ImportConfirmationSheet` after the user picks rows. Bypasses
    /// the StoreKit fetch (the sheet already has the payloads) and runs the
    /// same upsert + replan path as `sync` so behavior stays consistent.
    @discardableResult
    func importChosen(_ subscriptions: [ImportableSubscription], context: ModelContext) async -> ImportSummary {
        var summary = ImportSummary()
        applyUpserts(subscriptions, into: context, summary: &summary)
        await finalize(summary: &summary, context: context, recordTimestamp: true)
        lastSummary = summary
        return summary
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

    // MARK: - Sync internals

    private func performSync(context: ModelContext) async -> ImportSummary {
        var summary = ImportSummary()
        let outcomes = await StoreKitImport.fetchCurrentOutcomes()

        for outcome in outcomes {
            switch outcome.result {
            case .importable(let sub):
                applyUpserts([sub], into: context, summary: &summary)
            case .skipped(let reason):
                summary.skipped.append(.init(productID: outcome.productID, reason: reason.userFacingMessage))
                log.notice("Skipped \(outcome.productID, privacy: .public): \(reason.userFacingMessage, privacy: .public)")
            }
        }

        await finalize(summary: &summary, context: context, recordTimestamp: true)
        lastSummary = summary
        return summary
    }

    private func applyUpserts(
        _ subscriptions: [ImportableSubscription],
        into context: ModelContext,
        summary: inout ImportSummary
    ) {
        for sub in subscriptions {
            guard let originalID = sub.appleOriginalTransactionID, !originalID.isEmpty else {
                summary.skipped.append(.init(productID: sub.id, reason: "Missing original transaction ID"))
                continue
            }
            do {
                let result = try Trial.upsertAppleSubscription(
                    originalTransactionID: originalID,
                    serviceName: sub.displayName,
                    chargeDate: sub.nextBillingDate ?? fallbackChargeDate(),
                    chargeAmount: sub.amount,
                    billingCycle: sub.billingCycle,
                    in: context
                )
                if result.inserted {
                    summary.inserted += 1
                } else {
                    summary.updated += 1
                }
            } catch {
                log.error("Auto-import upsert failed for \(sub.id, privacy: .public): \(String(describing: error), privacy: .public)")
                summary.skipped.append(.init(productID: sub.id, reason: "Database error: \(error.localizedDescription)"))
            }
        }
    }

    /// Saves the context, gates the `lastAppleSync` timestamp on save success,
    /// and replans notifications only when we actually mutated the store.
    /// Previously the timestamp bumped even on save failure, which made the
    /// Settings "Last synced" line a lie whenever SwiftData rejected a write.
    @discardableResult
    private func finalize(summary: inout ImportSummary, context: ModelContext, recordTimestamp: Bool) async -> Bool {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                log.error("Auto-import save failed: \(String(describing: error), privacy: .public)")
                summary.saveError = error.localizedDescription
                // Save failure invalidates the imported/updated counts because
                // SwiftData rolls back the unsaved changes on the next fetch.
                summary.inserted = 0
                summary.updated = 0
                return false
            }
        }

        summary.completedAt = Date()

        if recordTimestamp, summary.didSucceed {
            UserDefaults.standard.set(summary.completedAt, forKey: "lastAppleSync")
        }

        if summary.totalProcessed > 0, summary.didSucceed {
            // Replan so imported subscriptions get a day-before alert
            // immediately instead of waiting for the next global replan.
            // P10 HIGH finding #2.
            let coordinator = TrialAlertCoordinator(
                modelContainer: context.container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()
        }

        return true
    }

    // MARK: - Live transaction updates

    private func process(update: VerificationResult<Transaction>, context: ModelContext) async {
        guard case .verified(let transaction) = update else { return }

        var summary = ImportSummary()
        if let sub = await StoreKitImport.importableSubscription(from: transaction) {
            applyUpserts([sub], into: context, summary: &summary)
        }
        let didPersist = await finalize(summary: &summary, context: context, recordTimestamp: false)

        // Don't overwrite a richer full-sync summary with this single-row
        // update unless the full sync hasn't run yet.
        if lastSummary == nil { lastSummary = summary }

        if didPersist {
            await transaction.finish()
        }
    }

    private func fallbackChargeDate() -> Date {
        Date().addingTimeInterval(60 * 60 * 24 * 30)
    }
}
