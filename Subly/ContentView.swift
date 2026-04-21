import Observation
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

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
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(SublyTheme.background).withAlphaComponent(0.92)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(
                notificationEngine: notificationEngine,
                onSeeAllTrials: { selection = .trials }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)

            TrialsView()
                .tabItem { Label("Trials", systemImage: "timer") }
                .tag(Tab.trials)
        }
        .tint(SublyTheme.primaryText)
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

func daysUntil(_ date: Date, from now: Date = Date()) -> Int {
    let calendar = Calendar.current
    let d1 = calendar.startOfDay(for: now)
    let d2 = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: d1, to: d2).day ?? 0
}
