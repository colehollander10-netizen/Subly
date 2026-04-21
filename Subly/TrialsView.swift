import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

/// Trials tab: full list of all active trials with a "+" for manual entry.
struct TrialsView: View {
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

    @State private var showingAddSheet = false
    @State private var confirmingLead: Trial?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if trials.isEmpty && leads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if !leads.isEmpty {
                            leadsSection
                        }
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
        .sheet(item: $confirmingLead) { lead in
            ConfirmLeadSheet(lead: lead, onConfirm: { confirmLead(lead) }, onDismiss: { dismiss(lead) })
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var leadsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Did you start these trials?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            ForEach(leads) { lead in
                LeadCard(lead: lead, onConfirm: { confirmingLead = lead }, onDismiss: { dismiss(lead) })
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
            Text("No trials yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("Subly scans your inbox automatically.\nMissing one? Add it yourself in seconds.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a trial manually")
                        .fontWeight(.semibold)
                }
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            }
            .padding(.top, 4)
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

    private func confirmLead(_ lead: Trial) {
        lead.isLead = false
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

// MARK: - Lead card

private struct LeadCard: View {
    let lead: Trial
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lead.serviceName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Detected \(lead.detectedAt.formatted(.dateTime.month().day()))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    Button(action: onConfirm) {
                        Text("Yes")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.blue.opacity(0.7)))
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Confirm lead sheet

private struct ConfirmLeadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let lead: Trial
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @State private var trialEndDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var chargeAmountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    Text(lead.serviceName)
                        .foregroundStyle(.secondary)
                }
                Section("Trial ends") {
                    DatePicker("", selection: $trialEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Section("Charge amount") {
                    TextField("20.00", text: $chargeAmountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Confirm trial")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not mine") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        lead.trialEndDate = trialEndDate
                        lead.chargeAmount = Decimal(string: chargeAmountText)
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add trial sheet

private struct AddTrialSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var serviceNameFocused: Bool

    @State private var serviceName = ""
    @State private var trialEndDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var chargeAmountText = ""
    @State private var pasteFeedback: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        applyClipboard()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste email to prefill")
                            Spacer()
                        }
                    }
                    if let pasteFeedback {
                        Text(pasteFeedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Copy a trial-start email, then tap to auto-fill what we can detect.")
                }
                Section("Service") {
                    TextField("e.g. Cursor Pro", text: $serviceName)
                        .focused($serviceNameFocused)
                        .submitLabel(.next)
                }
                Section("Trial ends") {
                    DatePicker("", selection: $trialEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Section("Charge amount") {
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    serviceNameFocused = true
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

    private func applyClipboard() {
        guard let raw = UIPasteboard.general.string, !raw.isEmpty else {
            pasteFeedback = "Clipboard is empty."
            return
        }
        let extracted = ManualTrialExtractor.extract(from: raw)
        var filled: [String] = []
        if let name = extracted.serviceName, serviceName.isEmpty {
            serviceName = name
            filled.append("service")
        }
        if let end = extracted.trialEndDate {
            trialEndDate = end
            filled.append("end date")
        }
        if let amount = extracted.chargeAmount, chargeAmountText.isEmpty {
            chargeAmountText = amount
            filled.append("amount")
        }
        pasteFeedback = filled.isEmpty
            ? "Couldn't detect trial details — fill in below."
            : "Filled: \(filled.joined(separator: ", "))."
    }
}

// MARK: - Manual trial extractor

/// Cheap clipboard parser for the paste-to-prefill flow. Deliberately no
/// dependency on `TrialParser` — the manual-add form must work even when
/// the parser's gates would reject the input.
enum ManualTrialExtractor {
    struct Result {
        let serviceName: String?
        let trialEndDate: Date?
        let chargeAmount: String?
    }

    static func extract(from text: String) -> Result {
        Result(
            serviceName: extractServiceName(from: text),
            trialEndDate: extractDate(from: text),
            chargeAmount: extractAmount(from: text)
        )
    }

    private static func extractServiceName(from text: String) -> String? {
        // Look for a From: header first — "From: The Cursor Team <team@cursor.com>"
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard lower.hasPrefix("from:") || lower.hasPrefix("from ") else { continue }
            let rest = String(line.dropFirst(5))
            if let lt = rest.firstIndex(of: "<") {
                let display = rest[..<lt].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !display.isEmpty { return display }
            }
            if let at = rest.lastIndex(of: "@") {
                let domain = rest[rest.index(after: at)...]
                    .trimmingCharacters(in: CharacterSet(charactersIn: "> \t\n\r"))
                let parts = domain.split(separator: ".")
                if parts.count >= 2 {
                    return String(parts[parts.count - 2]).capitalized
                }
            }
        }
        return nil
    }

    private static func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let future = Date().addingTimeInterval(60 * 60 * 6) // today or later
        for match in detector.matches(in: text, options: [], range: range) {
            if let d = match.date, d >= future { return d }
        }
        return nil
    }

    private static func extractAmount(from text: String) -> String? {
        let pattern = #"\$\s?(\d{1,4}(?:\.\d{2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.matches(in: text, options: [], range: range).first,
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[r])
    }
}
