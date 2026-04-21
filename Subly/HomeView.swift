import NotificationEngine
import OSLog
import SubscriptionStore
import SwiftData
import SwiftUI

private let scanLog = Logger(subsystem: "com.subly.Subly", category: "scan")

/// Home tab: scan state + the soonest-ending trial + quick stats.
/// "The glanceable screen" — gives the user the one piece of info they'd
/// open the app for. Anything deeper lives in the Trials tab.
struct HomeView: View {
    let notificationEngine: NotificationEngine

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed },
        sort: \Trial.trialEndDate,
        order: .forward
    ) private var activeTrials: [Trial]
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]

    @State private var isScanning = false
    @State private var lastSummary: ScanCoordinator.Summary?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    greetingCard
                    nextTrialCard
                    statsCard
                    scanButton
                    if let lastSummary {
                        lastScanCard(lastSummary)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var greetingCard: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(accounts.count) \(accounts.count == 1 ? "inbox" : "inboxes") connected")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    @ViewBuilder
    private var nextTrialCard: some View {
        GlassCard {
            if let next = activeTrials.first {
                VStack(alignment: .leading, spacing: 12) {
                    Text("NEXT TRIAL ENDING")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .kerning(1.5)

                    Text(next.serviceName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
                        countdownBadge(days: daysUntil(next.trialEndDate))
                        if let amount = next.chargeAmount {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Will charge")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(formatUSD(amount))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    Text("Ends \(next.trialEndDate.formatted(.dateTime.weekday(.wide).month().day()))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No trials tracked yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Run a scan or add one manually from the Trials tab.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    @ViewBuilder
    private var statsCard: some View {
        GlassCard(padding: 18) {
            HStack(spacing: 16) {
                statCell(value: "\(activeTrials.count)", label: "Active")
                Divider().background(.white.opacity(0.2))
                statCell(value: totalAtRisk, label: "At risk")
                Divider().background(.white.opacity(0.2))
                statCell(value: "\(endingThisWeekCount)", label: "This week")
            }
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func countdownBadge(days: Int) -> some View {
        let label: String = {
            if days <= 0 { return "Today" }
            if days == 1 { return "1 day" }
            return "\(days) days"
        }()
        let color: Color = days <= 3 ? .red : (days <= 7 ? .orange : .white.opacity(0.25))

        Text(label)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.9))
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            )
    }

    @ViewBuilder
    private func lastScanCard(_ summary: ScanCoordinator.Summary) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAST SCAN")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(1.2)
                Text("\(summary.accountsScanned) \(summary.accountsScanned == 1 ? "inbox" : "inboxes") · \(summary.messagesInspected) emails checked")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                if summary.trialsAdded + summary.trialsUpdated > 0 {
                    Text("\(summary.trialsAdded) new · \(summary.trialsUpdated) updated")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("No new trials found — that's normal if nothing's ending soon.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    @ViewBuilder
    private var scanButton: some View {
        GlassButton(
            title: isScanning ? "Scanning your inboxes…" : "Scan for trials now",
            systemImage: "sparkles.magnifyingglass",
            isBusy: isScanning
        ) {
            Task { await runScan() }
        }
    }

    // MARK: - Derived values

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        case 17..<22: base = "Good evening"
        default: base = "Hey"
        }
        return base
    }

    private var totalAtRisk: String {
        let total = activeTrials
            .compactMap { $0.chargeAmount }
            .reduce(Decimal(0), +)
        return formatUSD(total)
    }

    private var endingThisWeekCount: Int {
        activeTrials.filter { daysUntil($0.trialEndDate) <= 7 }.count
    }

    // MARK: - Actions

    private func runScan() async {
        scanLog.info("runScan START — accounts=\(accounts.count, privacy: .public)")
        errorMessage = nil
        isScanning = true
        defer {
            isScanning = false
            scanLog.info("runScan END")
        }

        let coordinator = ScanCoordinator(modelContainer: modelContext.container)
        let summary = await coordinator.runScan()
        scanLog.info("""
            runScan summary — accountsScanned=\(summary.accountsScanned, privacy: .public) \
            messagesInspected=\(summary.messagesInspected, privacy: .public) \
            added=\(summary.trialsAdded, privacy: .public) \
            updated=\(summary.trialsUpdated, privacy: .public) \
            error=\(summary.errorMessage ?? "nil", privacy: .public)
            """)
        lastSummary = summary
        if let err = summary.errorMessage { errorMessage = err }

        let alertCoordinator = TrialAlertCoordinator(
            modelContainer: modelContext.container,
            notificationEngine: notificationEngine
        )
        await alertCoordinator.replanAll()
    }
}
