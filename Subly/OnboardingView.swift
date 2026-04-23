import NotificationEngine
import PhosphorSwift
import SwiftUI
import UIKit
import UserNotifications

struct OnboardingView: View {
    @State private var step: Int = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    let onPreviewDemo: (() -> Void)?
    let onFinish: () -> Void

    init(onPreviewDemo: (() -> Void)? = nil, onFinish: @escaping () -> Void) {
        self.onPreviewDemo = onPreviewDemo
        self.onFinish = onFinish
    }

    var body: some View {
        ScreenFrame {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    screen1.tag(0)
                    screen2.tag(1)
                    screen3.tag(2)
                    screen4.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .task { await refreshNotificationStatus() }
    }

    // MARK: - Screen 1 — Hook

    private var screen1: some View {
        VStack(spacing: 24) {
            Spacer()
            Ph.moonStars.duotone
                .color(SublyTheme.accent.opacity(0.6))
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text("Subly")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(SublyTheme.accent)
                Text("Know before your trials charge you.")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Without linking your bank. Without reading your email.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SublyTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button("Continue") {
                Haptics.play(.rowTap)
                withAnimation { step = 1 }
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 20)
            Spacer(minLength: 60)
        }
    }

    // MARK: - Screen 2 — Differentiator

    private var screen2: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text("No bank. No inbox. No account.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                differentiatorRow(icon: Ph.bank.fill, text: "Never connects to your bank.")
                differentiatorRow(icon: Ph.envelope.fill, text: "Never reads your email.")
                differentiatorRow(icon: Ph.userCircleMinus.fill, text: "No sign-up, no cloud, no server.")
            }
            .padding(.horizontal, 20)

            Text("Everything lives on this device. Always.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SublyTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Button("Continue") {
                Haptics.play(.rowTap)
                withAnimation { step = 2 }
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 20)
            Spacer(minLength: 60)
        }
    }

    @ViewBuilder
    private func differentiatorRow(icon: Image, text: String) -> some View {
        SurfaceCard(padding: 16) {
            HStack(spacing: 14) {
                icon
                    .color(SublyTheme.accent)
                    .frame(width: 24, height: 24)
                    .frame(width: 32, alignment: .leading)
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SublyTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    // MARK: - Screen 3 — Mechanics

    private var screen3: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How you add a trial.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                differentiatorRow(icon: Ph.pencilSimple.bold, text: "Tap + and type it in.")
                differentiatorRow(icon: Ph.clipboardText.fill, text: "Paste a receipt and Subly fills it in.")
            }
            .padding(.horizontal, 20)

            Text("Takes 10 seconds. Alerts fire 3 days before and day-of.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SublyTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()
            Button("Continue") {
                Haptics.play(.rowTap)
                withAnimation { step = 3 }
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 20)
            Spacer(minLength: 60)
        }
    }

    // MARK: - Screen 4 — Permission + start

    private var screen4: some View {
        VStack(spacing: 24) {
            Spacer()
            Ph.bellRinging.duotone
                .color(SublyTheme.accent.opacity(0.6))
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("One last thing.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Subly uses local notifications to warn you before a charge. No push server, no tracking.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SublyTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(notificationPrimaryLabel) {
                    Task { await handleNotificationAction() }
                }
                .buttonStyle(PrimaryButton())

                Button("Maybe later") {
                    Haptics.play(.rowTap)
                    onFinish()
                }
                .buttonStyle(GhostButton())
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 60)
        }
    }

    private var notificationPrimaryLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "Finish setup"
        case .denied: return "Open iPhone Settings"
        case .notDetermined: return "Allow notifications"
        @unknown default: return "Allow notifications"
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    private func handleNotificationAction() async {
        Haptics.play(.primaryTap)
        switch notificationStatus {
        case .notDetermined:
            _ = await NotificationEngine().requestAuthorization()
            await refreshNotificationStatus()
            onFinish()
        case .authorized, .provisional, .ephemeral:
            onFinish()
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                _ = await UIApplication.shared.open(url)
            }
            onFinish()
        @unknown default:
            onFinish()
        }
    }
}
