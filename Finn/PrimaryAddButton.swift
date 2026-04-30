import SwiftUI
import PhosphorSwift

struct PrimaryAddButton: View {
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
                Circle()
                    .fill(FinnTheme.accent)
                Ph.plus.bold
                    .color(FinnTheme.background)
                    .frame(width: 24, height: 24)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PrimaryAddButtonStyle())
    }
}

private struct PrimaryAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(FinnMotion.press, value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        FinnTheme.background.ignoresSafeArea()
        VStack(spacing: 40) {
            PrimaryAddButton(onTap: {})
            PrimaryAddButton(onTap: {}, onLongPress: {}, diameter: 72)
        }
    }
}
