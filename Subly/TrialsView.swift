import SubscriptionStore
import SwiftData
import SwiftUI

struct TrialsView: View {
    @AppStorage(AppPreferences.showDemoData) private var showDemoData = true
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed && !$0.isLead },
        sort: \Trial.trialEndDate,
        order: .forward
    ) private var trials: [Trial]

    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed && $0.isLead },
        sort: \Trial.detectedAt,
        order: .reverse
    ) private var leads: [Trial]

    @State private var selectedTrial: Trial?
    @State private var selectedLead: Trial?
    @State private var showingManualAdd = false

    private var displayedTrials: [Trial] {
        if !trials.isEmpty {
            return trials
        }
        return showDemoData ? DemoContent.activeTrials() : []
    }

    private var displayedLeads: [Trial] {
        if !leads.isEmpty {
            return leads
        }
        return trials.isEmpty && showDemoData ? DemoContent.leads() : []
    }

    private var isShowingDemoData: Bool {
        trials.isEmpty && leads.isEmpty && showDemoData
    }

    private var endingSoon: [Trial] { displayedTrials.filter { daysUntil($0.trialEndDate) <= 7 } }
    private var later: [Trial] { displayedTrials.filter { daysUntil($0.trialEndDate) > 7 } }

    var body: some View {
        ScreenFrame {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if isShowingDemoData {
                        demoBanner
                    }

                    if displayedTrials.isEmpty && displayedLeads.isEmpty {
                        EmptyStateBlock(
                            title: "Nothing to watch yet",
                            message: "When a free trial confirmation lands in your inbox, it shows up here. Add one manually if you already know about it.",
                            actionTitle: "Add a trial",
                            action: { showingManualAdd = true }
                        )
                    } else {
                        section(title: "Ending soon", items: endingSoon, isUrgent: endingSoonIsUrgent)
                        section(title: "Later", items: later, isUrgent: false)
                        suggestedSection
                    }
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
        .sheet(item: $selectedTrial) { trial in
            TrialDetailSheet(trial: trial, onSaveExisting: { _ in })
        }
        .sheet(item: $selectedLead) { lead in
            TrialDetailSheet(trial: lead, onSaveExisting: { trial in
                trial.isLead = false
            })
        }
        .sheet(isPresented: $showingManualAdd) {
            TrialDetailSheet(onCreateNew: { _ in })
        }
    }

    private var endingSoonIsUrgent: Bool {
        endingSoon.contains { daysUntil($0.trialEndDate) <= 3 }
    }

    private var demoBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                Text("DEMO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(SublyTheme.highlight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(SublyTheme.highlight.opacity(0.12)))

                Text("These sample trials are here so we can tune the layout, logos, and spacing before your real scan fills in.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SublyTheme.secondaryText)
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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trials")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("Your alerts, your later queue, and anything the parser wants you to verify.")
                    .font(.system(size: 14))
                    .foregroundStyle(SublyTheme.secondaryText)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func section(title: String, items: [Trial], isUrgent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(isUrgent ? SublyTheme.critical : SublyTheme.tertiaryText)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(SublyTheme.tertiaryText)
                }
            }
            if items.isEmpty {
                Text("Nothing here yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(SublyTheme.tertiaryText)
                    .padding(.leading, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { trial in
                        if isShowingDemoData {
                            SurfaceCard(padding: 18, emphasized: isUrgent) {
                                TrialListRow(trial: trial)
                            }
                        } else {
                            Button {
                                selectedTrial = trial
                            } label: {
                                SurfaceCard(padding: 18, emphasized: isUrgent) {
                                    TrialListRow(trial: trial)
                                }
                            }
                            .buttonStyle(PressableRowStyle())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TerminalSectionLabel(title: "Suggested", trailing: displayedLeads.isEmpty ? nil : "\(displayedLeads.count)")
            if displayedLeads.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(SublyTheme.accentSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SublyTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No leads to review")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SublyTheme.primaryText)
                        Text("When the parser finds a maybe, it shows up here.")
                            .font(.system(size: 12))
                            .foregroundStyle(SublyTheme.tertiaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(displayedLeads) { lead in
                        SurfaceCard(padding: 14, tint: SublyTheme.highlightSoft) {
                            SuggestedLeadRow(
                                lead: lead,
                                isDemo: isShowingDemoData,
                                onConfirm: {
                                    Haptics.play(.primaryTap)
                                    selectedLead = lead
                                },
                                onDismiss: {
                                    Haptics.play(.primaryTap)
                                    dismiss(lead)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func dismiss(_ trial: Trial) {
        trial.userDismissed = true
        try? modelContext.save()
    }
}

private struct TrialListRow: View {
    let trial: Trial

    var body: some View {
        let days = daysUntil(trial.trialEndDate)
        HStack(spacing: 14) {
            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trial.serviceName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SublyTheme.primaryText)
                    if trial.isManual {
                        Text("MANUAL")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(SublyTheme.tertiaryText)
                    }
                }
                HStack(spacing: 6) {
                    Text(trial.trialEndDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 13))
                        .foregroundStyle(SublyTheme.secondaryText)
                    if let lengthLabel = trialLengthDescription(for: trial) {
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundStyle(SublyTheme.tertiaryText)
                        Text(lengthLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SublyTheme.tertiaryText)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(trial.chargeAmount.map(formatUSD) ?? "TBD")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.primaryText)
                AccentPill(
                    text: days <= 0 ? "TODAY" : "\(days)D",
                    color: SublyTheme.urgencyColor(daysLeft: days)
                )
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SuggestedLeadRow: View {
    let lead: Trial
    let isDemo: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ServiceIcon(name: lead.serviceName, domain: lead.senderDomain, size: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.serviceName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("Detected \(lead.detectedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 12))
                    .foregroundStyle(SublyTheme.secondaryText)
            }
            Spacer()
            Button("Dismiss", action: onDismiss)
                .buttonStyle(SecondaryTerminalButtonStyle())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(isDemo)
            Button("Confirm", action: onConfirm)
                .buttonStyle(TerminalButtonStyle(background: SublyTheme.highlight, foreground: .white))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(isDemo)
        }
        .opacity(isDemo ? 0.6 : 1.0)
    }
}
