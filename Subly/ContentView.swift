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
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]
    @State private var showingDemoPreview = false
    @State private var onboardingComplete = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(
                    onPreviewDemo: {
                        showingDemoPreview = true
                    },
                    onFinish: {
                        onboardingComplete = true
                    }
                )
            } else {
                RootTabView(notificationEngine: notificationEngine)
            }
        }
        .onAppear {
            if !accounts.isEmpty {
                onboardingComplete = true
            }
        }
        .onChange(of: accounts.count) { _, newValue in
            if newValue > 0 {
                onboardingComplete = true
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        accounts.isEmpty && !showingDemoPreview && !onboardingComplete
    }
}

private struct RootTabView: View {
    enum Tab {
        case home
        case trials
    }

    @Environment(AppRouter.self) private var appRouter
    let notificationEngine: NotificationEngine
    @State private var selection: Tab = .home

    init(notificationEngine: NotificationEngine) {
        self.notificationEngine = notificationEngine
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(SublyTheme.surface)
        appearance.shadowColor = UIColor(SublyTheme.divider).withAlphaComponent(0.6)

        let inactive = UIColor(SublyTheme.tertiaryText)
        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactive]

        let active = UIColor(SublyTheme.ink)
        appearance.stackedLayoutAppearance.selected.iconColor = active
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: active]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(notificationEngine: notificationEngine)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            TrialsView()
                .tabItem { Label("Trials", systemImage: "bell.badge") }
                .tag(Tab.trials)
        }
        .tint(SublyTheme.ink)
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
