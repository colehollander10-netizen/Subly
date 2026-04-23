import Foundation
import LogoService
import SubscriptionStore
import SwiftUI

enum SublyTheme {
    static let background = Color(red: 14 / 255, green: 15 / 255, blue: 18 / 255)
    static let backgroundElevated = Color(red: 20 / 255, green: 22 / 255, blue: 26 / 255)
    static let glassFill = Color.white.opacity(0.04)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassHighlight = Color.white.opacity(0.18)
    static let primaryText = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
    static let secondaryText = Color(red: 166 / 255, green: 168 / 255, blue: 181 / 255)
    static let tertiaryText = Color(red: 110 / 255, green: 112 / 255, blue: 128 / 255)
    static let divider = Color.white.opacity(0.08)
    static let accent = Color(red: 184 / 255, green: 164 / 255, blue: 255 / 255)
    static let accentSoft = Color(red: 184 / 255, green: 164 / 255, blue: 255 / 255).opacity(0.14)
    static let urgencyCalm = Color(red: 143 / 255, green: 163 / 255, blue: 190 / 255)
    static let urgencyWarning = Color(red: 245 / 255, green: 179 / 255, blue: 102 / 255)
    static let urgencyCritical = Color(red: 255 / 255, green: 122 / 255, blue: 107 / 255)
    static let urgencyDayOf = Color(red: 255 / 255, green: 90 / 255, blue: 74 / 255)

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

struct TerminalSectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(SublyTheme.tertiaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
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

struct TerminalButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    init(background: Color = SublyTheme.accent, foreground: Color = .white) {
        self.background = background
        self.foreground = foreground
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .shadow(color: background.opacity(0.14), radius: 10, y: 5)
    }
}

struct SecondaryTerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SublyTheme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SublyTheme.backgroundElevated.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SublyTheme.divider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
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
                    .fill(SublyTheme.glassFill)
                    .overlay(Circle().stroke(SublyTheme.divider, lineWidth: 1))
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
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.10)))
            .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
    }
}

struct SurfaceCard<Content: View>: View {
    let padding: CGFloat
    let tint: Color?
    var emphasized: Bool = false
    let content: Content

    init(padding: CGFloat = 18, tint: Color? = nil, emphasized: Bool = false, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.emphasized = emphasized
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint ?? SublyTheme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(emphasized ? 0.9 : 0.7),
                                SublyTheme.divider.opacity(emphasized ? 0.7 : 0.9),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(emphasized ? 0.055 : 0.035), radius: emphasized ? 18 : 12, y: emphasized ? 8 : 5)
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }
}

enum UrgencyLevel {
    case calm, warning, critical
}

struct FlagshipCard<Content: View>: View {
    let padding: CGFloat
    let urgency: UrgencyLevel
    let content: Content

    init(padding: CGFloat = 22, urgency: UrgencyLevel = .calm, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.urgency = urgency
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(SublyTheme.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                SublyTheme.divider.opacity(0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .leading) {
                if urgency == .critical {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [SublyTheme.urgencyCritical.opacity(0.22), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: Color.black.opacity(0.05), radius: 24, y: 10)
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
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
            Color(red: 0.31, green: 0.43, blue: 0.82),
            Color(red: 0.20, green: 0.70, blue: 0.51),
            Color(red: 0.87, green: 0.64, blue: 0.19),
            Color(red: 0.87, green: 0.24, blue: 0.33),
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
                            .padding(size * 0.16)
                            .background(SublyTheme.backgroundElevated)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(SublyTheme.backgroundElevated)
        )
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .stroke(SublyTheme.divider, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: size * 0.12, y: size * 0.06)
    }

    private var fallback: some View {
        ZStack {
            fallbackColor
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
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
            trialEndDate: Calendar.current.date(byAdding: .day, value: daysOut, to: referenceDate) ?? referenceDate,
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
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(SublyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryTerminalButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}
