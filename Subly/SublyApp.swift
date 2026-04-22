import EmailEngine
import NotificationEngine
import OSLog
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine
import UserNotifications

private let schemaLog = Logger(subsystem: "com.subly.Subly", category: "schema")

@main
struct SublyApp: App {
    private static let modelContainer: ModelContainer = {
        let schema = Schema([
            Trial.self,
            TrialAlert.self,
            ConnectedAccount.self,
            EmailScanState.self,
        ])
        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            schemaLog.error("ModelContainer load failed: \(String(describing: error), privacy: .public)")

            guard isUnrecoverableSchemaError(error) else {
                schemaLog.info("Retrying ModelContainer load without wipe")
                do {
                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    schemaLog.error("Retry also failed: \(String(describing: error), privacy: .public) — falling through to wipe")
                    return wipeAndReload(schema: schema, configuration: configuration)
                }
            }

            schemaLog.notice("Error classified as unrecoverable — wiping on-disk store")
            return wipeAndReload(schema: schema, configuration: configuration)
        }
    }()

    private static func wipeAndReload(schema: Schema, configuration: ModelConfiguration) -> ModelContainer {
        wipeStore()
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer load failed after wipe: \(error)")
        }
    }

    /// True only when the error signals a schema incompatibility that
    /// SwiftData cannot reconcile via lightweight migration. For everything
    /// else — transient filesystem hiccups, permission issues, container
    /// bootstrap problems — we retry instead of wiping the user's data.
    private static func isUnrecoverableSchemaError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let desc = (nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? nsError.localizedDescription).lowercased()
        let keywords = ["incompatible", "schema", "migration", "validation", "hashmodifier", "attribute"]
        return keywords.contains(where: desc.contains)
    }

    /// Retained for the lifetime of the app — UNUserNotificationCenter holds
    /// a weak reference so the delegate must outlive it.
    private let appRouter: AppRouter
    private let notificationDelegate: NotificationDelegate
    private let notificationEngine = NotificationEngine()

    init() {
        let router = AppRouter()
        self.appRouter = router

        EmailEngine.shared.configure(
            clientID: "332703006085-tb86ofvs1h5mjiftsp182h779b813tll.apps.googleusercontent.com"
        )

        let delegate = NotificationDelegate(
            modelContainer: Self.modelContainer,
            appRouter: router
        )
        self.notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate

        let container = Self.modelContainer
        let engine = notificationEngine

        ScanScheduler.register(modelContainer: container, notificationEngine: engine)
        ScanScheduler.scheduleNext()

        Task {
            // Restore the most recent Google sign-in silently so scans can run.
            _ = try? await EmailEngine.shared.restorePreviousSignIn()

            // Reconcile: any SwiftData ConnectedAccount whose userID is not
            // in the Keychain has no refresh token backing it and will fail
            // every scan with .notSignedIn. Drop those ghost rows so the UI
            // nudges the user back to onboarding to reconnect.
            await Self.reconcileConnectedAccounts(container: container)

            let coordinator = TrialAlertCoordinator(
                modelContainer: container,
                notificationEngine: engine
            )
            await coordinator.replanAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(notificationEngine: notificationEngine)
                .modelContainer(Self.modelContainer)
                .environment(appRouter)
                .onOpenURL { url in
                    EmailEngine.shared.handle(url)
                }
        }
    }
}

extension SublyApp {
    /// Drop SwiftData `ConnectedAccount` rows that have no matching Keychain
    /// entry in `EmailEngine.shared.connectedAccounts`. These are ghosts from
    /// a prior Keychain schema version or a manual Keychain wipe — keeping
    /// them makes the UI claim the user is signed in when every scan will
    /// throw `.notSignedIn`.
    @MainActor
    static func reconcileConnectedAccounts(container: ModelContainer) async {
        let keychainIDs = Set(EmailEngine.shared.connectedAccounts.map { $0.userID })
        let context = container.mainContext
        guard let stored = try? context.fetch(FetchDescriptor<ConnectedAccount>()) else { return }
        var removed = 0
        for row in stored where !keychainIDs.contains(row.id) {
            context.delete(row)
            removed += 1
        }
        if removed > 0 {
            try? context.save()
        }
    }
}

/// Wipe the on-disk SwiftData store (default.store + SQLite sidecar files).
/// Used when the schema has changed incompatibly and we want a clean slate.
private func wipeStore() {
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return
    }
    let candidates = [
        appSupport.appendingPathComponent("default.store"),
        appSupport.appendingPathComponent("default.store-shm"),
        appSupport.appendingPathComponent("default.store-wal"),
    ]
    for url in candidates {
        try? FileManager.default.removeItem(at: url)
    }
}

