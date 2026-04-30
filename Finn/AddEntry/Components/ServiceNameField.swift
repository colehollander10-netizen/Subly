import SwiftUI
import PhosphorSwift

struct ServiceNameField: View {
    @Binding var text: String
    var label: String = "Service"
    var placeholder: String = "Cursor Pro"
    var focusBinding: FocusState<Bool>.Binding? = nil

    var body: some View {
        FieldRow(
            icon: AnyView(Ph.briefcase.regular.color(FinnTheme.tertiaryText).frame(width: 22, height: 22)),
            label: label
        ) {
            if let focusBinding {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.words)
                    .focused(focusBinding)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundStyle(FinnTheme.primaryText)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundStyle(FinnTheme.primaryText)
            }
        }
    }
}
