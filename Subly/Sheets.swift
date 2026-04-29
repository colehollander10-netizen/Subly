import NotificationEngine
import PhosphorSwift
import SubscriptionStore
import TrialParsingCore
import SwiftData
import SwiftUI
import UIKit

struct TrialDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trial: Trial?
    let onSaveExisting: ((Trial) -> Void)?
    let onCreateNew: ((Trial) -> Void)?
    let notificationEngine: NotificationEngine?
    private let initialSharedText: String?

    private enum Preset: Int, CaseIterable, Identifiable {
        case sevenDays = 7
        case fourteenDays = 14
        case thirtyDays = 30
        case oneYear = 365
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .sevenDays: return "7d"
            case .fourteenDays: return "14d"
            case .thirtyDays: return "30d"
            case .oneYear: return "1y"
            }
        }
    }

    @State private var selectedPreset: Preset? = nil
    @State private var applyingPreset: Bool = false
    @FocusState private var focused: Bool
    @State private var serviceName: String
    @State private var trialEndDate: Date
    @State private var chargeAmountText: String
    @State private var pasteFilledFields: [String] = []
    @State private var pasteShowsSuccess: Bool = false
    @State private var didApplyInitialSharedText = false
    @State private var pasteResetTask: Task<Void, Never>? = nil
    @State private var showingCancelAssist = false

    init(
        trial: Trial? = nil,
        initialSharedText: String? = nil,
        onSaveExisting: ((Trial) -> Void)? = nil,
        onCreateNew: ((Trial) -> Void)? = nil,
        notificationEngine: NotificationEngine? = nil
    ) {
        self.trial = trial
        self.onSaveExisting = onSaveExisting
        self.onCreateNew = onCreateNew
        self.notificationEngine = notificationEngine
        self.initialSharedText = initialSharedText
        _serviceName = State(initialValue: trial?.serviceName ?? "")
        let resolvedEndDate = trial?.chargeDate ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        _trialEndDate = State(initialValue: resolvedEndDate)
        _chargeAmountText = State(initialValue: trial?.chargeAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        if let trial {
            let days = Calendar.current.dateComponents([.day], from: trial.detectedAt, to: trial.chargeDate).day ?? 0
            let match = Preset.allCases.first { abs($0.rawValue - days) <= 1 }
            _selectedPreset = State(initialValue: match)
        } else {
            _selectedPreset = State(initialValue: nil)
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: chargeAmountText.replacingOccurrences(of: "$", with: ""))
    }

    private var previewDomain: String? {
        BrandDirectory.logoDomain(for: serviceName, senderDomain: trial?.senderDomain)
    }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HairlineDivider()
                        TrialPreviewRow(
                            name: serviceName,
                            domain: previewDomain,
                            endDate: trialEndDate,
                            amount: parsedAmount
                        )
                        fieldsCard
                        Button {
                            Haptics.play(.save)
                            save()
                        } label: {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.top, 4)

                        if let trial {
                            VStack(spacing: 16) {
                                HairlineDivider()
                                Button {
                                    guard trial.status != .cancelled, notificationEngine != nil else { return }
                                    Haptics.play(.markCanceled)
                                    showingCancelAssist = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Ph.prohibit.bold
                                            .color(FinnTheme.urgencyCritical)
                                            .frame(width: 16, height: 16)
                                        Text("Cancel trial")
                                            .font(.system(size: 15, weight: .medium, design: .default))
                                            .foregroundStyle(FinnTheme.urgencyCritical)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 20)
                        }
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingCancelAssist) {
            if let trial, let notificationEngine {
                CancelAssistSheet(trial: trial, notificationEngine: notificationEngine)
            }
        }
        .onChange(of: trial?.status) { _, newValue in
            if newValue == .cancelled {
                dismiss()
            }
        }
        .onAppear {
            applyInitialSharedTextIfNeeded()
            if trial == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focused = true
                }
            }
        }
        .onDisappear {
            pasteResetTask?.cancel()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: trial == nil ? "New trial" : "Edit trial")
            Text(trial == nil ? "Add Trial" : "Edit Trial")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(FinnTheme.primaryText)
        }
    }

    @ViewBuilder
    private var fieldsCard: some View {
        SurfaceCard(padding: 0) {
            VStack(spacing: 0) {
                if trial == nil {
                    pasteRow
                    HairlineDivider().padding(.leading, 54)
                }
                serviceField
                HairlineDivider().padding(.leading, 54)
                trialEndsField
                HairlineDivider().padding(.leading, 54)
                chargeAmountField
            }
        }
    }

    @ViewBuilder
    private var pasteRow: some View {
        Button {
            Haptics.play(.primaryTap)
            applyClipboard()
        } label: {
            HStack(spacing: 14) {
                Group {
                    if pasteShowsSuccess {
                        Ph.checkCircle.fill
                            .color(FinnTheme.accent)
                            .frame(width: 22, height: 22)
                    } else {
                        Ph.clipboardText.regular
                            .color(FinnTheme.tertiaryText)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 24, height: 22, alignment: .center)
                .padding(.top, 2)

                Text(pasteShowsSuccess
                     ? "Filled: \(pasteFilledFields.joined(separator: ", "))"
                     : "Paste from clipboard")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(pasteShowsSuccess ? FinnTheme.accent : FinnTheme.primaryText)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var serviceField: some View {
        ServiceNameField(text: $serviceName, label: "Service", placeholder: "Cursor Pro", focusBinding: $focused)
    }

    @ViewBuilder
    private var trialEndsField: some View {
        DatePickerField(
            date: $trialEndDate,
            label: "Trial ends",
            onDateChange: { _ in
                if applyingPreset { return }
                selectedPreset = nil
            }
        ) {
            presetRow
        }
    }

    @ViewBuilder
    private var chargeAmountField: some View {
        AmountField(text: $chargeAmountText, label: "Charge amount", placeholder: "20.00")
    }

    @ViewBuilder
    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Preset.allCases) { preset in
                    let isSelected = selectedPreset == preset
                    Button {
                        applyingPreset = true
                        selectedPreset = preset
                        trialEndDate = Calendar.current.date(byAdding: .day, value: preset.rawValue, to: Date()) ?? trialEndDate
                        Haptics.play(.primaryTap)
                        Task { @MainActor in applyingPreset = false }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? FinnTheme.background : FinnTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? FinnTheme.accent : FinnTheme.backgroundElevated)
                            )
                            .overlay(
                                Capsule().strokeBorder(isSelected ? Color.clear : FinnTheme.divider, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = parsedAmount
        let inferredDomain = BrandDirectory.logoDomain(for: trimmedName, senderDomain: trial?.senderDomain)
        if let trial {
            trial.serviceName = trimmedName
            if (trial.senderDomain).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                trial.senderDomain = inferredDomain ?? ""
            }
            trial.chargeDate = trialEndDate
            trial.chargeAmount = amount
            onSaveExisting?(trial)
        } else {
            let newTrial = Trial(
                serviceName: trimmedName,
                senderDomain: inferredDomain ?? "",
                chargeDate: trialEndDate,
                chargeAmount: amount
            )
            modelContext.insert(newTrial)
            onCreateNew?(newTrial)
        }
        try? modelContext.save()

        let container = modelContext.container
        Task {
            let coordinator = TrialAlertCoordinator(
                modelContainer: container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()
        }

        dismiss()
    }

    private func applyClipboard() {
        guard let raw = UIPasteboard.general.string, !raw.isEmpty else {
            return
        }
        applySharedText(raw)
    }

    private func applyInitialSharedTextIfNeeded() {
        guard !didApplyInitialSharedText else { return }
        didApplyInitialSharedText = true
        guard let initialSharedText, trial == nil else { return }
        applySharedText(initialSharedText)
    }

    private func applySharedText(_ text: String) {
        let extracted = PastedTrialExtractor.extract(from: text)
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
        guard !filled.isEmpty else { return }
        pasteFilledFields = filled
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            pasteShowsSuccess = true
        }
        pasteResetTask?.cancel()
        pasteResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                pasteShowsSuccess = false
            }
        }
    }
}

enum PastedTrialExtractor {
    struct Result {
        let serviceName: String?
        let trialEndDate: Date?
        let chargeAmount: String?
    }

    static func extract(from text: String) -> Result {
        let classification = TrialParser.classifyText(text, source: .pastedText)
        guard classification.confidence != .low else {
            return Result(serviceName: nil, trialEndDate: nil, chargeAmount: nil)
        }

        return Result(
            serviceName: normalizedServiceName(classification.serviceName),
            trialEndDate: classification.trialEndDate,
            chargeAmount: classification.chargeAmount.map { NSDecimalNumber(decimal: $0).stringValue }
        )
    }

    private static func normalizedServiceName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Unknown" else { return nil }
        return trimmed
    }
}
