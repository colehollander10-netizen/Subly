import EmailEngine
import Foundation
import OSLog
import SubscriptionStore
import SwiftData

private let scanLog = Logger(subsystem: "com.subly.Subly", category: "scan")

/// Scans every connected Gmail account for free-trial emails and upserts
/// `Trial` rows. High-confidence parser matches become tracked trials, while
/// medium-confidence welcome/trial-started emails become manual-review leads.
@ModelActor
public actor ScanCoordinator {
    public struct Summary: Sendable {
        public let accountsScanned: Int
        public let messagesInspected: Int
        public let trialsAdded: Int
        public let trialsUpdated: Int
        public let errorMessage: String?
    }

    public func runScan(maxPagesPerAccount: Int = 4) async -> Summary {
        var accountsScanned = 0
        var messagesInspected = 0
        var trialsAdded = 0
        var trialsUpdated = 0

        setStatus(.scanning, error: nil)

        let accounts = fetchAccounts()
        scanLog.info("ScanCoordinator.runScan START — accounts=\(accounts.count, privacy: .public)")
        guard !accounts.isEmpty else {
            setStatus(.idle, error: nil)
            return Summary(
                accountsScanned: 0,
                messagesInspected: 0,
                trialsAdded: 0,
                trialsUpdated: 0,
                errorMessage: nil
            )
        }

        var lastError: String?

        for account in accounts {
            do {
                scanLog.info("→ scanning account \(account.email, privacy: .public)")
                var pageToken: String? = nil
                var pagesThisAccount = 0
                var candidateMessages: [GmailMessage] = []
                repeat {
                    let page = try await EmailEngine.shared.fetchMessageList(
                        accountID: account.id,
                        query: GmailQuery.trialsRecent,
                        pageToken: pageToken
                    )
                    pagesThisAccount += 1
                    let pageCount = page.messages?.count ?? 0
                    scanLog.info("  page \(pagesThisAccount, privacy: .public) — \(pageCount, privacy: .public) messages returned")

                    for ref in page.messages ?? [] {
                        messagesInspected += 1
                        if alreadyProcessed(sourceID: ref.id, accountID: account.id) { continue }

                        let meta = try await EmailEngine.shared.fetchMessageMetadata(
                            accountID: account.id,
                            id: ref.id
                        )
                        guard TrialParser.shouldFetchBody(meta) else {
                            scanLog.debug("    meta gate dropped \(ref.id, privacy: .public)")
                            continue
                        }

                        let full = try await EmailEngine.shared.fetchMessage(
                            accountID: account.id,
                            id: ref.id
                        )
                        candidateMessages.append(full)
                    }

                    pageToken = page.nextPageToken
                    try modelContext.save()
                } while pageToken != nil && pagesThisAccount < maxPagesPerAccount

                let analysis = TrialParser.analyze(candidateMessages)
                for detected in analysis.detectedTrials {
                    scanLog.info("    ✓ detected \(detected.serviceName, privacy: .public) — ends \(detected.trialEndDate, privacy: .public)")
                    let result = upsert(detected, accountID: account.id)
                    switch result {
                    case .inserted: trialsAdded += 1
                    case .updated: trialsUpdated += 1
                    case .skipped: break
                    }
                }
                for lead in analysis.detectedLeads {
                    scanLog.info("    ~ lead \(lead.serviceName, privacy: .public) (needs review)")
                    upsertLead(lead, accountID: account.id)
                }

                account.lastScannedAt = Date()
                try modelContext.save()
                accountsScanned += 1
            } catch let err as EmailEngineError {
                scanLog.error("account \(account.email, privacy: .public) failed: \(String(describing: err), privacy: .public)")
                switch err {
                case .refreshTokenRevoked, .refreshTokenUnavailable, .notSignedIn:
                    lastError = "Reconnect \(account.email) in Settings."
                default:
                    lastError = err.localizedDescription
                }
            } catch {
                scanLog.error("account \(account.email, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                lastError = error.localizedDescription
            }
        }

        setStatus(.idle, error: lastError)
        return Summary(
            accountsScanned: accountsScanned,
            messagesInspected: messagesInspected,
            trialsAdded: trialsAdded,
            trialsUpdated: trialsUpdated,
            errorMessage: lastError
        )
    }

    // MARK: - Persistence helpers

    private enum UpsertResult {
        case inserted, updated, skipped
    }

    private func fetchAccounts() -> [ConnectedAccount] {
        (try? modelContext.fetch(FetchDescriptor<ConnectedAccount>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
    }

    private func currentScanState() -> EmailScanState? {
        (try? modelContext.fetch(FetchDescriptor<EmailScanState>()))?.first
    }

    private func setStatus(_ status: ScanStatus, error: String?) {
        let state = currentScanState() ?? {
            let fresh = EmailScanState(
                lastScannedAt: .distantPast,
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

    /// Returns true if we've already processed this exact email for this account.
    private func alreadyProcessed(sourceID: String, accountID: String) -> Bool {
        var descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate {
                $0.sourceEmailID == sourceID && $0.accountID == accountID
            }
        )
        descriptor.fetchLimit = 1
        return ((try? modelContext.fetch(descriptor))?.first) != nil
    }

    /// Persist a welcome-email lead. Never overwrites a confirmed trial for
    /// the same domain — if the user has already confirmed it, skip.
    private func upsertLead(_ lead: DetectedLead, accountID: String) {
        let domain = lead.senderDomain
        var descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate {
                $0.accountID == accountID && $0.senderDomain == domain
            }
        )
        descriptor.fetchLimit = 1
        if (try? modelContext.fetch(descriptor))?.first != nil { return }

        let trial = Trial(
            accountID: accountID,
            serviceName: lead.serviceName,
            senderDomain: lead.senderDomain,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 14, to: lead.detectedAt) ?? lead.detectedAt,
            chargeAmount: nil,
            detectedAt: lead.detectedAt,
            sourceEmailID: lead.sourceMessageID,
            isLead: true
        )
        modelContext.insert(trial)
    }

    /// Upsert by `(accountID, senderDomain)`. A later email from the same
    /// service just updates the existing trial row — never creates a duplicate.
    private func upsert(_ detected: DetectedTrial, accountID: String) -> UpsertResult {
        let domain = detected.senderDomain
        var descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate {
                $0.accountID == accountID && $0.senderDomain == domain && !$0.isManual
            }
        )
        descriptor.fetchLimit = 1

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            guard detected.detectedAt >= existing.detectedAt else { return .skipped }
            existing.serviceName = detected.serviceName
            existing.trialEndDate = detected.trialEndDate
            existing.chargeAmount = detected.chargeAmount
            existing.detectedAt = detected.detectedAt
            existing.sourceEmailID = detected.sourceMessageID
            return .updated
        }

        let trial = Trial(
            accountID: accountID,
            serviceName: detected.serviceName,
            senderDomain: detected.senderDomain,
            trialEndDate: detected.trialEndDate,
            chargeAmount: detected.chargeAmount,
            detectedAt: detected.detectedAt,
            sourceEmailID: detected.sourceMessageID
        )
        modelContext.insert(trial)
        return .inserted
    }
}
