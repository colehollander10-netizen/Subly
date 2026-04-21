import SwiftUI

// MARK: - Design tokens

enum SublyTokens {
    // Urgency tiers
    static func urgencyColor(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return .sublyRed }
        if daysLeft <= 3 { return .sublyRed }
        if daysLeft <= 7 { return .sublyAmber }
        return .clear
    }

    static func urgencyGlowColor(daysLeft: Int) -> Color {
        if daysLeft <= 3 { return Color.sublyRed.opacity(0.45) }
        if daysLeft <= 7 { return Color.sublyAmber.opacity(0.35) }
        return Color.white.opacity(0.06)
    }

    static func urgencyBadgeColor(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return .sublyRed }
        if daysLeft <= 3 { return .sublyRed }
        if daysLeft <= 7 { return .sublyAmber }
        return Color.white.opacity(0.18)
    }
}

extension Color {
    static let sublyRed    = Color(red: 1.0,  green: 0.27, blue: 0.23) // #FF453A
    static let sublyAmber  = Color(red: 1.0,  green: 0.62, blue: 0.04) // #FF9F0A
    static let sublyBlue   = Color(red: 0.04, green: 0.52, blue: 1.0)  // #0A84FF
    static let sublyPurple = Color(red: 0.74, green: 0.35, blue: 1.0)  // #BD59FF

    // Background layers
    static let sublyBase   = Color(red: 0.04, green: 0.04, blue: 0.10) // near-black
}

// MARK: - Animated background

struct LiquidGlassBackground: View {
    @State private var t: CGFloat = 0

    var body: some View {
        ZStack {
            // Deep near-black base
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.09),
                    Color(red: 0.06, green: 0.03, blue: 0.14),
                    Color(red: 0.02, green: 0.05, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Purple blob — top left
            Circle()
                .fill(Color(red: 0.42, green: 0.18, blue: 0.95).opacity(0.50))
                .frame(width: 440, height: 440)
                .offset(x: -150 + cos(t) * 35, y: -270 + sin(t) * 50)
                .blur(radius: 100)

            // Cyan/blue blob — bottom right
            Circle()
                .fill(Color(red: 0.08, green: 0.48, blue: 0.98).opacity(0.38))
                .frame(width: 400, height: 400)
                .offset(x: 170 + sin(t * 0.7) * 45, y: 310 + cos(t * 0.7) * 45)
                .blur(radius: 95)

            // Accent pink — top right, subtle
            Circle()
                .fill(Color(red: 0.85, green: 0.25, blue: 0.65).opacity(0.20))
                .frame(width: 280, height: 280)
                .offset(x: 150 + cos(t * 1.1) * 25, y: -200 + sin(t * 1.1) * 35)
                .blur(radius: 110)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                t = .pi * 2
            }
        }
    }
}

// MARK: - Glass card (base)

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24

    init(padding: CGFloat = 20, cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.30),
                                        .white.opacity(0.08),
                                        .white.opacity(0.03),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Urgency trial card

/// Trial card that glows based on urgency. The glow bleeds through the glass
/// and tints the card edge — neutral (>7d), amber (≤7d), red (≤3d).
struct UrgencyCard<Content: View>: View {
    let daysLeft: Int
    let content: Content
    var padding: CGFloat = 20

    @State private var pulse = false

    init(daysLeft: Int, padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.daysLeft = daysLeft
        self.padding = padding
        self.content = content()
    }

    private var glowColor: Color { SublyTokens.urgencyGlowColor(daysLeft: daysLeft) }
    private var borderColor: Color {
        if daysLeft <= 3 { return Color.sublyRed.opacity(0.6) }
        if daysLeft <= 7 { return Color.sublyAmber.opacity(0.5) }
        return .white.opacity(0.15)
    }
    private var isUrgent: Bool { daysLeft <= 3 }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // Urgency tint layer
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(glowColor)
                    }
                    // Edge border
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [borderColor, borderColor.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
            }
            // Ambient glow behind card
            .shadow(color: glowColor.opacity(isUrgent ? (pulse ? 0.7 : 0.4) : 0.5), radius: isUrgent ? 18 : 12, x: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            .onAppear {
                if isUrgent {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
    }
}

// MARK: - Glass button

struct GlassButton: View {
    let title: String
    let systemImage: String?
    let isBusy: Bool
    let action: () -> Void

    init(title: String, systemImage: String? = nil, isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.20), .white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.30), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .disabled(isBusy)
    }
}

// MARK: - Countdown badge

struct CountdownBadge: View {
    let days: Int

    private var label: String {
        if days <= 0 { return "Today" }
        if days == 1 { return "1d" }
        return "\(days)d"
    }

    private var color: Color { SublyTokens.urgencyBadgeColor(daysLeft: days) }

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(color)
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.2), lineWidth: 0.5))
            )
    }
}

// MARK: - Service icon placeholder

/// Colored circle with first letter — stands in until we have real app icons.
struct ServiceIcon: View {
    let name: String
    var size: CGFloat = 40

    private var letter: String { String(name.prefix(1)).uppercased() }
    private var color: Color {
        // Deterministic color from service name hash
        let colors: [Color] = [
            Color(red: 0.4, green: 0.4, blue: 0.9),
            Color(red: 0.9, green: 0.4, blue: 0.4),
            Color(red: 0.4, green: 0.8, blue: 0.5),
            Color(red: 0.9, green: 0.6, blue: 0.2),
            Color(red: 0.6, green: 0.3, blue: 0.9),
            Color(red: 0.2, green: 0.7, blue: 0.9),
        ]
        let idx = abs(name.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                }
            Text(letter)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.4), radius: 8, y: 3)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
