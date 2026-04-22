import Foundation
import LogoService
import SubscriptionStore
import SwiftUI

enum SublyTheme {
    static let background = Color(red: 0.94, green: 0.93, blue: 0.90)
    static let backgroundTint = Color(red: 0.91, green: 0.93, blue: 0.89)
    static let surface = Color(red: 0.99, green: 0.98, blue: 0.97)
    static let elevated = Color.white
    static let primaryText = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let secondaryText = Color(red: 0.35, green: 0.37, blue: 0.39)
    static let tertiaryText = Color(red: 0.52, green: 0.54, blue: 0.57)
    static let divider = Color(red: 0.83, green: 0.82, blue: 0.79)
    static let accent = Color(red: 0.27, green: 0.47, blue: 0.37)
    static let accentSoft = Color(red: 0.90, green: 0.94, blue: 0.91)
    static let highlight = Color(red: 0.63, green: 0.51, blue: 0.26)
    static let highlightSoft = Color(red: 0.95, green: 0.92, blue: 0.85)
    static let warning = Color(red: 0.72, green: 0.49, blue: 0.14)
    static let warningSoft = Color(red: 0.96, green: 0.92, blue: 0.84)
    static let critical = Color(red: 0.60, green: 0.29, blue: 0.24)
    static let criticalSoft = Color(red: 0.95, green: 0.89, blue: 0.86)
    static let dayOf = Color(red: 0.48, green: 0.17, blue: 0.14)
    static let dayOfSoft = Color(red: 0.94, green: 0.85, blue: 0.82)
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.14)

    static func urgencyColor(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return dayOf }
        if daysLeft <= 3 { return critical }
        if daysLeft <= 7 { return warning }
        return accent
    }

    static func urgencySurface(daysLeft: Int) -> Color {
        if daysLeft <= 0 { return dayOfSoft }
        if daysLeft <= 3 { return criticalSoft }
        if daysLeft <= 7 { return warningSoft }
        return accentSoft
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            SublyTheme.background

            LinearGradient(
                colors: [
                    Color.white.opacity(0.75),
                    SublyTheme.background,
                    SublyTheme.backgroundTint.opacity(0.75),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(SublyTheme.highlight.opacity(0.07))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 140, y: -210)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(SublyTheme.accent.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -170, y: 420)

            RoundedRectangle(cornerRadius: 150, style: .continuous)
                .fill(Color.white.opacity(0.45))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -140, y: -160)
        }
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

struct QuietActionLink: View {
    let title: String
    var systemImage: String?
    var accent: Color = SublyTheme.primaryText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }
}

struct TerminalButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    init(background: Color = SublyTheme.primaryText, foreground: Color = .white) {
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
                    .fill(SublyTheme.elevated.opacity(configuration.isPressed ? 0.82 : 1))
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
                    .fill(SublyTheme.surface)
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
                    .fill(tint ?? SublyTheme.surface)
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
                    .fill(SublyTheme.elevated)
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
                                colors: [SublyTheme.critical.opacity(0.22), .clear],
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
                            .background(SublyTheme.elevated)
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
                .fill(SublyTheme.elevated)
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
            demoTrial("Figma", domain: "figma.com", daysOut: 2, amount: 16, manual: false, length: 14, from: referenceDate),
            demoTrial("Spotify", domain: "spotify.com", daysOut: 5, amount: 11.99, manual: false, length: 30, from: referenceDate),
            demoTrial("Notion", domain: "notion.so", daysOut: 9, amount: 10, manual: true, length: 14, from: referenceDate),
            demoTrial("MasterClass", domain: "masterclass.com", daysOut: 13, amount: 15, manual: false, length: 30, from: referenceDate),
        ]
    }

    static func leads(referenceDate: Date = Date()) -> [Trial] {
        [
            demoLead("Perplexity Pro", domain: "perplexity.ai", daysOut: 7, from: referenceDate),
            demoLead("Headspace", domain: "headspace.com", daysOut: 11, from: referenceDate),
        ]
    }

    private static func demoTrial(
        _ serviceName: String,
        domain: String,
        daysOut: Int,
        amount: Decimal,
        manual: Bool,
        length: Int? = nil,
        from referenceDate: Date
    ) -> Trial {
        Trial(
            accountID: "demo",
            serviceName: serviceName,
            senderDomain: domain,
            trialEndDate: Calendar.current.date(byAdding: .day, value: daysOut, to: referenceDate) ?? referenceDate,
            chargeAmount: amount,
            detectedAt: referenceDate,
            sourceEmailID: manual ? nil : "demo-\(serviceName)",
            isManual: manual,
            trialLengthDays: length
        )
    }

    private static func demoLead(
        _ serviceName: String,
        domain: String,
        daysOut: Int,
        from referenceDate: Date
    ) -> Trial {
        Trial(
            accountID: "demo",
            serviceName: serviceName,
            senderDomain: domain,
            trialEndDate: Calendar.current.date(byAdding: .day, value: daysOut, to: referenceDate) ?? referenceDate,
            chargeAmount: nil,
            detectedAt: referenceDate,
            sourceEmailID: "demo-lead-\(serviceName)",
            isLead: true
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
