import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onPreviewDemo: (() -> Void)?
    let onFinish: () -> Void

    @State private var step: Step = .portal
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var hasAnimatedIn = false

    private let previewBrands: [(name: String, domain: String)] = [
        ("Figma", "figma.com"),
        ("Spotify", "spotify.com"),
        ("Notion", "notion.so"),
        ("Headspace", "headspace.com"),
    ]

    private enum Step: Int, CaseIterable {
        case portal
        case privacy
        case proof
        case notifications

        var title: String {
            switch self {
            case .portal: return "Intro"
            case .privacy: return "Privacy"
            case .proof: return "Proof"
            case .notifications: return "Alerts"
            }
        }
    }

    init(onPreviewDemo: (() -> Void)? = nil, onFinish: @escaping () -> Void) {
        self.onPreviewDemo = onPreviewDemo
        self.onFinish = onFinish
    }

    var body: some View {
        ScreenFrame {
            ZStack {
                onboardingAtmosphere

                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    progressStrip

                    ScrollView(showsIndicators: false) {
                        currentStepView
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                    }

                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .task {
                notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                guard !hasAnimatedIn else { return }
                hasAnimatedIn = true
            }
        }
    }

    private var onboardingAtmosphere: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.82, green: 0.96, blue: 0.97).opacity(0.90),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 260
            )
            .offset(x: 80, y: -70)

            RadialGradient(
                colors: [
                    Color(red: 0.56, green: 0.87, blue: 0.85).opacity(0.18),
                    Color.clear,
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 240
            )
            .offset(x: -110, y: 200)

            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(Color.white.opacity(0.34))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -160, y: -250)

            RoundedRectangle(cornerRadius: 200, style: .continuous)
                .fill(Color(red: 0.12, green: 0.66, blue: 0.74).opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 150, y: 220)
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("subly")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(SublyTheme.accent)
                Text("Free-trial clarity, before the charge.")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(SublyTheme.secondaryText)
            }

            Spacer()

            if step != .portal {
                Button("Back") {
                    withAnimation(stepAnimation) {
                        step = Step(rawValue: max(step.rawValue - 1, 0)) ?? .portal
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(SublyTheme.tertiaryText)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
            }
        }
    }

    private var progressStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { value in
                    Capsule()
                        .fill(value.rawValue <= step.rawValue ? portalAccent : SublyTheme.divider.opacity(0.55))
                        .frame(height: 5)
                        .frame(maxWidth: value == step ? .infinity : 30)
                        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: step)
                }
            }

            HStack {
                Text("STEP \(step.rawValue + 1) OF \(Step.allCases.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.tertiaryText)
                Spacer()
                Text(step.title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.8)
                    .foregroundStyle(SublyTheme.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .portal:
            portalStep
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .privacy:
            privacyStep
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .proof:
            proofStep
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .notifications:
            notificationsStep
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var portalStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                PremiumGlassPanel(cornerRadius: 38, tint: portalAccent.opacity(0.15), padding: 0) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        portalAccent.opacity(0.26),
                                        portalAccent.opacity(0.06),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 12,
                                    endRadius: 110
                                )
                            )
                            .frame(width: 240, height: 240)

                        Circle()
                            .stroke(Color.white.opacity(0.82), lineWidth: 1)
                            .frame(width: 220, height: 220)
                        Circle()
                            .stroke(portalAccent.opacity(0.34), lineWidth: 1)
                            .frame(width: 170, height: 170)

                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 126, height: 126)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            )
                            .shadow(color: portalAccent.opacity(0.16), radius: 22, y: 8)

                        VStack(spacing: 6) {
                            Text("PORTAL")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .tracking(1.8)
                                .foregroundStyle(SublyTheme.secondaryText)
                            Text("subly")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(SublyTheme.accent)
                        }

                        ServiceIcon(name: "Figma", domain: "figma.com", size: 44)
                            .offset(x: -92, y: -48)
                        ServiceIcon(name: "Spotify", domain: "spotify.com", size: 42)
                            .offset(x: 92, y: -30)
                        ServiceIcon(name: "Notion", domain: "notion.so", size: 40)
                            .offset(x: -78, y: 72)
                        ServiceIcon(name: "Headspace", domain: "headspace.com", size: 46)
                            .offset(x: 88, y: 72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 330)
                    .overlay(alignment: .topLeading) {
                        FloatingPill(icon: "lock.shield", text: "Private by design")
                            .offset(x: 18, y: 18)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        FloatingPill(icon: "sparkles", text: "Finds trials first")
                            .offset(x: -18, y: -18)
                    }
                }
                .opacity(hasAnimatedIn ? 1 : 0.72)
                .scaleEffect(hasAnimatedIn || reduceMotion ? 1 : 0.96)
                .offset(y: hasAnimatedIn || reduceMotion ? 0 : 10)
                .animation(.easeOut(duration: 0.45), value: hasAnimatedIn)
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "Before it charges")
                Text("A calmer way to stay ahead of free trials.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Subly turns the trials you share into a clean signal. The next renewal appears first. The savings feel real. The noise falls away.")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(SublyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(title: "Privacy moat")

            Text("Nothing leaves your phone. Ever.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Subly never reads your inbox and never talks to a backend. You share a trial receipt — by screenshot or paste — and the parser runs entirely on this device.")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.secondaryText)

            VStack(spacing: 14) {
                PremiumGlassPanel(tint: portalAccent.opacity(0.08)) {
                    HStack(alignment: .top, spacing: 14) {
                        StatOrb(icon: "iphone", tint: portalAccent)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "What we use")
                            FeatureLine(icon: "checkmark.circle.fill", text: "Whatever you choose to share with the app")
                            FeatureLine(icon: "checkmark.circle.fill", text: "On-device parsing — no network round-trip")
                            FeatureLine(icon: "checkmark.circle.fill", text: "Local reminders tied to trial end dates")
                        }
                    }
                }

                PremiumGlassPanel(tint: Color.white.opacity(0.12)) {
                    HStack(alignment: .top, spacing: 14) {
                        StatOrb(icon: "shield.slash", tint: SublyTheme.urgencyCritical)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "What we never use")
                            FeatureLine(icon: "xmark.circle.fill", text: "Email accounts or OAuth")
                            FeatureLine(icon: "xmark.circle.fill", text: "Bank accounts or card numbers")
                            FeatureLine(icon: "xmark.circle.fill", text: "Any backend server")
                        }
                    }
                }
            }
        }
    }

    private struct ProofPreview: Identifiable {
        let id = UUID()
        let serviceName: String
        let domain: String
        let amount: Decimal
    }

    private var proofPreviews: [ProofPreview] {
        [
            ProofPreview(serviceName: "Figma", domain: "figma.com", amount: 16),
            ProofPreview(serviceName: "Spotify", domain: "spotify.com", amount: 11.99),
            ProofPreview(serviceName: "Notion", domain: "notion.so", amount: 10),
        ]
    }

    private var proofStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(title: "What it feels like")

            Text("A shortlist with taste, not another cluttered money app.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("The next renewal gets the spotlight. Everything else stays visible, but quiet.")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.10), padding: 16) {
                VStack(spacing: 12) {
                    ForEach(Array(proofPreviews.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 14) {
                            ServiceIcon(name: item.serviceName, domain: item.domain, size: index == 0 ? 48 : 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.serviceName)
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .foregroundStyle(SublyTheme.primaryText)
                                Text(index == 0 ? "Next renewal" : "Quietly waiting in queue")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }

                            Spacer()

                            Text(formatUSD(item.amount))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(SublyTheme.primaryText)
                        }
                        .padding(.vertical, index == 0 ? 4 : 0)

                        if index < 2 {
                            HairlineDivider()
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                FloatingPill(icon: "hand.tap", text: "Swipe to cancel")
                FloatingPill(icon: "sparkle.magnifyingglass", text: "Manual add stays easy")
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(title: "Finish setup")

            Text("Turn on notifications so Subly can do the one thing that matters.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Without notifications, Subly can still find your trials. It just can’t reliably stop you from forgetting them. The alert is the product.")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.12), padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatOrb(icon: "bell.badge.fill", tint: portalAccent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What you’ll get")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundStyle(SublyTheme.primaryText)
                            Text("Enough warning to act before the charge actually lands.")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(SublyTheme.secondaryText)
                        }
                    }

                    FeatureLine(icon: "calendar.badge.clock", text: "A 3-day heads up before renewal")
                    FeatureLine(icon: "clock.badge", text: "A day-of warning when the deadline is here")
                    FeatureLine(icon: "arrow.triangle.2.circlepath", text: "A follow-up reminder after you snooze or put it off")
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .portal, .privacy, .proof:
            VStack(alignment: .leading, spacing: 12) {
                Button("Continue") {
                    advance()
                }
                .buttonStyle(PrimaryButton())

                if step == .portal, let onPreviewDemo {
                    Button("Preview app first") {
                        onPreviewDemo()
                    }
                    .buttonStyle(GhostButton())
                }
            }

        case .notifications:
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    Task { await requestNotificationsAndFinish() }
                } label: {
                    HStack {
                        Text(notificationStatus == .authorized ? "Open Subly" : "Turn on notifications")
                        Spacer()
                        Image(systemName: "bell")
                    }
                }
                .buttonStyle(PrimaryButton())

                Button("Not now") {
                    onFinish()
                }
                .buttonStyle(GhostButton())
            }
        }
    }

    private var portalAccent: Color {
        Color(red: 0.10, green: 0.63, blue: 0.67)
    }

    private var stepAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.46, dampingFraction: 0.9)
    }

    private func advance() {
        withAnimation(stepAnimation) {
            step = Step(rawValue: min(step.rawValue + 1, Step.allCases.count - 1)) ?? step
        }
    }

    @MainActor
    private func requestNotificationsAndFinish() async {
        let center = UNUserNotificationCenter.current()
        let settingsBeforePrompt = await center.notificationSettings()

        let granted: Bool
        if settingsBeforePrompt.authorizationStatus == .notDetermined {
            granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        } else {
            granted = settingsBeforePrompt.authorizationStatus == .authorized
        }

        let settingsAfterPrompt = await center.notificationSettings()
        notificationStatus = settingsAfterPrompt.authorizationStatus

        if granted || settingsAfterPrompt.authorizationStatus == .authorized {
            let coordinator = TrialAlertCoordinator(
                modelContainer: modelContext.container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()
        }

        onFinish()
    }

}

private struct PremiumGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color
    let padding: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = 30,
        tint: Color = .white,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .padding(padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.001))
                    .glassEffect(.regular.tint(tint).interactive(false), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.44), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 20, y: 8)
            } else {
                content
                    .padding(padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 20, y: 8)
            }
        }
    }
}

private struct FloatingPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(0.8)
        }
        .foregroundStyle(SublyTheme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

private struct StatOrb: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

private struct FeatureLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SublyTheme.primaryText)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
