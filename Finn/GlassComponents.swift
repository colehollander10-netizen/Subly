import Foundation
import LogoService
import SubscriptionStore
import SwiftUI

enum FinnTheme {
    static let background = Color(red: 26 / 255, green: 22 / 255, blue: 20 / 255) // #1A1614
    static let backgroundElevated = Color(red: 34 / 255, green: 30 / 255, blue: 27 / 255) // #221E1B
    static let glassFill = Color(red: 251 / 255, green: 247 / 255, blue: 242 / 255).opacity(0.04)
    static let glassBorder = Color(red: 251 / 255, green: 247 / 255, blue: 242 / 255).opacity(0.12)
    static let glassHighlight = Color(red: 251 / 255, green: 247 / 255, blue: 242 / 255).opacity(0.18)
    static let primaryText = Color(red: 251 / 255, green: 247 / 255, blue: 242 / 255) // #FBF7F2
    static let secondaryText = Color(red: 184 / 255, green: 175 / 255, blue: 167 / 255) // #B8AFA7
    static let tertiaryText = Color(red: 130 / 255, green: 122 / 255, blue: 114 / 255) // #827A72
    static let divider = Color(red: 251 / 255, green: 247 / 255, blue: 242 / 255).opacity(0.08)
    static let accent = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255) // #F97316
    static let accentSoft = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255).opacity(0.14)
    static let urgencyCalm = Color(red: 143 / 255, green: 163 / 255, blue: 190 / 255) // #8FA3BE
    static let urgencyWarning = Color(red: 245 / 255, green: 179 / 255, blue: 102 / 255) // #F5B366
    static let urgencyCritical = Color(red: 255 / 255, green: 122 / 255, blue: 107 / 255) // #FF7A6B
    static let urgencyDayOf = Color(red: 255 / 255, green: 90 / 255, blue: 74 / 255) // #FF5A4A

    static func urgencyColor(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return urgencyDayOf }
        if daysLeft <= 3 { return urgencyCritical }
        if daysLeft <= 7 { return urgencyWarning }
        return urgencyCalm
    }
}

enum FinnMotion {
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.82)
    static let sheet = Animation.spring(response: 0.36, dampingFraction: 0.84)
    static let quick = Animation.easeInOut(duration: 0.15)
    static let colorShift = Animation.easeInOut(duration: 0.40)
}

struct AppBackground: View {
    var body: some View {
        FinnTheme.background
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
                .foregroundStyle(FinnTheme.tertiaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FinnTheme.tertiaryText)
            }
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(FinnTheme.divider)
            .frame(height: 1)
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(FinnTheme.background.opacity(isEnabled ? 1 : 0.62))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(FinnTheme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.36))
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(FinnMotion.press, value: configuration.isPressed)
            .animation(FinnMotion.quick, value: isEnabled)
    }
}

struct GhostButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(FinnTheme.accent.opacity(isEnabled ? 1 : 0.42))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(FinnTheme.accent.opacity(isEnabled ? 1 : 0.32), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(FinnMotion.press, value: configuration.isPressed)
            .animation(FinnMotion.quick, value: isEnabled)
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
        guard let days = daysUntilEnd else { return FinnTheme.tertiaryText }
        return FinnTheme.urgencyColor(daysLeft: days)
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
                    .foregroundStyle(FinnTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(FinnTheme.secondaryText)
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
                .fill(FinnTheme.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FinnTheme.divider, lineWidth: 1)
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
                    .fill(FinnTheme.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FinnTheme.glassBorder, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [FinnTheme.glassHighlight.opacity(0.4), .clear],
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
            .animation(FinnMotion.press, value: configuration.isPressed)
    }
}

struct StagedAppearModifier: ViewModifier {
    let index: Int
    let offset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : offset)
            .onAppear {
                guard !visible else { return }
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(FinnMotion.standard.delay(Double(index) * 0.06)) {
                        visible = true
                    }
                }
            }
    }
}

struct BreathingModifier: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(phase)
            .onAppear {
                guard active, !reduceMotion else {
                    phase = 1.0
                    return
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = 1.03
                }
            }
            .onChange(of: active) { _, isActive in
                guard isActive, !reduceMotion else {
                    withAnimation(FinnMotion.quick) { phase = 1.0 }
                    return
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = 1.03
                }
            }
    }
}

extension View {
    func stagedAppear(_ index: Int, offset: CGFloat = 18) -> some View {
        modifier(StagedAppearModifier(index: index, offset: offset))
    }

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
            FinnTheme.accent,
            FinnTheme.urgencyWarning,
            FinnTheme.urgencyCritical,
            FinnTheme.urgencyCalm,
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
                .foregroundStyle(FinnTheme.primaryText)
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
