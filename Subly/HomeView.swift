import NotificationEngine
import OSLog
import SubscriptionStore
import SwiftData
import SwiftUI

private let scanLog = Logger(subsystem: "com.subly.Subly", category: "scan")

struct HomeView: View {
    let notificationEngine: NotificationEngine

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed && !$0.isLead },
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    // Featured trial
                    featuredTrialSection
                        .padding(.top, 32)
                        .padding(.horizontal, 24)

                    // Stats row
                    statsRow
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                    // Scan CTA
                    scanSection
                        .padding(.top, 28)
                        .padding(.horizontal, 24)

                    // Last scan result
                    if let lastSummary {
                        lastScanRow(lastSummary)
                            .padding(.top, 16)
                            .padding(.horizontal, 24)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.sublyRed.opacity(0.9))
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 48)
                }
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            // Big at-risk number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(totalAtRisk)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Text("at risk from active trials")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Featured trial

    @ViewBuilder
    private var featuredTrialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Next ending")

            if let next = activeTrials.first(where: { !$0.isLead }) {
                let days = daysUntil(next.trialEndDate)
                UrgencyCard(daysLeft: days) {
                    HStack(spacing: 16) {
                        ServiceIcon(name: next.serviceName, size: 48)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(next.serviceName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Ends \(next.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.60))
                            if let amount = next.chargeAmount {
                                Text("Will charge \(formatUSD(amount))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(days <= 7 ? Color.sublyAmber : .white.opacity(0.75))
                            }
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text(days <= 0 ? "Today" : "\(days)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if days > 0 {
                                Text("days")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
            } else {
                GlassCard {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.white.opacity(0.5))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No trials tracked yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Scan your inbox or add one manually.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsRow: some View {
        GlassCard(padding: 0) {
            HStack(spacing: 0) {
                statCell(value: "\(activeTrials.count)", label: "Active")
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 36)
                statCell(value: "\(endingThisWeekCount)", label: "This week")
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 36)
                statCell(value: totalAtRisk, label: "At risk")
            }
            .padding(.vertical, 18)
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scan

    @ViewBuilder
    private var scanSection: some View {
        Button {
            Task { await runScan() }
        } label: {
            HStack(spacing: 10) {
                if isScanning {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "sparkles.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isScanning ? "Scanning…" : "Scan for trials")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.sublyBlue.opacity(0.70),
                                Color.sublyPurple.opacity(0.60),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
            }
            .shadow(color: Color.sublyBlue.opacity(0.4), radius: 16, y: 6)
        }
        .disabled(isScanning)
    }

    @ViewBuilder
    private func lastScanRow(_ summary: ScanCoordinator.Summary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
            Text("\(summary.accountsScanned == 1 ? "1 inbox" : "\(summary.accountsScanned) inboxes") · \(summary.messagesInspected) emails checked")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            if summary.trialsAdded > 0 {
                Text("· \(summary.trialsAdded) new")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.sublyBlue.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Derived

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hey"
        }
    }

    private var totalAtRisk: String {
        let total = activeTrials.compactMap { $0.chargeAmount }.reduce(Decimal(0), +)
        return formatUSD(total)
    }

    private var endingThisWeekCount: Int {
        activeTrials.filter { daysUntil($0.trialEndDate) <= 7 }.count
    }

    // MARK: - Scan action

    private func runScan() async {
        scanLog.info("runScan START — accounts=\(accounts.count, privacy: .public)")
        errorMessage = nil
        withAnimation(.spring(response: 0.3)) { isScanning = true }
        defer {
            withAnimation(.spring(response: 0.3)) { isScanning = false }
            scanLog.info("runScan END")
        }

        let coordinator = ScanCoordinator(modelContainer: modelContext.container)
        let summary = await coordinator.runScan()
        scanLog.info("runScan summary — accountsScanned=\(summary.accountsScanned, privacy: .public) messagesInspected=\(summary.messagesInspected, privacy: .public) added=\(summary.trialsAdded, privacy: .public) updated=\(summary.trialsUpdated, privacy: .public) error=\(summary.errorMessage ?? "nil", privacy: .public)")
        withAnimation(.spring(response: 0.4)) { lastSummary = summary }
        if let err = summary.errorMessage { errorMessage = err }

        let alertCoordinator = TrialAlertCoordinator(
            modelContainer: modelContext.container,
            notificationEngine: notificationEngine
        )
        await alertCoordinator.replanAll()
    }
}
