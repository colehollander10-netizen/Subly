import Foundation
import SubscriptionStore
import SwiftData
import UserNotifications

/// Receives notification tap and delivery callbacks and marks the
/// corresponding `TrialAlert` row as delivered.
///
/// Must be stored as a `let` property on `FinnApp` so it isn't
/// deallocated before UNUserNotificationCenter fires callbacks.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer
    private let appRouter: AppRouter

    init(modelContainer: ModelContainer, appRouter: AppRouter) {
        self.modelContainer = modelContainer
        self.appRouter = appRouter
    }

    // Called when a notification fires while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        markDelivered(identifier: notification.request.identifier)
        completionHandler([.banner, .sound])
    }

    // Called when the user taps a delivered notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        markDeliveredAndRoute(identifier: response.notification.request.identifier)
        completionHandler()
    }

    // MARK: - Private

    /// Marks the TrialAlert whose `id.uuidString` matches the notification
    /// request identifier. Runs on the main actor so the SwiftData write
    /// is safe — `modelContainer` itself is Sendable.
    private func markDelivered(identifier: String) {
        guard let alertID = UUID(uuidString: identifier) else { return }
        let container = modelContainer
        Task { @MainActor in
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<TrialAlert>(
                predicate: #Predicate { $0.id == alertID }
            )
            descriptor.fetchLimit = 1
            guard let alert = (try? context.fetch(descriptor))?.first else { return }
            alert.delivered = true
            try? context.save()
        }
    }

    /// Marks delivered and routes the user into the matching entry flow when
    /// the notification was explicitly tapped. Routes by entry type so a
    /// subscription renewal alert opens the Subscriptions tab, and a trial
    /// charge alert opens the Home tab.
    private func markDeliveredAndRoute(identifier: String) {
        guard let alertID = UUID(uuidString: identifier) else { return }
        let container = modelContainer
        let router = appRouter
        Task { @MainActor in
            let context = ModelContext(container)
            var alertDescriptor = FetchDescriptor<TrialAlert>(
                predicate: #Predicate { $0.id == alertID }
            )
            alertDescriptor.fetchLimit = 1
            guard let alert = (try? context.fetch(alertDescriptor))?.first else { return }
            alert.delivered = true
            try? context.save()

            let trialID = alert.trialID
            var trialDescriptor = FetchDescriptor<Trial>(
                predicate: #Predicate { $0.id == trialID }
            )
            trialDescriptor.fetchLimit = 1
            let entry = (try? context.fetch(trialDescriptor))?.first
            let route: PendingNotificationRoute = {
                if entry?.entryType == .subscription {
                    return .subscription(trialID)
                }
                return .trial(trialID)
            }()
            router.pendingRoute = route
            // Keep legacy HomeView flow working by also mirroring the trial
            // id when the route targets a trial. SubscriptionsView will
            // consume the subscription branch directly.
            if case .trial(let id) = route {
                router.pendingCancelTrialID = id
            } else {
                router.pendingCancelTrialID = nil
            }
        }
    }
}
