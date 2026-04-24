import SwiftUI
import PhosphorSwift

struct DatePickerField<Footer: View>: View {
    @Binding var date: Date
    var label: String
    var onDateChange: ((Date) -> Void)? = nil
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        FieldRow(
            icon: AnyView(Ph.calendar.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
            label: label
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .onChange(of: date) { _, newValue in
                        onDateChange?(newValue)
                    }
                footer()
            }
        }
    }
}

extension DatePickerField where Footer == EmptyView {
    init(
        date: Binding<Date>,
        label: String,
        onDateChange: ((Date) -> Void)? = nil
    ) {
        self._date = date
        self.label = label
        self.onDateChange = onDateChange
        self.footer = { EmptyView() }
    }
}
