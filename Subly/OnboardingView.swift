import EmailEngine
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
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var revealedFindings: [ScanFinding] = []
    @State private var displayedSavings: Decimal = 0
    @State private var scanningMessage = "Preparing your private scan"
    @State private var scanComplete = false
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
        case connect
        case scanning
        case notifications

        var title: String {
            switch self {
            case .portal: return "Intro"
            case .privacy: return "Privacy"
            case .proof: return "Proof"
            case .connect: return "Connect"
            case .scanning: return "Scan"
            case .notifications: return "Alerts"
            }
        }
    }

    private struct ScanFinding: Identifiable {
        let id = UUID()
        let serviceName: String
        let domain: String
        let amount: Decimal
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
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(SublyTheme.primaryText)
                Text("Free-trial clarity, before the charge.")
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(SublyTheme.tertiaryText)
                Spacer()
                Text(step.title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
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
        case .connect:
            connectStep
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .scanning:
            scanningStep
                .transition(.opacity.combined(with: .opacity))
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
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2.4)
                                .foregroundStyle(SublyTheme.secondaryText)
                            Text("subly")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(SublyTheme.primaryText)
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
                TerminalSectionLabel(title: "Before it charges")
                Text("A calmer way to stay ahead of free trials.")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(SublyTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Subly turns your inbox into a clean signal. The next renewal appears first. The savings feel real. The noise falls away.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(SublyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalSectionLabel(title: "Privacy moat")

            Text("No bank linking. No card sync. No false sense of control.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Subly only reads trial-related confirmations in Gmail so it can warn you before a free trial rolls into a paid charge.")
                .font(.system(size: 16))
                .foregroundStyle(SublyTheme.secondaryText)

            VStack(spacing: 14) {
                PremiumGlassPanel(tint: portalAccent.opacity(0.08)) {
                    HStack(alignment: .top, spacing: 14) {
                        StatOrb(icon: "envelope.open", tint: portalAccent)

                        VStack(alignment: .leading, spacing: 10) {
                            TerminalSectionLabel(title: "What we use")
                            FeatureLine(icon: "checkmark.circle.fill", text: "Read-only Gmail access")
                            FeatureLine(icon: "checkmark.circle.fill", text: "Trial-related renewal language")
                            FeatureLine(icon: "checkmark.circle.fill", text: "Local reminders tied to trial end dates")
                        }
                    }
                }

                PremiumGlassPanel(tint: Color.white.opacity(0.12)) {
                    HStack(alignment: .top, spacing: 14) {
                        StatOrb(icon: "shield.slash", tint: SublyTheme.critical)

                        VStack(alignment: .leading, spacing: 10) {
                            TerminalSectionLabel(title: "What we never use")
                            FeatureLine(icon: "xmark.circle.fill", text: "Bank accounts or Plaid")
                            FeatureLine(icon: "xmark.circle.fill", text: "Card numbers")
                            FeatureLine(icon: "xmark.circle.fill", text: "A giant financial dashboard")
                        }
                    }
                }
            }
        }
    }

    private var proofStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalSectionLabel(title: "What it feels like")

            Text("A shortlist with taste, not another cluttered money app.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("The next renewal gets the spotlight. Everything else stays visible, but quiet.")
                .font(.system(size: 16))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.10), padding: 16) {
                VStack(spacing: 12) {
                    ForEach(Array(demoFindings.prefix(3).enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 14) {
                            ServiceIcon(name: item.serviceName, domain: item.domain, size: index == 0 ? 48 : 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.serviceName)
                                    .font(.system(size: index == 0 ? 18 : 16, weight: .semibold))
                                    .foregroundStyle(SublyTheme.primaryText)
                                Text(index == 0 ? "Next renewal" : "Quietly waiting in queue")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }

                            Spacer()

                            Text(formatUSD(item.amount))
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(index == 0 ? SublyTheme.ink : SublyTheme.primaryText)
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

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalSectionLabel(title: "The handoff")

            Text("Connect Gmail, then watch Subly turn signal into savings.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("You’ll see the scan happen, trials appear, and the at-risk total stack up in front of you.")
                .font(.system(size: 16))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.12), padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatOrb(icon: "wand.and.stars", tint: portalAccent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("The magic starts after connect.")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(SublyTheme.primaryText)
                            Text("Read-only Gmail access. No bank credentials. No extra setup.")
                                .font(.system(size: 14))
                                .foregroundStyle(SublyTheme.secondaryText)
                        }
                    }

                    HStack(spacing: 10) {
                        ForEach(previewBrands, id: \.name) { brand in
                            ServiceIcon(name: brand.name, domain: brand.domain, size: 34)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SublyTheme.critical)
                    }
                }
            }
        }
    }

    private var scanningStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalSectionLabel(title: "Scanning")

            Text(scanningMessage)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is where Subly starts paying for itself: the trials appear, and the amount you can save becomes concrete.")
                .font(.system(size: 16))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.12), padding: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            TerminalSectionLabel(title: "Potential savings")
                            Text(formatUSD(displayedSavings))
                                .font(.system(size: 46, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(SublyTheme.ink)
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(portalAccent.opacity(0.12))
                                .frame(width: 42, height: 42)
                            ProgressView()
                                .tint(portalAccent)
                                .opacity(scanComplete ? 0 : 1)
                            if scanComplete {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(portalAccent)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(revealedFindings) { item in
                            HStack(spacing: 14) {
                                ServiceIcon(name: item.serviceName, domain: item.domain, size: 40)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.serviceName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(SublyTheme.primaryText)
                                    Text("Potential cancel before renewal")
                                        .font(.system(size: 13))
                                        .foregroundStyle(SublyTheme.secondaryText)
                                }

                                Spacer()

                                Text(formatUSD(item.amount))
                                    .font(.system(size: 16, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(SublyTheme.primaryText)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }

            if scanComplete {
                FloatingPill(icon: "bell.badge", text: "Next, turn on alerts so the follow-through is automatic")
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalSectionLabel(title: "Finish setup")

            Text("Turn on notifications so Subly can do the one thing that matters.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Without notifications, Subly can still find your trials. It just can’t reliably stop you from forgetting them. The alert is the product.")
                .font(.system(size: 16))
                .foregroundStyle(SublyTheme.secondaryText)

            PremiumGlassPanel(tint: portalAccent.opacity(0.12), padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatOrb(icon: "bell.badge.fill", tint: portalAccent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What you’ll get")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(SublyTheme.primaryText)
                            Text("Enough warning to act before the charge actually lands.")
                                .font(.system(size: 14))
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
                Button(step == .proof ? "Connect Gmail" : "Continue") {
                    advance()
                }
                .buttonStyle(TerminalButtonStyle(background: SublyTheme.ink, foreground: .white))

                if step == .portal, let onPreviewDemo {
                    Button("Preview app first") {
                        onPreviewDemo()
                    }
                    .buttonStyle(SecondaryTerminalButtonStyle())
                }
            }

        case .connect:
            Button {
                Task { await connectAndBeginScan() }
            } label: {
                HStack {
                    Text(isBusy ? "Connecting..." : "Connect Gmail")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(TerminalButtonStyle(background: portalAccent, foreground: .white))
            .disabled(isBusy)

        case .scanning:
            if scanComplete {
                Button("Continue") {
                    withAnimation(stepAnimation) {
                        step = .notifications
                    }
                }
                .buttonStyle(TerminalButtonStyle(background: SublyTheme.ink, foreground: .white))
            } else {
                EmptyView()
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
                .buttonStyle(TerminalButtonStyle(background: portalAccent, foreground: .white))

                Button("Not now") {
                    onFinish()
                }
                .buttonStyle(SecondaryTerminalButtonStyle())
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
    private func connectAndBeginScan() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        guard let presenter = PresentingHost.rootViewController() else {
            errorMessage = "Could not present sign-in."
            return
        }

        do {
            let account = try await EmailEngine.shared.signInAndAdd(presenting: presenter)
            let record = ConnectedAccount(id: account.userID, email: account.email)
            modelContext.insert(record)
            try? modelContext.save()

            withAnimation(stepAnimation) {
                step = .scanning
            }

            await performMagicScan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func performMagicScan() async {
        scanComplete = false
        revealedFindings = []
        displayedSavings = 0
        scanningMessage = "Preparing your private scan"

        let phaseMessages = [
            "Preparing your private scan",
            "Looking for active trial confirmations",
            "Stacking up what you could save",
        ]

        for message in phaseMessages {
            scanningMessage = message
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 420))
        }

        let coordinator = ScanCoordinator(modelContainer: modelContext.container)
        _ = await coordinator.runScan()

        let findings = realFindings()
        if findings.isEmpty {
            scanningMessage = "No trial confirmations found yet"
        } else {
            scanningMessage = "Finding what’s worth cancelling"
            for item in findings.prefix(4) {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 420))
                withAnimation(stepAnimation) {
                    revealedFindings.append(item)
                    displayedSavings += item.amount
                }
            }
        }

        scanningMessage = revealedFindings.isEmpty
            ? "Ready when your first trial appears"
            : "You’re already ahead of the next charges"

        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.22)) {
            scanComplete = true
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

    private func realFindings() -> [ScanFinding] {
        let descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate<Trial> { !$0.userDismissed && !$0.isLead },
            sortBy: [SortDescriptor(\.trialEndDate, order: .forward)]
        )

        let trials = (try? modelContext.fetch(descriptor)) ?? []

        return trials.compactMap { trial in
            guard let amount = trial.chargeAmount else { return nil }
            return ScanFinding(
                serviceName: trial.serviceName,
                domain: BrandDirectory.logoDomain(for: trial.serviceName, senderDomain: trial.senderDomain) ?? "",
                amount: amount
            )
        }
    }

    private var demoFindings: [ScanFinding] {
        [
            ScanFinding(serviceName: "Figma", domain: "figma.com", amount: 16),
            ScanFinding(serviceName: "Spotify", domain: "spotify.com", amount: 11.99),
            ScanFinding(serviceName: "Notion", domain: "notion.so", amount: 10),
            ScanFinding(serviceName: "MasterClass", domain: "masterclass.com", amount: 15),
        ]
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
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SublyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
