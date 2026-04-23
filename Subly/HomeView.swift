import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine

    @AppStorage(AppPreferences.showDemoData) private var showDemoData = true
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed },
        sort: \Trial.trialEndDate,
        order: .forward
    ) private var activeTrials: [Trial]

    @State private var showingSettings = false
    @State private var selectedCancelTrial: Trial?
    @State private var showingManualAdd = false
    @State private var horizontalDrag: CGFloat = 0
    @State private var dragCrossedThreshold = false

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
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if isShowingDemoTrials {
                        demoBanner
                    }
                    heroSection
                    comingUpSection
                    statusLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .overlay(alignment: .bottomTrailing) {
                PrimaryAddButton(
                    icon: "plus",
                    accessibilityLabel: "Add a trial",
                    accessibilityHint: "Enter trial details manually.",
                    onTap: { showingManualAdd = true },
                    diameter: 62
                )
                .padding(.trailing, 20)
                .padding(.bottom, 24)
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
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.tertiaryText)
                Text("Subly")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(SublyTheme.accent)
                Text("Know before your trials charge you.")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(SublyTheme.secondaryText)
            }

            Spacer()

            HeaderIconButton(
                systemImage: "gearshape",
                accessibilityLabel: "Settings",
                action: { showingSettings = true }
            )
        }
    }

    private var demoBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(SublyTheme.accent.opacity(0.85))
                    .frame(width: 7, height: 7)

                Text("Preview data is showing until your first real trial is found.")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(SublyTheme.tertiaryText)
            }

            Spacer()

            Button("Hide") {
                showDemoData = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold, design: .default))
            .foregroundStyle(SublyTheme.primaryText)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "Next ending trial", trailing: nextTrial.map { "\(daysUntil($0.trialEndDate))D" } ?? nil)

            if let nextTrial {
                let days = daysUntil(nextTrial.trialEndDate)
                FlagshipCard(urgency: urgencyLevel(days: days)) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 14) {
                            ServiceIcon(name: nextTrial.serviceName, domain: nextTrial.senderDomain, size: 64)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(nextTrial.serviceName)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SublyTheme.primaryText)
                                HStack(spacing: 6) {
                                    Text("Renews \(nextTrial.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                        .font(.system(size: 12, weight: .medium, design: .default))
                                        .monospacedDigit()
                                        .foregroundStyle(SublyTheme.secondaryText)
                                    if let lengthLabel = trialLengthDescription(for: nextTrial) {
                                        Text("·")
                                            .font(.system(size: 12, weight: .medium, design: .default))
                                            .foregroundStyle(SublyTheme.tertiaryText)
                                        Text(lengthLabel)
                                            .font(.system(size: 12, weight: .medium, design: .default))
                                            .foregroundStyle(SublyTheme.tertiaryText)
                                    }
                                }
                            }

                            Spacer()

                            AccentPill(
                                text: days <= 0 ? "TODAY" : "\(max(days, 0))D LEFT",
                                color: SublyTheme.urgencyColor(daysLeft: days)
                            )
                            .breathing(days <= 3)
                        }

                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(nextTrial.chargeAmount.map(formatUSD) ?? "Amount unknown")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(SublyTheme.primaryText)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                            Text(daysLabel(days))
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(SublyTheme.urgencyColor(daysLeft: days))
                        }

                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(isShowingDemoTrials ? "Preview trial" : "Cancellation path ready")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(SublyTheme.primaryText)
                                Text(isShowingDemoTrials
                                     ? "Add a real trial to enable swipe-to-cancel."
                                     : "Swipe left to open the real cancel steps for this service.")
                                    .font(.system(size: 15, weight: .medium, design: .default))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }

                            Spacer()

                            if !isShowingDemoTrials {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(SublyTheme.tertiaryText)
                            }
                        }

                        nextAlertRow
                    }
                }
                .contentShape(Rectangle())
                .offset(x: horizontalDrag)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard !isShowingDemoTrials else { return }
                            horizontalDrag = min(0, value.translation.width)
                            let crossed = value.translation.width < -60
                            if crossed != dragCrossedThreshold {
                                dragCrossedThreshold = crossed
                                if crossed { Haptics.play(.swipeThresholdCrossed) }
                            }
                        }
                        .onEnded { value in
                            guard !isShowingDemoTrials else { return }
                            if value.translation.width < -90 {
                                selectedCancelTrial = nextTrial
                            }
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                horizontalDrag = 0
                            }
                            dragCrossedThreshold = false
                        }
                )
            } else {
                EmptyStateBlock(
                    title: "No active trials yet",
                    message: "Share a trial receipt with Subly, or add one manually from the button below. The next charge will show up here.",
                    actionTitle: "Add a trial",
                    action: { showingManualAdd = true }
                )
            }
        }
    }

    private var upcomingAfterHero: [Trial] {
        Array(displayedActiveTrials.dropFirst().prefix(3))
    }

    @ViewBuilder
    private var comingUpSection: some View {
        if !upcomingAfterHero.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Coming up", trailing: "\(upcomingAfterHero.count)")
                VStack(spacing: 8) {
                    ForEach(upcomingAfterHero) { trial in
                        CompactTrialRow(trial: trial)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextAlertRow: some View {
        if !isShowingDemoTrials,
           let nextTrial,
           let planned = nextPlannedAlert(for: nextTrial) {
            let kindLabel: String = {
                switch planned.kind {
                case .threeDaysBefore: return "3-day heads up"
                case .dayBefore: return "1-day heads up"
                case .dayOf: return "day-of"
                }
            }()
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SublyTheme.accent)
                Text("Alert · \(planned.triggerDate.formatted(.relative(presentation: .named))) (\(kindLabel))")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.secondaryText)
            }
        }
    }

    private func nextPlannedAlert(for trial: Trial) -> PlannedTrialAlert? {
        let planned = TrialEngine.plan(trialID: trial.id, trialEndDate: trial.trialEndDate)
        return planned.min(by: { $0.triggerDate < $1.triggerDate })
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SublyTheme.tertiaryText.opacity(0.4))
                .frame(width: 5, height: 5)
            Text(activeTrials.isEmpty
                 ? "Share a trial receipt with Subly to start tracking."
                 : "\(activeTrials.count) trial\(activeTrials.count == 1 ? "" : "s") tracked")
                .font(.system(size: 12, weight: .medium, design: .default))
                .monospacedDigit()
                .foregroundStyle(SublyTheme.tertiaryText)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func urgencyLevel(days: Int) -> UrgencyLevel {
        if days <= 3 { return .critical }
        if days <= 7 { return .warning }
        return .calm
    }

    private func daysLabel(_ days: Int) -> String {
        if days <= 0 { return "Charges today" }
        if days == 1 { return "Charges in 1 day" }
        return "Charges in \(days) days"
    }

    private func markCancelled(_ trial: Trial) {
        trial.userDismissed = true
        try? modelContext.save()
        Haptics.play(.markCanceled)
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
        Haptics.play(.scheduleReminder)

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

}

private struct CompactTrialRow: View {
    let trial: Trial

    var body: some View {
        let days = daysUntil(trial.trialEndDate)
        HStack(spacing: 12) {
            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(trial.serviceName)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(SublyTheme.primaryText)
                Text(trial.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.tertiaryText)
            }
            Spacer()
            Text(days <= 0 ? "TODAY" : "\(days)D")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(0.8)
                .foregroundStyle(SublyTheme.urgencyColor(daysLeft: days))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SublyTheme.glassFill.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SublyTheme.divider.opacity(0.7), lineWidth: 1)
        )
    }
}
