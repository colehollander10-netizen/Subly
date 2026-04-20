import EmailEngine
import Foundation
import SubscriptionStore
import SwiftData

/// Orchestrates a Gmail scan end-to-end: paginates the message list, runs the
/// cheap metadata pass, fetches full bodies only on likely hits, and persists
/// Subscription rows idempotently against sourceEmailID.
///
/// Uses ModelActor so the heavy lifting stays off the main thread. The caller
/// only hands us a ModelContainer (Sendable); we build our own context inside.
@ModelActor
public actor ScanCoordinator {
    public struct Summary: Sendable {
        public let pagesScanned: Int
        public let messagesInspected: Int
        public let subscriptionsAdded: Int
        public let errorMessage: String?
    }

    public func runScan(maxPages: Int = 4) async -> Summary {
        var pagesScanned = 0
        var messagesInspected = 0
        var subscriptionsAdded = 0

        setStatus(.scanning, error: nil)
        let startingToken = currentScanState()?.nextPageToken

        var pageToken: String? = startingToken
        do {
            repeat {
                let page = try await EmailEngine.shared.fetchMessageList(pageToken: pageToken)
                pagesScanned += 1

                for ref in page.messages ?? [] {
                    messagesInspected += 1
                    if existingSubscription(sourceID: ref.id) != nil { continue }

                    let meta = try await EmailEngine.shared.fetchMessageMetadata(id: ref.id)
                    guard SubscriptionParser.classifyMetadata(meta) != nil else { continue }

                    let full = try await EmailEngine.shared.fetchMessage(id: ref.id)
                    guard let parsed = SubscriptionParser.classifyFull(full) else { continue }
                    if existingSubscription(sourceID: parsed.sourceMessageID) != nil { continue }

                    insertSubscription(parsed)
                    subscriptionsAdded += 1
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
                errorMessage: nil
            )
        } catch {
            setStatus(.idle, error: error.localizedDescription)
            return Summary(
                pagesScanned: pagesScanned,
                messagesInspected: messagesInspected,
                subscriptionsAdded: subscriptionsAdded,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Persistence helpers

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

    private func existingSubscription(sourceID: String) -> Subscription? {
        var descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.sourceEmailID == sourceID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func insertSubscription(_ parsed: ParsedSubscription) {
        let subscription = Subscription(
            id: UUID(),
            serviceName: parsed.serviceName,
            logoURL: nil,
            status: mapStatus(parsed.event),
            amount: parsed.amount,
            billingCycle: mapBilling(parsed.billing),
            detectedAt: parsed.detectedAt,
            sourceEmailID: parsed.sourceMessageID,
            trialEndDate: parsed.trialEndDate
        )
        modelContext.insert(subscription)
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
