import Foundation
import LogoService
import SubscriptionStore
import SwiftUI

enum SublyTheme {
    // Vulpine palette (2026-04-23). Warm charcoal base + Phosphor-orange accent
    // tied to the fox mascot. Higher contrast text than the prior cool lavender
    // palette — primaryText is pure white, secondaryText is a warm tan that
    // actually reads on the warm charcoal background.
    static let background = Color(red: 26 / 255, green: 22 / 255, blue: 20 / 255)         // #1A1614 warm charcoal
    static let backgroundElevated = Color(red: 37 / 255, green: 32 / 255, blue: 25 / 255) // #252019
    static let glassFill = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255).opacity(0.04)
    static let glassBorder = Color(red: 58 / 255, green: 47 / 255, blue: 38 / 255).opacity(0.85) // #3A2F26 warm stroke
    static let glassHighlight = Color.white.opacity(0.18)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 199 / 255, green: 187 / 255, blue: 176 / 255)   // #C7BBB0 warm light tan
    static let tertiaryText = Color(red: 134 / 255, green: 115 / 255, blue: 106 / 255)    // #86736A Vulpine Neutral
    static let divider = Color(red: 46 / 255, green: 38 / 255, blue: 32 / 255)            // #2E2620 warm dark divider
    static let accent = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)           // #F97316 Vulpine Primary
    static let accentSoft = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255).opacity(0.18) // #D97706 deeper amber, soft
    static let urgencyCalm = Color(red: 0 / 255, green: 162 / 255, blue: 244 / 255)       // #00A2F4 Vulpine Tertiary (sky blue = safe)
    static let urgencyWarning = Color(red: 172 / 255, green: 101 / 255, blue: 61 / 255)   // #AC653D Vulpine Secondary (cinnamon = warning)
    static let urgencyCritical = Color(red: 255 / 255, green: 176 / 255, blue: 77 / 255)  // #FFB04D brighter golden-orange (alarm — distinct from brand accent)
    static let urgencyDayOf = Color(red: 255 / 255, green: 209 / 255, blue: 102 / 255)    // #FFD166 brightest gold (TODAY)

    static func urgencyColor(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return urgencyDayOf }
        if daysLeft <= 3 { return urgencyCritical }
        if daysLeft <= 7 { return urgencyWarning }
        return urgencyCalm
    }
}

struct AppBackground: View {
    var body: some View {
        SublyTheme.background
            .ignoresSafeArea()
    }
}

struct ScreenFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
    }
}

struct SectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .tracking(1.8)
                .foregroundStyle(SublyTheme.tertiaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.tertiaryText)
            }
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(SublyTheme.divider)
            .frame(height: 1)
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SublyTheme.background)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(SublyTheme.accent.opacity(configuration.isPressed ? 0.82 : 1))
            )
    }
}

struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SublyTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(SublyTheme.accent, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct HeaderIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SublyTheme.backgroundElevated)
                    .overlay(Circle().fill(SublyTheme.glassFill))
                    .overlay(Circle().stroke(SublyTheme.glassBorder, lineWidth: 1))
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(SublyTheme.primaryText)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SublyTheme.primaryText)
                }
            }
            .frame(width: 40, height: 40)
            .padding(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AccentPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.10)))
            .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
    }
}

/// Compact live-updating preview row. ~72pt tall. Used in TrialDetailSheet
/// to show the user what their trial entry will look like in Home/Trials.
struct TrialPreviewRow: View {
    let name: String
    let domain: String?
    let endDate: Date?
    let amount: Decimal?

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your trial" : trimmed
    }

    private var daysUntilEnd: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day
    }

    private var urgencyColor: Color {
        guard let days = daysUntilEnd else { return SublyTheme.tertiaryText }
        return SublyTheme.urgencyColor(daysLeft: days)
    }

    private var daysLeftText: String {
        guard let days = daysUntilEnd else { return "—" }
        if days <= 0 { return "TODAY" }
        return "\(days)D LEFT"
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        switch (endDate, amount) {
        case (nil, _):
            return "Set an end date"
        case (let date?, nil):
            return "Ends \(formatter.string(from: date))"
        case (let date?, let amount?):
            return "Ends \(formatter.string(from: date)) · \(formatUSD(amount))"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ServiceIcon(name: displayName, domain: domain, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if daysUntilEnd != nil {
                AccentPill(text: daysLeftText, color: urgencyColor)
                    .contentTransition(.numericText())
                    .breathing((daysUntilEnd ?? 99) <= 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SublyTheme.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SublyTheme.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 24, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                // Solid warm fill instead of .ultraThinMaterial — material reads
                // washed-out gray on the flat charcoal background and ruins
                // legibility of fields inside the card.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(SublyTheme.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SublyTheme.glassBorder, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [SublyTheme.glassHighlight.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
    }
}

struct SurfaceCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        GlassCard(cornerRadius: 24, padding: padding) {
            content
        }
    }
}

struct FlagshipCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        GlassCard(cornerRadius: 28, padding: padding) {
            content
        }
    }
}

struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct BreathingModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(phase)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = 1.03
                }
            }
    }
}

