import SubscriptionStore
import SwiftData
import SwiftUI

/// Trials tab: full list of all active trials with a "+" for manual entry.
struct TrialsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trial> { !$0.userDismissed },
        sort: \Trial.trialEndDate,
        order: .forward
    ) private var trials: [Trial]

    @State private var showingAddSheet = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if trials.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(trials) { trial in
                            TrialCard(trial: trial, onDismiss: { dismiss(trial) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTrialSheet()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
            Text("No trials yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Scan your inbox from the Home tab,\nor add a trial manually with +.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                }
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
    }

    // MARK: - Actions

    private func dismiss(_ trial: Trial) {
        trial.userDismissed = true
        try? modelContext.save()
    }
}

// MARK: - Trial card

private struct TrialCard: View {
    let trial: Trial
    let onDismiss: () -> Void

    var body: some View {
        GlassCard(padding: 18) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(trial.serviceName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if trial.isManual {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.caption)
                        }
                    }
                    Text("Ends \(trial.trialEndDate.formatted(.dateTime.month().day()))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    if let amount = trial.chargeAmount {
                        Text("Will charge \(formatUSD(amount))")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.95))
                    }
                }
                Spacer()
                countdown(days: daysUntil(trial.trialEndDate))
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDismiss()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func countdown(days: Int) -> some View {
        let label: String = {
            if days <= 0 { return "Today" }
            if days == 1 { return "1d" }
            return "\(days)d"
        }()
        let color: Color = days <= 3 ? .red : (days <= 7 ? .orange : .white.opacity(0.2))

        Text(label)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.85)))
    }
}

// MARK: - Add trial sheet

private struct AddTrialSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var serviceName = ""
    @State private var trialEndDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var chargeAmountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("e.g. Cursor Pro", text: $serviceName)
                }
                Section("Trial ends") {
                    DatePicker("", selection: $trialEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Section("Charge amount (optional)") {
                    TextField("20.00", text: $chargeAmountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add a trial")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(serviceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let amount = Decimal(string: chargeAmountText)
        let trial = Trial(
            accountID: "",
            serviceName: serviceName.trimmingCharacters(in: .whitespaces),
            senderDomain: "",
            trialEndDate: trialEndDate,
            chargeAmount: amount,
            sourceEmailID: nil,
            isManual: true
        )
        modelContext.insert(trial)
        try? modelContext.save()
        dismiss()
    }
}
