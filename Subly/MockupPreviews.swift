import SwiftUI

// Showing these in Xcode:
// 1. Open this file, then **Editor → Canvas** (or press **⌥⌘↩** / Option‑Command‑Return).
// 2. If the canvas says Paused, click **Resume** (▶︎).
// 3. At the bottom of the canvas, open the picker and choose a preview (Subscriptions, Trial Detail, etc.).
// 4. Set the run destination to an **iPhone Simulator** (toolbar), not “My Mac”.

// MARK: - Design tokens

private enum SublyMock {
    static let accent = Color(red: 0.29, green: 0.62, blue: 1.0)
    static let urgentRed = Color(red: 1.0, green: 0.32, blue: 0.38)
    static let warningAmber = Color(red: 1.0, green: 0.68, blue: 0.18)
    static let deepNavy = Color(red: 0.04, green: 0.05, blue: 0.09)
    static let charcoal = Color(red: 0.09, green: 0.1, blue: 0.12)
    static let glassStroke = Color.white.opacity(0.17)
    static let cornerRadius: CGFloat = 22
}

// MARK: - Background

private struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SublyMock.deepNavy,
                    SublyMock.charcoal,
                    Color(red: 0.05, green: 0.07, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    SublyMock.accent.opacity(0.12),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.08),
                    Color.clear,
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 380
            )

            NoiseOverlay()
                .blendMode(.overlay)
                .opacity(0.22)
        }
        .ignoresSafeArea()
    }
}

private struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 3
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let v = Double((x / cell + y / cell).truncatingRemainder(dividingBy: 7)) / 7.0
                    let o = 0.04 + v * 0.07
                    context.fill(
                        Path(CGRect(x: x, y: y, width: cell, height: cell)),
                        with: .color(Color.white.opacity(o))
                    )
                    y += cell
                }
                x += cell
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Glass card

private struct GlassCardModifier: ViewModifier {
    var urgencyGlow: UrgencyGlow?

    enum UrgencyGlow {
        case critical
        case soon
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                        .strokeBorder(SublyMock.glassStroke, lineWidth: 1)

                    if let urgencyGlow {
                        RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: glowColors(for: urgencyGlow),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                            .blur(radius: 6)
                            .opacity(0.85)
                    }
                }
            }
            .shadow(color: ambientGlow(for: urgencyGlow), radius: urgencyGlow == nil ? 16 : 24, y: 8)
    }

    private func glowColors(for glow: UrgencyGlow) -> [Color] {
        switch glow {
        case .critical:
            [SublyMock.urgentRed, SublyMock.urgentRed.opacity(0.2)]
        case .soon:
            [SublyMock.warningAmber, SublyMock.warningAmber.opacity(0.15)]
        }
    }

    private func ambientGlow(for glow: UrgencyGlow?) -> Color {
        switch glow {
        case .critical:
            SublyMock.urgentRed.opacity(0.25)
        case .soon:
            SublyMock.warningAmber.opacity(0.2)
        case .none:
            Color.white.opacity(0.06)
        }
    }
}

private extension View {
    func glassCard(urgencyGlow: GlassCardModifier.UrgencyGlow? = nil) -> some View {
        modifier(GlassCardModifier(urgencyGlow: urgencyGlow))
    }
}

// MARK: - Shared rows

private struct BrandGlyph: View {
    let systemName: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.55), tint.opacity(0.15)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 36
                    )
                )
                .frame(width: 52, height: 52)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }

            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

private struct DaysLeftBadge: View {
    let days: Int

    var body: some View {
        let critical = days < 3
        let soon = days < 7 && !critical
        return Text("\(days)d left")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(critical ? SublyMock.urgentRed : (soon ? SublyMock.warningAmber : Color.white.opacity(0.85)))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                (critical ? SublyMock.urgentRed : SublyMock.warningAmber).opacity(0.45),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: (critical ? SublyMock.urgentRed : SublyMock.warningAmber).opacity(0.35), radius: 8)
    }
}

// MARK: - 1. Subscriptions tab

private struct SubscriptionsTabMock: View {
    @State private var segment = 0