extension View {
    func breathing(_ active: Bool) -> some View {
        modifier(BreathingModifier(active: active))
    }
}

struct ServiceIcon: View {
    let name: String
    var domain: String?
    var size: CGFloat = 40

    private var resolvedDomain: String? {
        BrandDirectory.logoDomain(for: name, senderDomain: domain)
    }

    private var fallbackColor: Color {
        let colors: [Color] = [
            SublyTheme.accent,
            SublyTheme.urgencyWarning,
            SublyTheme.urgencyCritical,
            SublyTheme.urgencyCalm,
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Group {
            if let resolvedDomain,
               let url = LogoService.logoURL(
                   for: resolvedDomain,
                   brandfetchClientID: AppSecrets.brandfetchClientID,
                   logoDevToken: AppSecrets.logoDevPublicToken,
                   size: Int(max(size * 2, 96))
               ) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(fallbackColor)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
        }
        .frame(width: size, height: size)
    }
}

enum BrandDirectory {
    private static let domainsByAlias: [String: String] = [
        "1password": "1password.com",
        "adobe": "adobe.com",
        "amazon prime": "amazon.com",
        "amazon": "amazon.com",
        "apple": "apple.com",
        "apple music": "apple.com",
        "apple one": "apple.com",
        "audible": "audible.com",
        "babbel": "babbel.com",
        "blinkist": "blinkist.com",
        "bumble": "bumble.com",
        "calm": "calm.com",
        "canva": "canva.com",
        "chatgpt": "openai.com",
        "claude": "anthropic.com",
        "copilot": "github.com",
        "cursor": "cursor.com",
        "discord nitro": "discord.com",
        "discord": "discord.com",
        "disney+": "disneyplus.com",
        "disney plus": "disneyplus.com",
        "disney": "disneyplus.com",
        "dropbox": "dropbox.com",
        "duolingo": "duolingo.com",
        "every": "every.to",
        "figma": "figma.com",
        "fitbod": "fitbod.me",
        "github copilot": "github.com",
        "grammarly": "grammarly.com",
        "headspace": "headspace.com",
        "hinge": "hinge.co",
        "hulu": "hulu.com",
        "icloud": "apple.com",
        "kindle unlimited": "amazon.com",
        "linkedin premium": "linkedin.com",
        "linkedin": "linkedin.com",
        "masterclass": "masterclass.com",
        "max": "max.com",
        "microsoft 365": "microsoft.com",
        "midjourney": "midjourney.com",
        "netflix": "netflix.com",
        "new york times": "nytimes.com",
        "notion": "notion.so",
        "nytimes": "nytimes.com",
        "openai": "openai.com",
        "paramount+": "paramountplus.com",
        "paramount plus": "paramountplus.com",
        "peloton": "onepeloton.com",
        "perplexity": "perplexity.ai",
        "readwise": "readwise.io",
        "scribd": "scribd.com",
        "spotify": "spotify.com",
        "strava": "strava.com",
        "substack": "substack.com",
        "youtube premium": "youtube.com",
        "youtube": "youtube.com",
        "wsj": "wsj.com",
        "wall street journal": "wsj.com",
    ]

    static func logoDomain(for serviceName: String, senderDomain: String?) -> String? {
        if let senderDomain {
            let trimmed = senderDomain
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "www.", with: "")
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let normalized = normalize(serviceName)
        if let exact = domainsByAlias[normalized] {
            return exact
        }

        if let fuzzy = domainsByAlias.first(where: { alias, _ in
            normalized.contains(alias) || alias.contains(normalized)
        })?.value {
            return fuzzy
        }

        return nil
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

enum DemoContent {
    static func activeTrials(referenceDate: Date = Date()) -> [Trial] {
        [
            demoTrial("Figma", domain: "figma.com", daysOut: 2, amount: 16, length: 14, from: referenceDate),
            demoTrial("Spotify", domain: "spotify.com", daysOut: 5, amount: 11.99, length: 30, from: referenceDate),
            demoTrial("Notion", domain: "notion.so", daysOut: 9, amount: 10, length: 14, from: referenceDate),
            demoTrial("MasterClass", domain: "masterclass.com", daysOut: 13, amount: 15, length: 30, from: referenceDate),
        ]
    }

    private static func demoTrial(
        _ serviceName: String,
        domain: String,
        daysOut: Int,
        amount: Decimal,
        length: Int? = nil,
        from referenceDate: Date
    ) -> Trial {
        Trial(
            serviceName: serviceName,
            senderDomain: domain,
            chargeDate: Calendar.current.date(byAdding: .day, value: daysOut, to: referenceDate) ?? referenceDate,
            chargeAmount: amount,
            detectedAt: referenceDate,
            trialLengthDays: length
        )
    }
}

enum AppSecrets {
    static var brandfetchClientID: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BRANDFETCH_CLIENT_ID") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var logoDevPublicToken: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "LOGO_DEV_PUBLIC_TOKEN") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct EmptyStateBlock: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(SublyTheme.accentSoft)
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SublyTheme.accent)
            }
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GhostButton())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}
