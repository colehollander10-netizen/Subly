import EmailEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionStore.self) private var store
    @Query(sort: \Subscription.detectedAt, order: .reverse) private var subscriptions: [Subscription]

    @State private var isSignedIn = EmailEngine.shared.isSignedIn
    @State private var connectedEmail = EmailEngine.shared.connectedEmail
    @State private var scanState: ScanState = .idle
    @State private var lastSummary: ScanCoordinator.Summary?
    @State private var errorMessage: String?

    private enum ScanState: Equatable {
        case idle, scanning, done
    }

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                if isSignedIn { scanSection }
                if !subscriptions.isEmpty { detectedSection }
            }
            .navigationTitle("Subly")
            .task { await refreshSignInState() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            if isSignedIn {
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectedEmail ?? "Connected")
                        .font(.headline)
                    Text("Gmail connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Sign out", role: .destructive) { signOut() }
            } else {
                Button {
                    Task { await signIn() }
                } label: {
                    Label("Connect Gmail", systemImage: "envelope.badge")
                }
            }
        } header: {
            Text("Account")
        }
    }

    @ViewBuilder
    private var scanSection: some View {
        Section {
            Button {
                Task { await runScan() }
            } label: {
                HStack {
                    if scanState == .scanning {
                        ProgressView()
                        Text("Scanning your inbox…")
                    } else {
                        Label("Scan now", systemImage: "sparkles.magnifyingglass")
                    }
                }
            }
            .disabled(scanState == .scanning)

            if let summary = lastSummary {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last scan: \(summary.subscriptionsAdded) new, \(summary.messagesInspected) emails checked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Scan")
        }
    }

    @ViewBuilder
    private var detectedSection: some View {
        Section {
            ForEach(subscriptions) { sub in
                SubscriptionRow(subscription: sub)
            }
            .onDelete(perform: delete)
        } header: {
            Text("Detected (\(subscriptions.count))")
        } footer: {
            Text("Swipe to remove anything that isn't yours.")
        }
    }

    // MARK: - Actions

    private func refreshSignInState() async {
        isSignedIn = EmailEngine.shared.isSignedIn
        connectedEmail = EmailEngine.shared.connectedEmail
    }

    private func signIn() async {
        errorMessage = nil
        guard let presenter = Self.rootViewController() else {
            errorMessage = "Could not present sign-in."
            return
        }
        do {
            try await EmailEngine.shared.signIn(presenting: presenter)
            await refreshSignInState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() {
        EmailEngine.shared.signOut()
        Task { await refreshSignInState() }
    }

    private func runScan() async {
        errorMessage = nil
        scanState = .scanning
        let container = modelContext.container
        let coordinator = ScanCoordinator(modelContainer: container)
        let summary = await coordinator.runScan()
        lastSummary = summary
        if let err = summary.errorMessage { errorMessage = err }
        scanState = .done
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.delete(subscriptions[index])
        }
        try? store.save()
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.serviceName)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(subscription.status.rawValue.capitalized)
                    if let cycle = subscription.billingCycle, cycle != .unknown {
                        Text("· \(cycle.rawValue)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let amount = subscription.amount {
                Text(format(amount))
                    .font(.body.monospacedDigit())
            }
        }
    }

    private var statusIcon: String {
        switch subscription.status {
        case .active: return "checkmark.seal.fill"
        case .trial: return "clock.badge"
        case .paused: return "pause.circle"
        case .canceled: return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch subscription.status {
        case .active: return .green
        case .trial: return .orange
        case .paused: return .gray
        case .canceled: return .red
        }
    }

    private func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}
