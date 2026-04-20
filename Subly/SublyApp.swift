import EmailEngine
import LogoService
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import TrialEngine

@main
struct SublyApp: App {
    private static let modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                Subscription.self,
                TrialAlert.self,
                EmailScanState.self,
            ])
            let configuration = ModelConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        EmailEngine.shared.configure(
            clientID: "332703006085-tb86ofvs1h5mjiftsp182h779b813tll.apps.googleusercontent.com"
        )
        ScanScheduler.register(modelContainer: Self.modelContainer)
        ScanScheduler.scheduleNext()
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionStoreEnvironment()
                .modelContainer(Self.modelContainer)
                .onOpenURL { url in
                    EmailEngine.shared.handle(url)
                }
        }
    }
}

private struct SubscriptionStoreEnvironment: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .environment(SubscriptionStore(modelContext: modelContext))
    }
}
