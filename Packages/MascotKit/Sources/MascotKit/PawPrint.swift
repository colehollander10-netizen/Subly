import SwiftUI

/// A single paw print glyph — main pad + 4 toe beans. Flat fill, no
/// gradients or shadows, matching the Duolingo art direction.
public struct PawPrint: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Main pad: a rounded quad centered on the lower half.
        let padRect = CGRect(
            x: rect.minX + w * 0.22,
            y: rect.minY + h * 0.48,
            width: w * 0.56,
            height: h * 0.42
        )
        path.addRoundedRect(in: padRect, cornerSize: CGSize(width: w * 0.16, height: h * 0.16))

        // Four toe beans, splayed across the upper half.
        let toeRadius = w * 0.12
        let toeY = rect.minY + h * 0.18
        let toeOffsets: [CGFloat] = [0.18, 0.40, 0.60, 0.82]
        for offset in toeOffsets {
            let cx = rect.minX + w * offset
            let toeRect = CGRect(
                x: cx - toeRadius,
                y: toeY,
                width: toeRadius * 2,
                height: toeRadius * 2
            )
            path.addEllipse(in: toeRect)
        }
        return path
    }
}

/// Static walking trail of paw prints. Used in onboarding finale, Trials
/// empty state, Settings "About Finn" footer.
public struct PawPrintTrail: View {
    private let count: Int
    private let color: Color
    private let size: CGFloat

    public init(count: Int = 5, color: Color = .orange, size: CGFloat = 18) {
        self.count = max(count, 1)
        self.color = color
        self.size = size
    }

    public var body: some View {
        HStack(spacing: size * 0.9) {
            ForEach(0 ..< count, id: \.self) { index in
                PawPrint()
                    .fill(color)
                    .frame(width: size, height: size)
                    // Gentle alternation so the trail reads as walking
                    // rather than a line of stamps.
                    .offset(y: index.isMultiple(of: 2) ? 0 : size * 0.3)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -8 : 8))
                    .opacity(0.85)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Celebratory paw-print confetti burst. Fires on kill-celebration, savings
/// increment, onboarding finale. Under Reduce Motion, collapses to a single
/// static paw print at center.
public struct PawPrintConfetti: View {
    private let trigger: Bool
    private let pieceCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(trigger: Bool, pieceCount: Int = 24) {
        self.trigger = trigger
        self.pieceCount = pieceCount
    }

    public var body: some View {
        GeometryReader { proxy in
            if reduceMotion {
                if trigger {
                    PawPrint()
                        .fill(Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255))
                        .frame(width: 32, height: 32)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .accessibilityHidden(true)
                }
            } else {
                ZStack {
                    ForEach(0 ..< pieceCount, id: \.self) { index in
                        ConfettiPiece(
                            index: index,
                            total: pieceCount,
                            canvas: proxy.size,
                            trigger: trigger
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let total: Int
    let canvas: CGSize
    let trigger: Bool

    @State private var fallen = false

    private var palette: Color {
        let vulpine = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
        let cream = Color(red: 250 / 255, green: 244 / 255, blue: 232 / 255)
        let sky = Color(red: 0 / 255, green: 162 / 255, blue: 244 / 255)
        switch index % 3 {
        case 0: return vulpine
        case 1: return cream
        default: return sky
        }
    }

    private var startX: CGFloat {
        // Spread uniformly across canvas width with slight jitter.
        let step = canvas.width / CGFloat(max(total - 1, 1))
        let jitter = CGFloat((index * 2654435761) % 40) - 20
        return step * CGFloat(index) + jitter
    }

    private var duration: Double {
        1.4 + Double(index % 5) * 0.18
    }

    private var drift: CGFloat {
        CGFloat((index * 2654435761) % 60) - 30
    }

    private var rotationAmount: Double {
        Double((index % 4) * 90 + 20)
    }

    var body: some View {
        PawPrint()
            .fill(palette)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(fallen ? rotationAmount : 0))
            .position(
                x: startX + (fallen ? drift : 0),
                y: fallen ? canvas.height + 20 : -20
            )
            .opacity(fallen ? 0 : 1)
            .onChange(of: trigger) { _, newValue in
                guard newValue else {
                    fallen = false
                    return
                }
                withAnimation(.easeIn(duration: duration)) {
                    fallen = true
                }
            }
    }
}

#Preview {
    VStack(spacing: 28) {
        PawPrintTrail(count: 5, color: .orange, size: 22)
        PawPrint()
            .fill(Color.orange)
            .frame(width: 60, height: 60)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
