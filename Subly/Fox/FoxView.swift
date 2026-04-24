import SwiftUI

struct FoxView: View {
    let state: FoxState
    var size: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var celebrationBounce = false

    var body: some View {
        Image(state.assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: size, maxHeight: size)
            .scaleEffect(currentScale)
            .accessibilityLabel(state.accessibilityLabel)
            .onAppear { startIdleAnimation() }
            .onChange(of: state) { _, _ in startIdleAnimation() }
    }

    private var currentScale: CGFloat {
        if reduceMotion { return 1.0 }
        switch state {
        case .sleeping:
            return breathing ? 1.02 : 1.0
        case .proud, .veryHappy:
            return celebrationBounce ? 1.06 : 1.0
        default:
            return 1.0
        }
    }

    private func startIdleAnimation() {
        guard !reduceMotion else { return }
        switch state {
        case .sleeping:
            // Slow 2s breathing loop — only ambient/decorative animation per DESIGN.md.
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathing = true
            }
        case .proud, .veryHappy:
            // Single short celebration bounce — not looped.
            celebrationBounce = false
            withAnimation(.spring(response: 0.36, dampingFraction: 0.6)) {
                celebrationBounce = true
            }
        default:
            breathing = false
            celebrationBounce = false
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        FoxView(state: .sleeping)
        FoxView(state: .curious, size: 96)
        FoxView(state: .proud, size: 200)
    }
    .padding()
    .background(FinnTheme.background)
}