    private let activeRows: [(name: String, symbol: String, tint: Color, price: String, next: String)] = [
        ("Spotify", "music.note", .green, "$9.99", "Renews Mar 12"),
        ("Netflix", "play.rectangle.fill", .red, "$15.99", "Renews Mar 18"),
        ("ChatGPT Plus", "sparkles", .mint, "$20.00", "Renews Mar 22"),
    ]

    private let trialRows: [(name: String, symbol: String, tint: Color, price: String, days: Int)] = [
        ("Notion", "doc.text.fill", .white, "Then $10/mo", 2),
        ("Figma", "square.grid.2x2.fill", Color(red: 0.62, green: 0.38, blue: 1.0), "Then $15/mo", 6),
    ]

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(alignment: .leading, spacing: 0) {
                Text("Subscriptions")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.white)

                Text("Track renewals and trials in one calm place.")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)

                Picker("", selection: $segment) {
                    Text("Active").tag(0)
                    Text("Trials").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.top, 22)
                .tint(SublyMock.accent)

                ScrollView {
                    VStack(spacing: 14) {
                        if segment == 0 {
                            ForEach(Array(activeRows.enumerated()), id: \.offset) { _, row in
                                activeCard(row)
                            }
                        } else {
                            ForEach(Array(trialRows.enumerated()), id: \.offset) { _, row in
                                trialCard(row)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
        }
    }

    private func activeCard(_ row: (name: String, symbol: String, tint: Color, price: String, next: String)) -> some View {
        HStack(alignment: .center, spacing: 16) {
            BrandGlyph(systemName: row.symbol, tint: row.tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.name)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(row.price + " / mo")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(SublyMock.accent.opacity(0.95))
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(row.next)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(18)
        .glassCard(urgencyGlow: nil)
    }

    private func trialCard(_ row: (name: String, symbol: String, tint: Color, price: String, days: Int)) -> some View {
        let glow: GlassCardModifier.UrgencyGlow? = row.days < 3 ? .critical : (row.days < 7 ? .soon : nil)
        return HStack(alignment: .center, spacing: 16) {
            BrandGlyph(systemName: row.symbol, tint: row.tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.name)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(row.price)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            DaysLeftBadge(days: row.days)
        }
        .padding(18)
        .glassCard(urgencyGlow: glow)
    }
}

// MARK: - 2. Trial detail sheet

private struct TrialDetailSheetMock: View {
    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 22)

                BrandGlyph(systemName: "doc.text.fill", tint: .white)
                    .scaleEffect(1.85)

                Text("Notion")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text("2 days left in trial")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(SublyMock.urgentRed)
                    .shadow(color: SublyMock.urgentRed.opacity(0.45), radius: 14)
                    .padding(.top, 8)

                Text("Trial ends April 20, 2026")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 12) {
                    detailRow(title: "After trial", value: "$10.00 / month", highlight: true)
                    detailRow(title: "Detected from", value: "Gmail · receipts@notion.so", highlight: false)
                }
                .padding(20)
                .glassCard(urgencyGlow: nil)
                .padding(.top, 28)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button {
                    } label: {
                        Text("Cancel Trial")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                    .fill(Color.red.opacity(0.22))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                            .strokeBorder(Color.red.opacity(0.45), lineWidth: 1)
                                    }
                            }
                            .foregroundStyle(SublyMock.urgentRed)
                    }
                    .buttonStyle(.plain)
                    .shadow(color: SublyMock.urgentRed.opacity(0.25), radius: 18, y: 6)

                    Button {
                    } label: {
                        Text("Set Reminder")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                            .strokeBorder(SublyMock.glassStroke, lineWidth: 1)
                                    }
                            }
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func detailRow(title: String, value: String, highlight: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: highlight ? .semibold : .regular, design: .default))
                .foregroundStyle(highlight ? SublyMock.accent : .white.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 3. Onboarding scanning

private struct OnboardingScanningMock: View {
    @State private var pulse = false
    @State private var iconPulse = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 36) {
                Spacer()

                ZStack {
                    ForEach(0 ..< 3, id: \.self) { ring in
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        SublyMock.accent.opacity(0.45 - Double(ring) * 0.12),
                                        Color.white.opacity(0.08),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: CGFloat(140 + ring * 48), height: CGFloat(140 + ring * 48))
                            .scaleEffect(pulse ? 1.04 : 0.96)
                            .opacity(pulse ? 0.9 : 0.45)
                            .animation(
                                .easeInOut(duration: 1.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(ring) * 0.12),
                                value: pulse
                            )
                    }

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Circle()
                                .strokeBorder(SublyMock.glassStroke, lineWidth: 1)
                        }
                        .shadow(color: SublyMock.accent.opacity(0.35), radius: 28, y: 0)

                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, SublyMock.accent.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(iconPulse ? 1.05 : 0.98)
                        .opacity(iconPulse ? 1.0 : 0.88)
                        .animation(
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                            value: iconPulse
                        )
                }

                VStack(spacing: 12) {
                    Text("Scanning your inbox…")
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Finding subscriptions and trials you might have missed.")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: 0.62)
                        .tint(SublyMock.accent)
                        .scaleEffect(x: 1, y: 1.4, anchor: .center)
                        .padding(.horizontal, 8)

                    HStack {
                        Text("Parsing receipts")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Text("62%")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundStyle(SublyMock.accent)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .glassCard(urgencyGlow: nil)
                .padding(.horizontal, 36)

                Spacer()
                Spacer()
            }
            .onAppear {
                pulse = true
                iconPulse = true
            }
        }
    }
}

