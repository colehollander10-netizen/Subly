import Foundation
import UserNotifications

/// One notification the engine should schedule. The app layer builds these
/// from persisted `TrialAlert` rows — `NotificationEngine` stays decoupled
/// from SwiftData so it can be unit-tested without a ModelContainer.
public struct ScheduledAlert: Sendable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let triggerDate: Date

    public init(id: String, title: String, body: String, triggerDate: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.triggerDate = triggerDate
    }
}

public protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

public actor NotificationEngine {
    private let center: NotificationCenterProtocol

    public init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Requests permission. Returns true on grant. App should call this
    /// once at onboarding after the user opts in to notifications.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces all pending trial notifications with the given set.
    ///
    /// Idempotent: safe to call on every app launch and whenever trial data
    /// changes. Uses `ScheduledAlert.id` as the notification request identifier,
    /// so callers must supply stable IDs (typically the `TrialAlert.id.uuidString`).
    ///
    /// Alerts with `triggerDate` in the past are skipped silently — upstream
    /// filtering in `TrialEngine.plan` normally prevents this, but we re-check
    /// here in case stored alerts have aged past their trigger between runs.
    public func scheduleAll(_ alerts: [ScheduledAlert], now: Date = Date()) async {
        center.removeAllPendingNotificationRequests()

        for alert in alerts where alert.triggerDate > now {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: alert.triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
