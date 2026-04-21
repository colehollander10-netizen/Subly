import EmailEngine
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

/// Root view. Gates on onboarding (must connect at least one Gmail account)
/// then shows the three-tab liquid-glass shell: Home / Trials / Settings.
struct ContentView: View {
    let notificationEngine: NotificationEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]

    var body: some View {
        Group {
            if accounts.isEmpty {
                OnboardingView()
            } else {
                RootTabView(notificationEngine: notificationEngine)
            }
        }
    }
}

// MARK: - Tab shell

private struct RootTabView: View {
    let notificationEngine: NotificationEngine

    var body: some View {
        TabView {
            HomeView(notificationEngine: notificationEngine)
                .tabItem { Label("Home", systemImage: "house.fill") }

            TrialsView()
                .tabItem { Label("Trials", systemImage: "timer") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.white)
    }
}

// MARK: - Helpers used across tabs

/// UIKit root view controller lookup for Google Sign-In presentation.
enum PresentingHost {
    static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}

/// Used by Home and Trials for price formatting. Pure function so tests can
/// verify output without a SwiftUI environment.
func formatUSD(_ value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
}

func daysUntil(_ date: Date, from now: Date = Date()) -> Int {
    let cal = Calendar.current
    let d1 = cal.startOfDay(for: now)
    let d2 = cal.startOfDay(for: date)
    return cal.dateComponents([.day], from: d1, to: d2).day ?? 0
}
