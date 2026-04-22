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
                    .foregroundStyle(SublyTheme.surface)
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
                    .regular.tint(SublyTheme.primaryText.opacity(0.88)).interactive(true),
                    in: .circle
                )
        } else {
            ZStack {
                Circle().fill(SublyTheme.primaryText)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.4),
                                .init(color: .clear, location: 0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PrimaryAddButtonStyle: ButtonStyle {
    // Dual shadows (tight + diffuse) stack so the button reads as a grounded bead and a lifted element against Subly's warm off-white.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            .shadow(
                color: Color.black.opacity(0.10),
                radius: configuration.isPressed ? 10 : 18,
                x: 0,
                y: configuration.isPressed ? 4 : 10
            )
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
