import SwiftUI

struct FieldRow<Content: View>: View {
    let icon: AnyView
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.8)
                    .foregroundStyle(SublyTheme.secondaryText)
                content()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
