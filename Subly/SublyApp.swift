import EmailEngine
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine
import UserNotifications

@main
struct SublyApp: App {
    private static let modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                Trial.self,
                TrialAlert.self,
                ConnectedAccount.self,
                EmailScanState.self,
            ])
            let configuration = ModelConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // If the existing on-disk store is from the old Subscription schema,
            // wipe it and try again. We have no users yet, so a fresh store is fine.
            wipeStore()
            do {
                let schema = Schema([
                    Trial.self,
                    TrialAlert.self,
                    ConnectedAccount.self,
                    EmailScanState.self,
                ])
                let configuration = ModelConfiguration(schema: schema)
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer after wipe: \(error)")
            }
        }
    }()

    /// Retained for the lifetime of the app — UNUserNotificationCenter holds
    /// a weak reference so the delegate must outlive it.
    private let notificationDelegate: NotificationDelegate
    private let notificationEngine = NotificationEngine()

    init() {
        EmailEngine.shared.configure(
            clientID: "332703006085-tb86ofvs1h5mjiftsp182h779b813tll.apps.googleusercontent.com"
        )

        let delegate = NotificationDelegate(modelContainer: Self.modelContainer)
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

            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                await engine.requestAuthorization()
            }

            let coordinator = TrialAlertCoordinator(
                modelContainer: container,
                notificationEngine: engine
            )
            await coordinator.replanAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            TrialStoreEnvironment(notificationEngine: notificationEngine)
                .modelContainer(Self.modelContainer)
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

private struct TrialStoreEnvironment: View {
    let notificationEngine: NotificationEngine
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView(notificationEngine: notificationEngine)
            .environment(TrialStore(modelContext: modelContext))
    }
}
