import BackgroundTasks
import EmailEngine
import Foundation
import SwiftData

/// Registers + schedules the BGAppRefreshTask that runs ScanCoordinator in the background.
/// The task identifier must match the BGTaskSchedulerPermittedIdentifiers entry in Info.plist.
public enum ScanScheduler {
    public static let taskIdentifier = "com.subly.scan.refresh"

    /// Call once during app launch, before application(_:didFinishLaunching...).
    public static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: refreshTask, modelContainer: modelContainer)
        }
    }

    /// Schedule the next background refresh. Safe to call after every foreground scan.
    public static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask, modelContainer: ModelContainer) {
        scheduleNext()

        let coordinator = ScanCoordinator(modelContainer: modelContainer)
        let workItem = Task { @Sendable in
            guard EmailEngine.shared.isSignedIn else {
                task.setTaskCompleted(success: false)
                return
            }
            let summary = await coordinator.runScan(maxPagesPerWindow: 2)
            task.setTaskCompleted(success: summary.errorMessage == nil)
        }

        task.expirationHandler = {
            workItem.cancel()
        }
    }
}
