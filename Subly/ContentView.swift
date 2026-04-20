import EmailEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionStore.self) private var store
    @Query(
        filter: #Predicate<Subscription> { !$0.userDismissed },
        sort: \Subscription.detectedAt,
        order: .reverse
    ) private var allSubscriptions: [Subscription]

    private var activeSubscriptions: [Subscription] {
        allSubscriptions.filter { $0.status != .canceled }
    }

    /// High-confidence OR user-confirmed rows. These are shown in "Detected".
    private var detectedSubscriptions: [Subscription] {
        activeSubscriptions.filter { sub in
            if sub.userConfirmed == true { return true }
            if sub.userConfirmed == false { return false }
            return sub.confidence >= 0.7
        }
    }

    /// Medium-confidence rows awaiting user verdict.
    private var reviewSubscriptions: [Subscription] {
        activeSubscriptions.filter { sub in
            sub.userConfirmed == nil && sub.confidence >= 0.4 && sub.confidence < 0.7
        }
    }

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
                if !detectedSubscriptions.isEmpty { detectedSection }
                if !reviewSubscriptions.isEmpty { reviewSection }
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
                    Text("Last scan: \(summary.subscriptionsAdded) new, \(summary.subscriptionsUpdated) updated, \(summary.messagesInspected) emails checked")
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
            ForEach(detectedSubscriptions) { sub in
                SubscriptionRow(subscription: sub)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            dismiss(sub)
                        } label: {
                            Label("Not a subscription", systemImage: "xmark.bin")
                        }
                    }
            }
        } header: {
            Text("Detected (\(detectedSubscriptions.count))")
        } footer: {
            Text("Swipe any row that isn't a real subscription to remove it.")
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        Section {
            ForEach(reviewSubscriptions) { sub in
                ReviewRow(
                    subscription: sub,
                    onConfirm: { confirm(sub) },
                    onReject: { dismiss(sub) }
                )
            }
        } header: {
            Text("Review these (\(reviewSubscriptions.count))")
        } footer: {
            Text("These look like they might be subscriptions. Tap ✓ to keep or ✗ to remove.")
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

    private func dismiss(_ subscription: Subscription) {
        subscription.userDismissed = true
        subscription.userConfirmed = false
        try? store.save()
    }

    private func confirm(_ subscription: Subscription) {
        subscription.userConfirmed = true
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
                HStack(spacing: 6) {
                    Text(subscription.serviceName)
                        .font(.body)
                    if !subscription.accountIdentifier.isEmpty {
                        Text(accountLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(statusLabel)
                    if let introEnd = subscription.introPriceEndDate,
                       subscription.regularAmount != nil {
                        Text("· intro until \(introEnd.formatted(.dateTime.month().day()))")
                            .foregroundStyle(.orange)
                    } else if let trialEnd = subscription.trialEndDate,
                              subscription.status == .trial {
                        Text("· ends \(trialEnd.formatted(.dateTime.month().day()))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let chargeWarning {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(chargeWarning)
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }
            Spacer()
            priceBadge
        }
    }

    /// "Will charge $4.99 on Oct 19" — only when this is a card-on-file trial
    /// with a known charge date. Silent when the trial is no-card or we don't
    /// know the date, so the user only sees the warning when it's actionable.
    private var chargeWarning: String? {
        guard subscription.status == .trial,
              subscription.willAutoCharge,
              let chargeDate = subscription.trialEndDate
        else { return nil }
        let amountText = subscription.regularAmount.map(formatPrice)
            ?? subscription.amount.map(formatPrice)
        let dateText = chargeDate.formatted(.dateTime.month(.abbreviated).day())
        if let amountText {
            return "Will charge \(amountText) on \(dateText)"
        }
        return "Will charge on \(dateText)"
    }

    @ViewBuilder
    private var priceBadge: some View {
        if shouldShowPrice, let amount = subscription.amount {
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatPrice(amount))
                    .font(.body.monospacedDigit())
                if let regular = subscription.regularAmount, regular != amount {
                    Text("then \(formatPrice(regular))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var shouldShowPrice: Bool {
        // Only show price for currently-active / trial rows with a real amount.
        switch subscription.status {
        case .active, .trial:
            return subscription.amount != nil
        case .paused, .canceled:
            return false
        }
    }

    private var statusLabel: String {
        switch subscription.status {
        case .active: return "Active"
        case .trial: return "Trial"
        case .paused: return "Paused"
        case .canceled: return "Canceled"
        }
    }

    private var accountLabel: String {
        let id = subscription.accountIdentifier
        if id.contains("@") { return id }
        if id.count == 4, Int(id) != nil { return "•••• \(id)" }
        return "@\(id)"
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

    private func formatPrice(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let base = formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
        switch subscription.billingCycle ?? .unknown {
        case .monthly: return "\(base)/mo"
        case .annual: return "\(base)/yr"
        case .unknown: return base
        }
    }
}

private struct ReviewRow: View {
    let subscription: Subscription
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.serviceName)
                    .font(.body)
                HStack(spacing: 6) {
                    if let amount = subscription.amount {
                        Text(formatPrice(amount))
                            .font(.caption.monospacedDigit())
                    }
                    Text("· \(subscription.senderDomain)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    onReject()
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.15))

                Button {
                    onConfirm()
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(.green)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.green.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func formatPrice(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let base = formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
        switch subscription.billingCycle ?? .unknown {
        case .monthly: return "\(base)/mo"
        case .annual: return "\(base)/yr"
        case .unknown: return base
        }
    }
}
