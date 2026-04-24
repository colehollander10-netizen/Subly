import SwiftUI

/// Finn's on-screen presence. One `FoxView` per placement — the view is
/// cheap and can be composed anywhere a mascot appears. Motion is keyed to
/// `FoxState` and respects `accessibilityReduceMotion`.
public struct FoxView: View {
    private let state: FoxState
    private let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: FoxState, size: CGFloat = 160) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Group {
            #if canImport(UIKit)
            if let uiImage = UIImage(named: state.assetName, in: .module, with: nil) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                PlaceholderFox(state: state)
            }
            #else
            PlaceholderFox(state: state)
            #endif
        }
        .frame(maxWidth: size, maxHeight: size)
        .modifier(FoxMotion(state: state, reduceMotion: reduceMotion))
        .accessibilityLabel(state.accessibilityLabel)
    }
}

/// Applies the per-state spring entry + optional emotional-beat loop. Kept
/// in one modifier so tuning happens in one place (design doc § Motion Rules).
private struct FoxMotion: ViewModifier {
    let state: FoxState
    let reduceMotion: Bool

    @State private var entered = false
    @State private var beatPhase: Int = 0
    @State private var beatTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scaleEffect(entered ? 1.0 : 0.92)
            .opacity(entered ? 1.0 : 0.0)
            .offset(y: beatOffset)
            .rotationEffect(.degrees(beatRotation))
            .onAppear { onStateBecomeActive() }
            .onChange(of: state) { _, _ in onStateBecomeActive() }
            .onDisappear { beatTask?.cancel() }
    }

    private var beatOffset: CGFloat {
        switch (state, beatPhase) {
        case (.hunting, 1): return -2
        case (.hunting, 2): return 1
        default: return 0
        }
    }

    private var beatRotation: Double {
        switch (state, beatPhase) {
        case (.nervous, 1): return -2
        case (.nervous, 2): return 2
        default: return 0
        }
    }

    private func onStateBecomeActive() {
        beatTask?.cancel()
        // Spring-bounce pose entry. Snap-with-overshoot feel per spec.
        if reduceMotion {
            entered = true
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                entered = true
            }
        }

        guard !reduceMotion, state.hasEmotionalBeat else {
            beatPhase = 0
            return
        }

        // Kick off the emotional-beat loop. `TimelineView` is too heavy for
        // the tiny offsets we need here — a cancellable loop Task is lighter
        // and stops automatically on state change or disappear.
        beatTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) { beatPhase = 1 }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) { beatPhase = 2 }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) { beatPhase = 0 }
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }
}

/// Shown when the asset catalog doesn't include a match for `state`. This
/// is the v1 pre-illustrator fallback — a flat capsule body + circle head
/// in the Vulpine palette so the layout still composes.
private struct PlaceholderFox: View {
    let state: FoxState

    private let vulpine = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    private let cream = Color(red: 250 / 255, green: 244 / 255, blue: 232 / 255)
    private let outline = Color(red: 26 / 255, green: 22 / 255, blue: 20 / 255)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                // Body (capsule)
                Capsule()
                    .fill(vulpine)
                    .frame(width: side * 0.72, height: side * 0.62)
                    .overlay(
                        Capsule().stroke(outline, lineWidth: side * 0.04)
                    )
                    .offset(y: side * 0.12)

                // Head (circle)
                Circle()
                    .fill(vulpine)
                    .frame(width: side * 0.58, height: side * 0.58)
                    .overlay(
                        Circle().stroke(outline, lineWidth: side * 0.04)
                    )
                    .offset(y: -side * 0.14)

                // Belly hint
                Capsule()
                    .fill(cream)
                    .frame(width: side * 0.32, height: side * 0.22)
                    .offset(y: side * 0.18)

                // Eye dots
                HStack(spacing: side * 0.14) {
                    Circle().fill(outline).frame(width: side * 0.08, height: side * 0.08)
                    Circle().fill(outline).frame(width: side * 0.08, height: side * 0.08)
                }
                .offset(y: -side * 0.14)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 28) {
        ForEach(FoxState.allCases, id: \.self) { state in
            HStack {
                FoxView(state: state, size: 80)
                    .frame(width: 96, height: 96)
                Text(state.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
