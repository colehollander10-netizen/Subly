import EmailEngine
import SubscriptionStore
import SwiftData
import SwiftUI

/// Settings tab: connected accounts list, add another account, disconnect,
/// about section. No password, no preferences yet — keep it minimal.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]

    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 20) {
                    accountsCard
                    aboutCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var accountsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("CONNECTED EMAILS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .kerning(1.5)

                ForEach(accounts) { account in
                    accountRow(account)
                    if account != accounts.last {
                        Divider().background(.white.opacity(0.15))
                    }
                }

                GlassButton(title: "Add another email", systemImage: "plus") {
                    Task { await connectAdditional() }
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func accountRow(_ account: ConnectedAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.white)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let last = account.lastScannedAt {
                    Text("Last scan: \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("Not scanned yet")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            Button(role: .destructive) {
                disconnect(account)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var aboutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("ABOUT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .kerning(1.5)
                Text("Subly tracks paid free trials — the ones where you entered a credit card — and reminds you to cancel before you're charged.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Version 0.2.0")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Actions

    private func connectAdditional() async {
        errorMessage = nil
        guard let presenter = PresentingHost.rootViewController() else {
            errorMessage = "Could not present sign-in."
            return
        }
        do {
            let account = try await EmailEngine.shared.signInAndAdd(presenting: presenter)
            let record = ConnectedAccount(id: account.userID, email: account.email)
            modelContext.insert(record)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disconnect(_ account: ConnectedAccount) {
        EmailEngine.shared.disconnect(accountID: account.id)
        modelContext.delete(account)
        try? modelContext.save()
    }
}
