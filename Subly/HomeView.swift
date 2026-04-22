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

    @AppStorage(AppPreferences.showDemoData) private var showDemoData = true
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
        if !activeTrials.isEmpty {
            return activeTrials
        }
        return showDemoData ? DemoContent.activeTrials() : []
    }

    private var isShowingDemoTrials: Bool {
        activeTrials.isEmpty && showDemoData
    }

    private var nextTrial: Trial? { displayedActiveTrials.first }

    var body: some View {
        ScreenFrame {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if isShowingDemoTrials {
                        demoBanner
                    }
                    heroSection
                    actionRow
                    statusLine
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
                Text("Subly")
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
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(SublyTheme.highlight.opacity(0.85))
                    .frame(width: 7, height: 7)

                Text("Preview data is showing until your first real trial is found.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SublyTheme.tertiaryText)
            }

            Spacer()

            Button("Hide") {
                showDemoData = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SublyTheme.primaryText)
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

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(isScanning ? "Scanning…" : "Scan now") {
                Task { await runScan() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isScanning)

            Button {
                showingManualAdd = true
            } label: {
                Label("Add manually", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastSummary {
                Text("\(lastSummary.accountsScanned) inbox(es) · \(lastSummary.messagesInspected) checked · \(lastSummary.trialsAdded) new")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !accounts.isEmpty {
                Text(accounts.count == 1 ? "1 inbox connected" : "\(accounts.count) inboxes connected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
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
