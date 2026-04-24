import MascotKit
import PhosphorSwift
import SubscriptionStore
import SwiftUI

struct ImportConfirmationSheet: View {
    let subscriptions: [ImportableSubscription]
    var onImport: ([ImportableSubscription]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var checkedIDs: Set<String>

    init(subscriptions: [ImportableSubscription], onImport: @escaping ([ImportableSubscription]) -> Void) {
        self.subscriptions = subscriptions
        self.onImport = onImport
        _checkedIDs = State(initialValue: Set(subscriptions.map(\.id)))
    }

    private var checkedCount: Int { checkedIDs.count }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if subscriptions.isEmpty {
                            emptyState
                        } else {
                            SectionLabel(title: "Found \(subscriptions.count)")
                            SurfaceCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(subscriptions) { subscription in
                                        checkboxRow(for: subscription)
                                        if subscription.id != subscriptions.last?.id {
                                            HairlineDivider().padding(.horizontal, 18)
                                        }
                                    }
                                }
                            }

                            Button {
                                importChecked()
                            } label: {
                                Text("Import \(checkedCount)")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButton())
                            .disabled(checkedCount == 0)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Ph.x.bold
                                .color(FinnTheme.tertiaryText)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 8) {
            foxPlaceholder
            Text("Import from Apple")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(FinnTheme.primaryText)
                .frame(maxWidth: .infinity)
            Text("Select the Apple-billed subscriptions you want Finn to track.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FinnTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var foxPlaceholder: some View {
        FoxView(state: .celebrating, size: 72)
            .frame(width: 72, height: 72)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Ph.appleLogo.regular
                .color(FinnTheme.tertiaryText)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            Text("No App Store subscriptions found")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(FinnTheme.primaryText)
                .multilineTextAlignment(.center)
            Text("Apple did not return any active auto-renewable subscriptions for this Apple ID. For everything else, add it manually.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FinnTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Add manually")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButton())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    @ViewBuilder
    private func checkboxRow(for subscription: ImportableSubscription) -> some View {
        Button {
            Haptics.play(.rowTap)
            toggle(subscription)
        } label: {
            HStack(spacing: 12) {
                (checkedIDs.contains(subscription.id) ? Ph.checkSquare.fill : Ph.square.regular)
                    .color(checkedIDs.contains(subscription.id) ? FinnTheme.accent : FinnTheme.tertiaryText)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FinnTheme.primaryText)
                    Text("\(formatUSD(subscription.amount)) / \(subscription.billingCycle.displayName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FinnTheme.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 12)

                if let nextBillingDate = subscription.nextBillingDate {
                    Text(nextBillingDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FinnTheme.tertiaryText)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle())
    }

    private func toggle(_ subscription: ImportableSubscription) {
        if checkedIDs.contains(subscription.id) {
            checkedIDs.remove(subscription.id)
        } else {
            checkedIDs.insert(subscription.id)
        }
    }

    private func importChecked() {
        let chosen = subscriptions.filter { checkedIDs.contains($0.id) }
        Haptics.play(.save)
        onImport(chosen)
        dismiss()
    }
}

private extension BillingCycle {
    var displayName: String {
        switch self {
        case .monthly:
            return "month"
        case .yearly:
            return "year"
        case .weekly:
            return "week"
        case .custom:
            return "billing period"
        }
    }
}
