import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed },
        sort: \Trial.trialEndDate,
        order: .forward
    ) private var activeTrials: [Trial]

    @State private var selectedTrial: Trial?
    @State private var showingManualAdd = false

    private var upcomingSoon: [Trial] {
        activeTrials.filter { daysUntil($0.trialEndDate) <= 7 }
    }

    private var nextTrial: Trial? { upcomingSoon.first }

    private var upcomingAfterHero: [Trial] {
        Array(upcomingSoon.dropFirst().prefix(3))
    }

    var body: some View {
        ScreenFrame {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    mainContent
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
        .sheet(isPresented: $showingManualAdd) {
            TrialDetailSheet(onCreateNew: { _ in })
        }
        .sheet(item: $selectedTrial) { trial in
            TrialDetailSheet(
                trial: trial,
                onSaveExisting: { _ in },
                onMarkCancelled: { t in markCancelled(t) }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.month(.wide).day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SublyTheme.tertiaryText)
            Text("Subly")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(SublyTheme.accent)
                .accessibilityLabel("Subly")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let nextTrial {
            heroSection(for: nextTrial)
            if !upcomingAfterHero.isEmpty {
                comingUpSection
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func heroSection(for trial: Trial) -> some View {
        let days = daysUntil(trial.trialEndDate)
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "Next ending trial", trailing: "\(days)D")

            Button {
                selectedTrial = trial
            } label: {
                FlagshipCard(urgency: urgencyLevel(days: days)) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 14) {
                            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 64)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(trial.serviceName)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SublyTheme.primaryText)
                                HStack(spacing: 6) {
                                    Text("Renews \(trial.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                        .font(.system(size: 12, weight: .medium, design: .default))
                                        .monospacedDigit()
                                        .foregroundStyle(SublyTheme.secondaryText)
                                    if let lengthLabel = trialLengthDescription(for: trial) {
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
                            Text(trial.chargeAmount.map(formatUSD) ?? "Amount unknown")
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

                        nextAlertRow(for: trial)
                    }
                }
            }
            .buttonStyle(PressableRowStyle())
            .accessibilityLabel(
                "\(trial.serviceName), charges \(trial.trialEndDate.formatted(.dateTime.month().day())), \(trial.chargeAmount.map(formatUSD) ?? "amount unknown")"
            )
        }
    }

    @ViewBuilder
    private var comingUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Also this week", trailing: "\(upcomingAfterHero.count)")
            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingAfterHero.enumerated()), id: \.element.id) { index, trial in
                        Button {
                            selectedTrial = trial
                        } label: {
                            CompactTrialRow(trial: trial)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PressableRowStyle())
                        if index < upcomingAfterHero.count - 1 {
                            HairlineDivider().padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(SublyTheme.accent.opacity(0.4))
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Nothing charging soon.")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("The next 7 days are clear. Your full list lives in Trials.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SublyTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func nextAlertRow(for trial: Trial) -> some View {
        if let planned = nextPlannedAlert(for: trial) {
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
        selectedTrial = trial
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
    }
}
