import NotificationEngine
import OSLog
import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI

private let subscriptionsViewLog = Logger(subsystem: "com.subly.Subly", category: "subscriptions-view")

struct SubscriptionsView: View {
    @Environment(AppRouter.self) private var appRouter
    @Query(
        filter: #Predicate<Trial> {
            $0.entryTypeRaw == "subscription" && $0.statusRaw == "active"
        },
        sort: \Trial.chargeDate,
        order: .forward
    ) private var subscriptions: [Trial]

    @State private var selectedSubscription: Trial?
    @State private var showingAddSubscription = false

    private var chargingThisWeek: [Trial] {
        subscriptions.filter {
            let days = daysUntil($0.chargeDate)
            return (0 ... 7).contains(days)
        }
    }

    private var thisMonth: [Trial] {
        subscriptions.filter {
            let days = daysUntil($0.chargeDate)
            return (8 ... 30).contains(days)
        }
    }

    private var later: [Trial] {
        subscriptions.filter { daysUntil($0.chargeDate) > 30 }
    }

    private var monthlyTotal: Decimal {
        subscriptions.reduce(.zero) { partial, subscription in
            guard let amount = subscription.chargeAmount else { return partial }
            let multiplier = subscription.billingCycle?.monthlyMultiplier ?? BillingCycle.custom.monthlyMultiplier
            let normalized = NSDecimalNumber(decimal: amount)
                .multiplying(by: NSDecimalNumber(value: multiplier))
                .decimalValue
            return partial + normalized
        }
    }

    var body: some View {
        ScreenFrame {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if subscriptions.isEmpty {
                        emptyState
                    } else {
                        if !chargingThisWeek.isEmpty {
                            section(title: "Charging this week", items: chargingThisWeek)
                        }
                        if !thisMonth.isEmpty {
                            section(title: "This month", items: thisMonth)
                        }
                        if !later.isEmpty {
                            section(title: "Later", items: later)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .overlay(alignment: .bottomTrailing) {
                PrimaryAddButton(
                    accessibilityLabel: "Add a subscription",
                    accessibilityHint: "Enter subscription details manually.",
                    onTap: { showingAddSubscription = true },
                    diameter: 62
                )
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $selectedSubscription) { trial in
            SubscriptionDetailSheet(trial: trial)
        }
        .onChange(of: selectedSubscription?.id) { _, newValue in
            if newValue != nil { Haptics.play(.sheetPresent) }
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionSheet()
        }
        .onChange(of: showingAddSubscription) { _, newValue in
            if newValue { Haptics.play(.sheetPresent) }
        }
        .onAppear { resolvePendingNotificationRoute() }
        .onChange(of: appRouter.pendingRoute) { _, _ in
            resolvePendingNotificationRoute()
        }
    }

    private func resolvePendingNotificationRoute() {
        guard case .subscription(let id) = appRouter.pendingRoute else { return }
        guard let subscription = subscriptions.first(where: { $0.id == id }) else { return }
        selectedSubscription = subscription
        appRouter.pendingRoute = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subscriptions")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(FinnTheme.primaryText)
            Text("\(subscriptions.count) active · \(formatUSD(monthlyTotal))/mo")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(FinnTheme.tertiaryText)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 72)
            SurfaceCard {
                VStack(spacing: 10) {
                    Ph.repeat.regular
                        .color(FinnTheme.tertiaryText)
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    Text("No subscriptions yet")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FinnTheme.primaryText)
                    Text("Tap + to add one.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinnTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func section(title: String, items: [Trial]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: title, trailing: "\(items.count)")
            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, subscription in
                        Button {
                            Haptics.play(.rowTap)
                            selectedSubscription = subscription
                        } label: {
                            SubscriptionListRow(subscription: subscription)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(PressableRowStyle())
                        if index < items.count - 1 {
                            HairlineDivider().padding(.horizontal, 18)
                        }
                    }
                }
            }
        }
    }
}

