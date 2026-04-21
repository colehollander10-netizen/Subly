import Foundation
import SubscriptionStore
import SwiftData
import UserNotifications

/// Receives notification tap and delivery callbacks and marks the
/// corresponding `TrialAlert` row as delivered.
///
/// Must be stored as a `let` property on `SublyApp` so it isn't
/// deallocated before UNUserNotificationCenter fires callbacks.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
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
        markDelivered(identifier: response.notification.request.identifier)
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
}