// MARK: - 4. Settings tab

private struct SettingsTabMock: View {
    @State private var notifyDays = 2

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(.white)

                    Text("Accounts & alerts")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.55))

                    VStack(spacing: 14) {
                        settingsRow(
                            title: "Gmail",
                            subtitle: "cole@example.com",
                            trailing: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(SublyMock.accent)
                                    .font(.title3)
                            },
                            leading: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [SublyMock.accent.opacity(0.5), SublyMock.accent.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    Text("C")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Trial reminders")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.white.opacity(0.45))
                                .textCase(.uppercase)

                            HStack {
                                Text("Notify me before trial ends")
                                    .font(.system(size: 16, weight: .medium, design: .default))
                                    .foregroundStyle(.white)
                                Spacer()
                                Stepper(value: $notifyDays, in: 1 ... 14) {
                                    Text("\(notifyDays) days")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SublyMock.accent)
                                        .frame(minWidth: 72, alignment: .trailing)
                                }
                                .tint(SublyMock.accent)
                            }
                        }
                        .padding(18)
                        .glassCard(urgencyGlow: nil)

                        settingsRow(
                            title: "Add subscription manually",
                            subtitle: "For services outside your inbox",
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.35))
                            },
                            leading: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(SublyMock.accent.opacity(0.9))
                                    .symbolRenderingMode(.hierarchical)
                            }
                        )
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Danger zone")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundStyle(SublyMock.urgentRed.opacity(0.85))
                            .textCase(.uppercase)

                        Button {
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Erase local data")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundStyle(.white)
                                    Text("Removes subscriptions stored on this device.")
                                        .font(.system(size: 13, weight: .regular, design: .default))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                                Image(systemName: "trash")
                                    .foregroundStyle(SublyMock.urgentRed)
                            }
                            .padding(18)
                            .background {
                                RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                    .fill(.thinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SublyMock.cornerRadius, style: .continuous)
                                            .strokeBorder(SublyMock.urgentRed.opacity(0.35), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .shadow(color: SublyMock.urgentRed.opacity(0.2), radius: 16, y: 6)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func settingsRow<Leading: View, Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(18)
        .glassCard(urgencyGlow: nil)
    }
}

// MARK: - Xcode previews (`#Preview` surfaces reliably in the Canvas)

#Preview("Subscriptions") {
    SubscriptionsTabMock()
        .preferredColorScheme(.dark)
}

#Preview("Trial Detail Sheet") {
    TrialDetailSheetMock()
        .preferredColorScheme(.dark)
}

#Preview("Onboarding · Scanning") {
    OnboardingScanningMock()
        .preferredColorScheme(.dark)
}

#Preview("Settings") {
    SettingsTabMock()
        .preferredColorScheme(.dark)
}
