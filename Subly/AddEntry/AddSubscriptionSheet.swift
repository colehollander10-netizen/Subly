import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI

struct AddSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSave: (Trial) -> Void = { _ in }

    @State private var serviceName: String = ""
    @State private var chargeDate: Date
    @State private var billingCycle: BillingCycle = .monthly
    @State private var chargeAmountText: String = ""

    init(onSave: @escaping (Trial) -> Void = { _ in }) {
        self.onSave = onSave
        let in30 = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        _chargeDate = State(initialValue: in30)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HairlineDivider()
                        fieldsCard
                        Button {
                            save()
                        } label: {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canSave)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "New subscription")
            Text("Add Subscription")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
        }
    }

    @ViewBuilder
    private var fieldsCard: some View {
        SurfaceCard(padding: 0) {
            VStack(spacing: 0) {
                ServiceNameField(text: $serviceName, label: "Service", placeholder: "Netflix")
                HairlineDivider().padding(.leading, 54)
                DatePickerField(date: $chargeDate, label: "Next billing date")
                HairlineDivider().padding(.leading, 54)
                billingCycleField
                HairlineDivider().padding(.leading, 54)
                AmountField(text: $chargeAmountText, label: "Charge amount", placeholder: "9.99")
            }
        }
    }

    @ViewBuilder
    private var billingCycleField: some View {
        FieldRow(
            icon: AnyView(Ph.repeat.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
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
        let entry = Trial(
            serviceName: trimmed,
            senderDomain: "",
            chargeDate: chargeDate,
            chargeAmount: amount,
            entryType: .subscription,
            status: .active,
            billingCycle: billingCycle,
            notificationOffset: nil
        )
        modelContext.insert(entry)
        Haptics.play(.save)
        onSave(entry)
        dismiss()
    }
}

#Preview {
    if let container = try? ModelContainer(
        for: Schema([Trial.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) {
        ZStack {
            SublyTheme.background.ignoresSafeArea()
            AddSubscriptionSheet()
        }
        .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
