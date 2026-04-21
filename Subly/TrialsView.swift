import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !leads.isEmpty {
                            leadsSection
                                .padding(.top, 24)
                                .padding(.horizontal, 20)
                        }

                        if !trials.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: trials.count == 1 ? "1 active trial" : "\(trials.count) active trials")
                                    .padding(.horizontal, 20)
                                    .padding(.top, leads.isEmpty ? 24 : 28)

                                VStack(spacing: 12) {
                                    ForEach(trials) { trial in
                                        TrialRow(trial: trial, onDismiss: { dismiss(trial) })
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addFAB
                        .padding(.trailing, 24)
                        .padding(.bottom, 28)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTrialSheet()
        }
        .sheet(item: $confirmingLead) { lead in
            ConfirmLeadSheet(
                lead: lead,
                onConfirm: { confirmLead(lead) },
                onDismiss: { dismiss(lead) }
            )
        }
    }

    // MARK: - Leads section

    @ViewBuilder
    private var leadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Did you start these?")

            VStack(spacing: 10) {
                ForEach(leads) { lead in
                    LeadRow(lead: lead, onConfirm: { confirmingLead = lead }, onDismiss: { dismiss(lead) })
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            GlassCard(padding: 36, cornerRadius: 28) {
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.sublyPurple.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: "timer")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    VStack(spacing: 8) {
                        Text("No trials yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Subly scans your inbox automatically.\nMissing one? Add it in seconds.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    Button {
                        showingAddSheet = true
                    } label: {
                        Text("Add manually")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - FAB

    @ViewBuilder
    private var addFAB: some View {
        Button { showingAddSheet = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.sublyBlue.opacity(0.75), Color.sublyPurple.opacity(0.70)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .shadow(color: Color.sublyBlue.opacity(0.45), radius: 14, y: 5)
        }
    }

    // MARK: - Actions

    private func dismiss(_ trial: Trial) {
        withAnimation(.spring(response: 0.35)) {
            trial.userDismissed = true
        }
        try? modelContext.save()
    }

    private func confirmLead(_ lead: Trial) {
        withAnimation(.spring(response: 0.35)) {
            lead.isLead = false
        }
        try? modelContext.save()
    }
}

// MARK: - Trial row

private struct TrialRow: View {
    let trial: Trial
    let onDismiss: () -> Void

    var body: some View {
        let days = daysUntil(trial.trialEndDate)
        UrgencyCard(daysLeft: days) {
            HStack(spacing: 14) {
                ServiceIcon(name: trial.serviceName, size: 44)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(trial.serviceName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if trial.isManual {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.40))
                        }
                    }
                    Text("Ends \(trial.trialEndDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    if let amount = trial.chargeAmount {
                        Text("Will charge \(formatUSD(amount))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(days <= 7 ? Color.sublyAmber : .white.opacity(0.60))
                    }
                }

                Spacer()

                CountdownBadge(days: days)
            }
        }
        .contextMenu {
            Button(role: .destructive) { onDismiss() } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Lead row

private struct LeadRow: View {
    let lead: Trial
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 12) {
                ServiceIcon(name: lead.serviceName, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(lead.serviceName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Found \(lead.detectedAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.white.opacity(0.10)))
                    }

                    Button(action: onConfirm) {
                        Text("Yes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.sublyBlue.opacity(0.70))
                                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.2), lineWidth: 0.5))
                            )
                    }
                }
            }
        }
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
                Section("Charge amount (optional)") {
                    TextField("20.00", text: $chargeAmountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Confirm trial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not mine") { onDismiss(); dismiss() }
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
                    Button { applyClipboard() } label: {
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
            .navigationBarTitleDisplayMode(.inline)
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
            serviceName = name; filled.append("service")
        }
        if let end = extracted.trialEndDate {
            trialEndDate = end; filled.append("end date")
        }
        if let amount = extracted.chargeAmount, chargeAmountText.isEmpty {
            chargeAmountText = amount; filled.append("amount")
        }
        pasteFeedback = filled.isEmpty
            ? "Couldn't detect trial details — fill in below."
            : "Filled: \(filled.joined(separator: ", "))."
    }
}

// MARK: - Manual trial extractor

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
                if parts.count >= 2 { return String(parts[parts.count - 2]).capitalized }
            }
        }
        return nil
    }

    private static func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let future = Date().addingTimeInterval(60 * 60 * 6)
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
