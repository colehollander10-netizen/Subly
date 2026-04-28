import MascotKit
import NotificationEngine
import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine

    @Query(
        filter: #Predicate<Trial> {
            !$0.userDismissed && $0.entryTypeRaw == "freeTrial" && $0.statusRaw == "active"
        },
        sort: \Trial.chargeDate,
        order: .forward
    ) private var activeTrials: [Trial]

    @State private var selectedTrial: Trial?
    @State private var showingRouter = false
    @State private var showingAddTrial = false
    @State private var showingAddSubscription = false
    @State private var pendingAddChoice: AddEntryRouterSheet.Choice?

    private var upcomingSoon: [Trial] {
        activeTrials.filter { daysUntil($0.chargeDate) <= 7 }
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
                    accessibilityLabel: "Add to Finn",
                    accessibilityHint: "Choose whether to add a trial or subscription.",
                    onTap: { showingRouter = true },
                    diameter: 62
                )
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingRouter) {
            AddEntryRouterSheet(onSelect: { pendingAddChoice = $0 })
        }
        .sheet(isPresented: $showingAddTrial) {
            TrialDetailSheet(onCreateNew: { _ in })
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionSheet()
        }
        .onChange(of: showingRouter) { _, newValue in
            if newValue {
                Haptics.play(.sheetPresent)
                return
            }

            guard let pendingAddChoice else { return }
            switch pendingAddChoice {
            case .trial:
                showingAddTrial = true
            case .subscription:
                showingAddSubscription = true
            }
            self.pendingAddChoice = nil
        }
        .sheet(item: $selectedTrial) { trial in
            TrialDetailSheet(
                trial: trial,
                onSaveExisting: { _ in },
                notificationEngine: notificationEngine
            )
        }
        .onChange(of: selectedTrial?.id) { _, newValue in
            if newValue != nil { Haptics.play(.sheetPresent) }
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
                .foregroundStyle(FinnTheme.tertiaryText)
            Text("Finn")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(FinnTheme.accent)
                .accessibilityLabel("Finn")
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
        let days = daysUntil(trial.chargeDate)
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "Next ending trial", trailing: "\(days)D")

            Button {
                Haptics.play(.rowTap)
                selectedTrial = trial
            } label: {
                FlagshipCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 14) {
                            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 64)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(trial.serviceName)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(FinnTheme.primaryText)
                                HStack(spacing: 6) {
                                    Text("Renews \(trial.chargeDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                        .font(.system(size: 12, weight: .medium, design: .default))
                                        .monospacedDigit()
                                        .foregroundStyle(FinnTheme.secondaryText)
                                    if let lengthLabel = trialLengthDescription(for: trial) {
                                        Text("·")
                                            .font(.system(size: 12, weight: .medium, design: .default))
                                            .foregroundStyle(FinnTheme.tertiaryText)
                                        Text(lengthLabel)
                                            .font(.system(size: 12, weight: .medium, design: .default))
                                            .foregroundStyle(FinnTheme.tertiaryText)
                                    }
                                }
                            }

                            Spacer()

                            AccentPill(
                                text: days <= 0 ? "TODAY" : "\(max(days, 0))D LEFT",
                                color: FinnTheme.urgencyColor(daysLeft: days)
                            )
                            .breathing(days <= 3)
                        }

                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(trial.chargeAmount.map(formatUSD) ?? "Amount unknown")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(FinnTheme.primaryText)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                            Text(daysLabel(days))
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(FinnTheme.urgencyColor(daysLeft: days))
                        }

                        nextAlertRow(for: trial)
                    }
                }
            }
            .buttonStyle(PressableRowStyle())
            .accessibilityLabel(
                "\(trial.serviceName), charges \(trial.chargeDate.formatted(.dateTime.month().day())), \(trial.chargeAmount.map(formatUSD) ?? "amount unknown")"
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
                            Haptics.play(.rowTap)
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
            FoxView(state: .sleeping, size: 120)
                .frame(width: 120, height: 120)
            VStack(spacing: 8) {
                Text("Nothing charging soon.")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(FinnTheme.primaryText)
                Text("The next 7 days are clear. Your full list lives in Trials.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinnTheme.secondaryText)
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
                case .subscriptionDayBefore: return "renewal heads up"
                }
            }()
            HStack(spacing: 10) {
                Ph.bellSimple.fill
                    .color(FinnTheme.accent)
                    .frame(width: 14, height: 14)
                Text("Alert · \(planned.triggerDate.formatted(.relative(presentation: .named))) (\(kindLabel))")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(FinnTheme.secondaryText)
            }
        }
    }

    private func nextPlannedAlert(for trial: Trial) -> PlannedTrialAlert? {
        let planned = TrialEngine.plan(trialID: trial.id, chargeDate: trial.chargeDate)
        return planned.min(by: { $0.triggerDate < $1.triggerDate })
    }

    private func daysLabel(_ days: Int) -> String {
        if days <= 0 { return "Charges today" }
        if days == 1 { return "Charges in 1 day" }
        return "Charges in \(days) days"
    }

    private func resolvePendingNotificationRoute() {
        guard let pendingTrialID = appRouter.pendingCancelTrialID else { return }
        guard let trial = activeTrials.first(where: { $0.id == pendingTrialID }) else { return }
        selectedTrial = trial
        appRouter.pendingCancelTrialID = nil
        if case .trial = appRouter.pendingRoute { appRouter.pendingRoute = nil }
    }
}

private struct CompactTrialRow: View {
    let trial: Trial

    var body: some View {
        let days = daysUntil(trial.chargeDate)
        HStack(spacing: 12) {
            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(trial.serviceName)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(FinnTheme.primaryText)
                Text(trial.chargeDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(FinnTheme.tertiaryText)
            }
            Spacer()
            Text(days <= 0 ? "TODAY" : "\(days)D")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(0.8)
                .foregroundStyle(FinnTheme.urgencyColor(daysLeft: days))
        }
    }
}
