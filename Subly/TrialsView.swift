import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI

struct TrialsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed },
        sort: \Trial.chargeDate,
        order: .forward
    ) private var trials: [Trial]

    @State private var selectedTrial: Trial?
    @State private var showingManualAdd = false

    private var endingSoon: [Trial] { trials.filter { daysUntil($0.chargeDate) <= 7 } }
    private var later: [Trial] { trials.filter { daysUntil($0.chargeDate) > 7 } }

    var body: some View {
        ScreenFrame {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if trials.isEmpty {
                        emptyState
                    } else {
                        if !endingSoon.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Ending soon", trailing: "\(endingSoon.count)")
                                SurfaceCard(padding: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(endingSoon.enumerated()), id: \.element.id) { index, trial in
                                            Button {
                                                Haptics.play(.rowTap)
                                                selectedTrial = trial
                                            } label: {
                                                TrialListRow(trial: trial)
                                                    .padding(.horizontal, 18)
                                                    .padding(.vertical, 14)
                                            }
                                            .buttonStyle(PressableRowStyle())
                                            if index < endingSoon.count - 1 {
                                                HairlineDivider().padding(.horizontal, 18)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if !later.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Later", trailing: "\(later.count)")
                                SurfaceCard(padding: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(later.enumerated()), id: \.element.id) { index, trial in
                                            Button {
                                                Haptics.play(.rowTap)
                                                selectedTrial = trial
                                            } label: {
                                                TrialListRow(trial: trial)
                                                    .padding(.horizontal, 18)
                                                    .padding(.vertical, 14)
                                            }
                                            .buttonStyle(PressableRowStyle())
                                            if index < later.count - 1 {
                                                HairlineDivider().padding(.horizontal, 18)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .overlay(alignment: .bottomTrailing) {
                PrimaryAddButton(
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
            TrialDetailSheet(
                trial: trial,
                onSaveExisting: { _ in },
                onMarkCancelled: { t in markCancelled(t) }
            )
        }
        .onChange(of: selectedTrial?.id) { _, newValue in
            if newValue != nil { Haptics.play(.sheetPresent) }
        }
        .sheet(isPresented: $showingManualAdd) {
            TrialDetailSheet(onCreateNew: { _ in })
        }
        .onChange(of: showingManualAdd) { _, newValue in
            if newValue { Haptics.play(.sheetPresent) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trials")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
            if !trials.isEmpty {
                Text("\(trials.count) trial\(trials.count == 1 ? "" : "s") tracked")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SublyTheme.tertiaryText)
                    .monospacedDigit()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            Ph.moonStars.duotone
                .color(SublyTheme.accent.opacity(0.4))
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("No trials yet.")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("Add a trial with the + button so we can warn you before it charges.")
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

    private func markCancelled(_ trial: Trial) {
        trial.userDismissed = true
        try? modelContext.save()
        // TODO(COL-128): trigger replanAll when notificationEngine is wired through TrialsView
    }
}

private struct TrialListRow: View {
    let trial: Trial

    var body: some View {
        let days = daysUntil(trial.chargeDate)
        HStack(spacing: 14) {
            ServiceIcon(name: trial.serviceName, domain: trial.senderDomain, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(trial.serviceName)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(SublyTheme.primaryText)
                HStack(spacing: 6) {
                    Text(trial.chargeDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
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
            VStack(alignment: .trailing, spacing: 3) {
                Text(trial.chargeAmount.map(formatUSD) ?? "TBD")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
