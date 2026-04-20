import EmailEngine
import Foundation
import SubscriptionStore
import SwiftData

/// Orchestrates a Gmail scan end-to-end: paginates the message list, runs
/// the cheap metadata pre-filter, fetches full bodies only for likely hits,
/// and upserts Subscription rows with lifecycle awareness (newer events
/// update existing rows instead of creating duplicates).
@ModelActor
public actor ScanCoordinator {
    public struct Summary: Sendable {
        public let pagesScanned: Int
        public let messagesInspected: Int
        public let subscriptionsAdded: Int
        public let subscriptionsUpdated: Int
        public let errorMessage: String?
    }

    public func runScan(maxPages: Int = 4) async -> Summary {
        var pagesScanned = 0
        var messagesInspected = 0
        var subscriptionsAdded = 0
        var subscriptionsUpdated = 0

        setStatus(.scanning, error: nil)
        let startingToken = currentScanState()?.nextPageToken

        var pageToken: String? = startingToken
        do {
            repeat {
                let page = try await EmailEngine.shared.fetchMessageList(pageToken: pageToken)
                pagesScanned += 1

                for ref in page.messages ?? [] {
                    messagesInspected += 1
                    if alreadyProcessed(sourceID: ref.id) { continue }

                    let meta = try await EmailEngine.shared.fetchMessageMetadata(id: ref.id)
                    guard SubscriptionParser.shouldFetchBody(meta) else { continue }

                    let full = try await EmailEngine.shared.fetchMessage(id: ref.id)
                    guard let parsed = SubscriptionParser.classify(full) else { continue }
                    if alreadyProcessed(sourceID: parsed.sourceMessageID) { continue }

                    let result = upsert(parsed)
                    switch result {
                    case .inserted: subscriptionsAdded += 1
                    case .updated: subscriptionsUpdated += 1
                    case .skipped: break
                    }
                }

                pageToken = page.nextPageToken
                updateScanState(nextPageToken: pageToken)
                try modelContext.save()
            } while pageToken != nil && pagesScanned < maxPages

            setStatus(.idle, error: nil)
            return Summary(
                pagesScanned: pagesScanned,
                messagesInspected: messagesInspected,
                subscriptionsAdded: subscriptionsAdded,
                subscriptionsUpdated: subscriptionsUpdated,
                errorMessage: nil
            )
        } catch {
            setStatus(.idle, error: error.localizedDescription)
            return Summary(
                pagesScanned: pagesScanned,
                messagesInspected: messagesInspected,
                subscriptionsAdded: subscriptionsAdded,
                subscriptionsUpdated: subscriptionsUpdated,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Persistence helpers

    private enum UpsertResult {
        case inserted, updated, skipped
    }

    private func currentScanState() -> EmailScanState? {
        (try? modelContext.fetch(FetchDescriptor<EmailScanState>()))?.first
    }

    private func setStatus(_ status: ScanStatus, error: String?) {
        let state = currentScanState() ?? {
            let fresh = EmailScanState(
                lastScannedAt: .distantPast,
                nextPageToken: nil,
                status: .idle,
                errorMessage: nil
            )
            modelContext.insert(fresh)
            return fresh
        }()
        state.status = status
        state.errorMessage = error
        if status == .idle { state.lastScannedAt = Date() }
        try? modelContext.save()
    }

    private func updateScanState(nextPageToken: String?) {
        guard let state = currentScanState() else { return }
        state.nextPageToken = nextPageToken
    }

    /// Returns true if we've already processed this exact email (by Gmail message ID).
    private func alreadyProcessed(sourceID: String) -> Bool {
        var descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.sourceEmailID == sourceID }
        )
        descriptor.fetchLimit = 1
        return ((try? modelContext.fetch(descriptor))?.first) != nil
    }

    /// Upserts by sender domain — one row per service. Newer events override older ones.
    private func upsert(_ parsed: ParsedSubscription) -> UpsertResult {
        let domain = parsed.senderDomain
        var descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.senderDomain == domain }
        )
        descriptor.fetchLimit = 1

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            // Only apply update if this email is newer than what we had.
            guard parsed.detectedAt >= existing.detectedAt else { return .skipped }
            applyUpdate(to: existing, from: parsed)
            return .updated
        }

        let subscription = Subscription(
            id: UUID(),
            serviceName: parsed.serviceName,
            senderDomain: parsed.senderDomain,
            logoURL: nil,
            status: mapStatus(parsed.event),
            amount: parsed.amount,
            billingCycle: mapBilling(parsed.billing),
            detectedAt: parsed.detectedAt,
            sourceEmailID: parsed.sourceMessageID,
            trialEndDate: parsed.trialEndDate,
            regularAmount: parsed.regularAmount,
            introPriceEndDate: parsed.introPriceEndDate
        )
        modelContext.insert(subscription)
        return .inserted
    }

    /// Applies a newer parsed event to an existing row. Lifecycle events
    /// (cancel/pause) always override status. Price/cadence only update if
    /// the new email gives us something we didn't have.
    private func applyUpdate(to existing: Subscription, from parsed: ParsedSubscription) {
        existing.status = mapStatus(parsed.event)
        existing.detectedAt = parsed.detectedAt
        existing.sourceEmailID = parsed.sourceMessageID

        if parsed.event == .canceled || parsed.event == .paused {
            // Canceled / paused — preserve last known price metadata but flip status.
            return
        }

        if let amount = parsed.amount, amount > 0 {
            existing.amount = amount
        }
        if parsed.billing != .unknown {
            existing.billingCycle = mapBilling(parsed.billing)
        }
        if parsed.trialEndDate != nil {
            existing.trialEndDate = parsed.trialEndDate
        }
        if parsed.regularAmount != nil {
            existing.regularAmount = parsed.regularAmount
        }
        if parsed.introPriceEndDate != nil {
            existing.introPriceEndDate = parsed.introPriceEndDate
        }
    }

    private func mapStatus(_ event: ParsedSubscription.EventKind) -> SubscriptionStatus {
        switch event {
        case .trialStart: return .trial
        case .canceled: return .canceled
        case .paused: return .paused
        case .welcome, .renewal, .receipt, .unknown: return .active
        }
    }

    private func mapBilling(_ billing: ParsedSubscription.BillingInterval) -> BillingCycle {
        switch billing {
        case .monthly: return .monthly
        case .annual: return .annual
        case .unknown: return .unknown
        }
    }
}
