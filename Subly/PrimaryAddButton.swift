import SwiftUI

struct PrimaryAddButton: View {
    var icon: String = "plus"
    var accessibilityLabel: String = "Add"
    var accessibilityHint: String = ""
    var onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var diameter: CGFloat = 60

    @State private var didLongPress = false

    var body: some View {
        Group {
            if let onLongPress {
                buttonContent.simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                        didLongPress = true
                        Haptics.play(.primaryLongPress)
                        onLongPress()
                    }
                )
            } else {
                buttonContent
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var buttonContent: some View {
        Button {
            if didLongPress {
                didLongPress = false
                return
            }
            Haptics.play(.primaryTap)
            onTap()
        } label: {
            ZStack {
                backdrop
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SublyTheme.accent)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PrimaryAddButtonStyle())
    }

    @ViewBuilder
    private var backdrop: some View {
        if #available(iOS 26, *) {
            Color.clear
                .glassEffect(
                    .regular.tint(SublyTheme.accent.opacity(0.88)).interactive(true),
                    in: .circle
                )
        } else {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(SublyTheme.glassFill))
                    .overlay(Circle().stroke(SublyTheme.glassBorder, lineWidth: 1))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [SublyTheme.glassHighlight, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.plusLighter)
                    )
            }
        }
    }
}

private struct PrimaryAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        SublyTheme.background.ignoresSafeArea()
        VStack(spacing: 40) {
            PrimaryAddButton(onTap: {})
            PrimaryAddButton(onTap: {}, onLongPress: {}, diameter: 72)
        }
    }
}
