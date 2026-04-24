import SwiftUI
import PhosphorSwift

struct AmountField: View {
    @Binding var text: String
    var label: String = "Charge amount"
    var placeholder: String = "20.00"

    var body: some View {
        FieldRow(
            icon: AnyView(Ph.currencyDollar.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
            label: label
        ) {
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(SublyTheme.tertiaryText)
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
            }
        }
    }
}
