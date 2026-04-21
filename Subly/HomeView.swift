import NotificationEngine
import OSLog
import SubscriptionStore
import SwiftData
import SwiftUI

private let scanLog = Logger(subsystem: "com.subly.Subly", category: "scan")

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine
    let onSeeAllTrials: () -> Void

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
    @State private var showingSettings = false
    @State private var selectedCancelTrial: Trial?
    @State private var showingManualAdd = false
    @State private var horizontalDrag: CGFloat = 0

    private var displayedActiveTrials: [Trial] {
        activeTrials.isEmpty ? DemoContent.activeTrials() : activeTrials
    }

    private var isShowingDemoTrials: Bool {
        activeTrials.isEmpty
    }

    private var nextTrial: Trial? { displayedActiveTrials.first }
    private var upcomingTrials: [Trial] { Array(displayedActiveTrials.dropFirst().prefix(3)) }

    var body: some View {
        ScreenFrame {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if isShowingDemoTrials {
                        demoBanner
                    }
                    heroSection
                    fallbackSection
                    nextThreeSection
                    scanSection
                    scanMetaSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingManualAdd) {
            TrialDetailSheet(onCreateNew: { _ in })
        }
        .sheet(item: $selectedCancelTrial) { trial in
            CancelFlowSheet(
                trial: trial,
                onCancelled: { markCancelled(trial) },
                onSnooze: { scheduleFollowUpReminder(for: trial) }
            )
        }
        .onAppear {
            resolvePendingNotificationRoute()
        }
        .onChange(of: appRouter.pendingCancelTrialID) { _, _ in
            resolvePendingNotificationRoute()
        }
        .onChange(of: activeTrials.count) { _, _ in
            resolvePendingNotificationRoute()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SublyTheme.tertiaryText)
                Text("subly")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("Know before your trials charge you.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(SublyTheme.secondaryText)
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SublyTheme.primaryText)
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(SublyTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(SublyTheme.divider, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SublyTheme.highlight.opacity(0.85))
                .frame(width: 7, height: 7)

            Text("Preview data is showing until your first real trial is found.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SublyTheme.tertiaryText)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TerminalSectionLabel(title: "Next ending trial", trailing: nextTrial.map { "\(daysUntil($0.trialEndDate))D" } ?? nil)

            if let nextTrial {
                let days = daysUntil(nextTrial.trialEndDate)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 14) {
                            ServiceIcon(name: nextTrial.serviceName, domain: nextTrial.senderDomain, size: 64)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(nextTrial.serviceName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(SublyTheme.primaryText)
                                Text("Renews \(nextTrial.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }

                            Spacer()

                            AccentPill(
                                text: days <= 0 ? "TODAY" : "\(max(days, 0))D LEFT",
                                color: SublyTheme.urgencyColor(daysLeft: days)
                            )
                        }

                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(nextTrial.chargeAmount.map(formatUSD) ?? "Amount unknown")
                                .font(.system(size: 50, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(SublyTheme.ink)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                            Text(daysLabel(days))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(SublyTheme.urgencyColor(daysLeft: days))
                        }

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Cancellation path ready")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SublyTheme.primaryText)
                                Text("Swipe left to open the real cancel steps for this service.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(SublyTheme.tertiaryText)
                        }
                    }
                }
                .contentShape(Rectangle())
                .offset(x: horizontalDrag)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            horizontalDrag = min(0, value.translation.width)
                        }
                        .onEnded { value in
                            if value.translation.width < -90 {
                                selectedCancelTrial = nextTrial
                            }
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                horizontalDrag = 0
                            }
                        }
                )
            } else {
                EmptyStateBlock(
                    title: "No active trials yet",
                    message: "Scan Gmail or add one manually from the button below. The next charge will show up here.",
                    actionTitle: "Add a trial",
                    action: { showingManualAdd = true }
                )
            }
        }
    }

    private var fallbackSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    ServiceIcon(name: "Apple", domain: "apple.com", size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        TerminalSectionLabel(title: "Manual entry")
                        Text("Not in Gmail?")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(SublyTheme.primaryText)
                        Text("Some trials never hit your inbox cleanly. Add them yourself and keep the same calm reminder flow.")
                            .font(.system(size: 14))
                            .foregroundStyle(SublyTheme.secondaryText)
                    }
                }

                HStack(spacing: 10) {
                    Button("Add manually") {
                        showingManualAdd = true
                    }
                    .buttonStyle(TerminalButtonStyle(background: SublyTheme.ink, foreground: .white))

                    Button("See all trials") {
                        onSeeAllTrials()
                    }
                    .buttonStyle(SecondaryTerminalButtonStyle())
                }
            }
        }
    }

    private var nextThreeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TerminalSectionLabel(title: "Queue", trailing: "\(displayedActiveTrials.count) total")
                Spacer()
                QuietActionLink(title: "See all", systemImage: "arrow.right", action: onSeeAllTrials)
            }

            if upcomingTrials.isEmpty {
                Text("No other trials behind the current one.")
                    .font(.system(size: 14))
                    .foregroundStyle(SublyTheme.secondaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(upcomingTrials) { trial in
                        SurfaceCard(padding: 14) {
                            TrialQueueRow(trial: trial)
                        }
                    }
                }
            }
        }
    }

    private var scanSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                TerminalSectionLabel(title: "Privacy")
                Text("Private by design. Subly reads trial confirmations from Gmail without linking your bank account or building a server-side subscription graph.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(SublyTheme.primaryText)

                HStack(spacing: 10) {
                    Button(isScanning ? "Scanning..." : "Scan now") {
                        Task { await runScan() }
                    }
                    .buttonStyle(TerminalButtonStyle(background: SublyTheme.accent, foreground: .white))
                    .disabled(isScanning)

                    if !accounts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(accounts.count == 1 ? "1 inbox connected" : "\(accounts.count) inboxes connected")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(SublyTheme.secondaryText)
                            Text("Read-only Gmail access")
                                .font(.system(size: 12))
                                .foregroundStyle(SublyTheme.tertiaryText)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scanMetaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isShowingDemoTrials {
                Text("Demo mode uses branded sample trials so we can tune the layout before your first scan.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SublyTheme.tertiaryText)
            } else if let lastSummary {
                Text("\(lastSummary.accountsScanned == 1 ? "1 inbox" : "\(lastSummary.accountsScanned) inboxes") · \(lastSummary.messagesInspected) messages checked · \(lastSummary.trialsAdded) new")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.secondaryText)
            } else {
                Text("\(accounts.count == 1 ? "1 inbox connected" : "\(accounts.count) inboxes connected")")
                    .font(.system(size: 12))
                    .foregroundStyle(SublyTheme.secondaryText)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SublyTheme.critical)
            }
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days <= 0 { return "Charges today" }
        if days == 1 { return "Charges in 1 day" }
        return "Charges in \(days) days"
    }

    private func markCancelled(_ trial: Trial) {
        trial.userDismissed = true
        try? modelContext.save()
        Task {
            let coordinator = TrialAlertCoordinator(
                modelContainer: modelContext.container,
                notificationEngine: notificationEngine
            )
            await coordinator.replanAll()
        }
    }

    private func scheduleFollowUpReminder(for trial: Trial) {
        let followUp = TrialAlert(
            id: UUID(),
            trialID: trial.id,
            triggerDate: Date().addingTimeInterval(60 * 60),
            alertType: .followUp,
            delivered: false
        )

        modelContext.insert(followUp)
        try? modelContext.save()

        Task {
            let coordinator = TrialAlertCoordinator(
                modelContainer: modelContext.container,
                notificationEngine: notificationEngine
            )
            await coordinator.replanAll()
        }
    }

    private func resolvePendingNotificationRoute() {
        guard let pendingTrialID = appRouter.pendingCancelTrialID else { return }
        guard let trial = activeTrials.first(where: { $0.id == pendingTrialID }) else { return }
        selectedCancelTrial = trial
        appRouter.pendingCancelTrialID = nil
    }

    private func runScan() async {
        scanLog.info("runScan START — accounts=\(accounts.count, privacy: .public)")
        errorMessage = nil
        isScanning = true
        defer { isScanning = false }

        let coordinator = ScanCoordinator(modelContainer: modelContext.container)
        let summary = await coordinator.runScan()
        scanLog.info("runScan summary — accountsScanned=\(summary.accountsScanned, privacy: .public) messagesInspected=\(summary.messagesInspected, privacy: .public) added=\(summary.trialsAdded, privacy: .public) updated=\(summary.trialsUpdated, privacy: .public) error=\(summary.errorMessage ?? "nil", privacy: .public)")
        lastSummary = summary
        if let err = summary.errorMessage {
            errorMessage = err
        }

        let alertCoordinator = TrialAlertCoordinator(
            modelContainer: modelContext.container,
            notificationEngine: notificationEngine
        )
        await alertCoordinator.replanAll()
    }
}

private struct TrialQueueRow: View {
    let trial: Trial

    var body: some View {
        let days = daysUntil(trial.trialEndDate)
        HStack(spacing: 14) {
            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(trial.serviceName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SublyTheme.primaryText)
                Text(trial.trialEndDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 13))
                    .foregroundStyle(SublyTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(trial.chargeAmount.map(formatUSD) ?? "TBD")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.primaryText)
                Text(days <= 0 ? "today" : "\(days)d")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.urgencyColor(daysLeft: days))
            }
        }
    }
}
