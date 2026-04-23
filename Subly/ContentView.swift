import Observation
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

enum AppPreferences {
    static let showDemoData = "showDemoData"
}

@MainActor
@Observable
final class AppRouter {
    var pendingCancelTrialID: UUID?
}

struct ContentView: View {
    let notificationEngine: NotificationEngine
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query private var existingTrials: [Trial]
    @State private var showingDemoPreview = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(
                    onPreviewDemo: {
                        showingDemoPreview = true
                    },
                    onFinish: {
                        hasCompletedOnboarding = true
                    }
                )
            } else {
                RootTabView(notificationEngine: notificationEngine)
            }
        }
        .onAppear {
            // One-time migration: anyone who already has real trial data
            // (from the prior Gmail build, or who added trials before
            // tapping "Open Subly" in onboarding) shouldn't be re-onboarded.
            if !hasCompletedOnboarding && !existingTrials.isEmpty {
                hasCompletedOnboarding = true
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding && !showingDemoPreview
    }
}

private struct RootTabView: View {
    enum Tab {
        case home
        case trials
        case settings
    }

    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine
    @State private var selection: Tab = .home

    init(notificationEngine: NotificationEngine) {
        self.notificationEngine = notificationEngine
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(SublyTheme.background).withAlphaComponent(0.72)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.shadowColor = UIColor(SublyTheme.divider).withAlphaComponent(0.8)

        let inactive = UIColor(SublyTheme.tertiaryText)
        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactive]

        let active = UIColor(SublyTheme.accent)
        appearance.stackedLayoutAppearance.selected.iconColor = active
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: active]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(notificationEngine: notificationEngine)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            TrialsView()
                .tabItem { Label("Trials", systemImage: "list.bullet.rectangle.fill") }
                .tag(Tab.trials)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(SublyTheme.accent)
        .onChange(of: selection) { _, _ in
            Haptics.play(.tabSwitch)
        }
        .onChange(of: appRouter.pendingCancelTrialID) { _, newValue in
            if newValue != nil {
                selection = .home
            }
        }
    }
}

enum PresentingHost {
    static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}

func formatUSD(_ value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
}

func trialLengthDescription(for trial: Trial) -> String? {
    guard let days = trial.trialLengthDays else { return nil }
    if days >= 350 { return "1-year trial" }
    if days >= 80 && days <= 100 { return "3-month trial" }
    if days >= 55 && days <= 65 { return "2-month trial" }
    if days >= 28 && days <= 32 { return "1-month trial" }
    return "\(days)-day trial"
}

func daysUntil(_ date: Date, from now: Date = Date()) -> Int {
    let calendar = Calendar.current
    let d1 = calendar.startOfDay(for: now)
    let d2 = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: d1, to: d2).day ?? 0
}