private struct SubscriptionListRow: View {
    let subscription: Trial

    private var highlightColor: Color {
        daysUntil(subscription.chargeDate) <= 2 ? FinnTheme.accent : FinnTheme.urgencyCalm
    }

    var body: some View {
        HStack(spacing: 14) {
            ServiceIcon(name: subscription.serviceName, domain: subscription.senderDomain, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.serviceName)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(FinnTheme.primaryText)
                Text("Renews \(subscription.chargeDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(FinnTheme.secondaryText)
            }
            Spacer()
            Text(subscription.chargeAmount.map(formatUSD) ?? "TBD")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlightColor)
                .contentTransition(.numericText())
        }
        .contentShape(Rectangle())
    }
}

private struct SubscriptionDetailSheet: View {
    let trial: Trial

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var serviceName: String
    @State private var chargeDate: Date
    @State private var billingCycle: BillingCycle
    @State private var chargeAmountText: String

    init(trial: Trial) {
        self.trial = trial
        _serviceName = State(initialValue: trial.serviceName)
        _chargeDate = State(initialValue: trial.chargeDate)
        _billingCycle = State(initialValue: trial.billingCycle ?? .monthly)
        _chargeAmountText = State(initialValue: trial.chargeAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    private var parsedAmount: Decimal? {
        Decimal(string: chargeAmountText.replacingOccurrences(of: "$", with: ""))
    }

    private var canSave: Bool {
        !serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount != nil
    }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Active subscription")
                            Text("Edit Subscription")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(FinnTheme.primaryText)
                        }

                        SurfaceCard(padding: 0) {
                            VStack(spacing: 0) {
                                ServiceNameField(text: $serviceName, placeholder: "Netflix")
                                HairlineDivider().padding(.leading, 54)
                                DatePickerField(date: $chargeDate, label: "Next billing date")
                                HairlineDivider().padding(.leading, 54)
                                billingCycleField
                                HairlineDivider().padding(.leading, 54)
                                AmountField(text: $chargeAmountText, placeholder: "9.99")
                            }
                        }

                        Button {
                            save()
                        } label: {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canSave)

                        Button {
                            delete()
                        } label: {
                            Text("Delete")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .foregroundStyle(FinnTheme.urgencyCritical)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(FinnTheme.urgencyCritical, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(FinnTheme.primaryText)
                    }
                }
            }
        }
    }

    private var billingCycleField: some View {
        FieldRow(
            icon: AnyView(Ph.repeat.regular.color(FinnTheme.tertiaryText).frame(width: 22, height: 22)),
            label: "Billing cycle"
        ) {
            Picker("", selection: $billingCycle) {
                Text("Monthly").tag(BillingCycle.monthly)
                Text("Yearly").tag(BillingCycle.yearly)
                Text("Weekly").tag(BillingCycle.weekly)
                Text("Custom").tag(BillingCycle.custom)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .onChange(of: billingCycle) { _, _ in
                Haptics.play(.primaryTap)
            }
        }
    }

    private func save() {
        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = parsedAmount else { return }
        trial.serviceName = trimmed
        trial.chargeDate = chargeDate
        trial.billingCycle = billingCycle
        trial.chargeAmount = amount
        do {
            try modelContext.save()
        } catch {
            subscriptionsViewLog.error("Subscription edit save failed: \(String(describing: error), privacy: .public)")
            return
        }
        Haptics.play(.save)
        replanAlerts()
        dismiss()
    }

    private func delete() {
        modelContext.delete(trial)
        do {
            try modelContext.save()
        } catch {
            subscriptionsViewLog.error("Subscription delete save failed: \(String(describing: error), privacy: .public)")
            return
        }
        Haptics.play(.destructiveConfirm)
        replanAlerts()
        dismiss()
    }

    private func replanAlerts() {
        let container = modelContext.container
        Task {
            let coordinator = TrialAlertCoordinator(
                modelContainer: container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()
        }
    }
}

