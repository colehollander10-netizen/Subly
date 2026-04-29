import Observation
import NotificationEngine
import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

enum AppPreferences {
    static let showDemoData = "showDemoData"
}

/// Typed route used when a notification is tapped. Keeps tab + detail-sheet
/// selection in sync with the entry type the user was alerted about.
enum PendingNotificationRoute: Equatable {
    case trial(UUID)
    case subscription(UUID)

    var entryID: UUID {
        switch self {
        case .trial(let id), .subscription(let id):
            return id
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    /// Legacy compat — mirrored from `pendingRoute` when the route targets a
    /// trial so existing HomeView code keeps working. New callers should
    /// observe `pendingRoute`.
    var pendingCancelTrialID: UUID?
    var pendingRoute: PendingNotificationRoute?
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
            // tapping "Open Finn" in onboarding) shouldn't be re-onboarded.
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
        case subscriptions
        case settings
    }

    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine
    @State private var selection: Tab = .home

    init(notificationEngine: NotificationEngine) {
        self.notificationEngine = notificationEngine
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(FinnTheme.background).withAlphaComponent(0.72)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.shadowColor = UIColor(FinnTheme.divider).withAlphaComponent(0.8)

        let inactive = UIColor(FinnTheme.tertiaryText)
        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactive]

        let active = UIColor(FinnTheme.accent)
        appearance.stackedLayoutAppearance.selected.iconColor = active
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: active]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        // SwiftUI tabItem icons must be SF Symbols — custom views render at intrinsic size and blow out the tab bar.
        // Falling back to SF Symbols for tab chrome only (FinnTheme.accent tint preserves the lavender brand).
        TabView(selection: $selection) {
            HomeView(notificationEngine: notificationEngine)
                .tabItem {
                    Label("Home", systemImage: selection == .home ? "house.fill" : "house")
                }
                .tag(Tab.home)

            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: selection == .subscriptions ? "repeat.circle.fill" : "repeat")
                }
                .tag(Tab.subscriptions)

            TrialsView(notificationEngine: notificationEngine)
                .tabItem {
                    Label("Trials", systemImage: selection == .trials ? "clock.fill" : "clock")
                }
                .tag(Tab.trials)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: selection == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(FinnTheme.accent)
        .onChange(of: selection) { _, _ in
            Haptics.play(.tabSwitch)
        }
        .onChange(of: appRouter.pendingRoute) { _, newRoute in
            // Switch to the tab that owns the entry type so the sheet lands
            // in the right place. HomeView + SubscriptionsView each watch
            // `pendingRoute` and present their own detail sheet.
            switch newRoute {
            case .trial:
                selection = .home
            case .subscription:
                selection = .subscriptions
            case .none:
                break
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

func trialCountdownBadgeText(days: Int, includeLeft: Bool = false) -> String {
    if days < 0 { return "PAST DUE" }
    if days == 0 { return "TODAY" }
    return includeLeft ? "\(days)D LEFT" : "\(days)D"
}
