import EmailEngine
import SubscriptionStore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]

    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Manage your connected inboxes")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    // Accounts section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Connected emails")
                            .padding(.horizontal, 24)
                            .padding(.top, 32)

                        GlassCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(accounts) { account in
                                    accountRow(account)
                                    if account != accounts.last {
                                        Divider()
                                            .background(.white.opacity(0.10))
                                            .padding(.leading, 68)
                                    }
                                }

                                // Add account row
                                Divider()
                                    .background(.white.opacity(0.10))

                                Button {
                                    Task { await connectAdditional() }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.sublyBlue.opacity(0.20))
                                                .frame(width: 38, height: 38)
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.sublyBlue)
                                        }
                                        Text("Add another email")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.sublyBlue)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.sublyRed.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    // About section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "About")
                            .padding(.horizontal, 24)
                            .padding(.top, 32)

                        GlassCard(padding: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Subly tracks paid free trials — the ones where you entered a credit card — and reminds you to cancel before you're charged.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .lineSpacing(3)

                                Divider().background(.white.opacity(0.10))

                                HStack {
                                    Text("Version")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.45))
                                    Spacer()
                                    Text("0.3.0")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 60)
                }
            }
        }
    }

    // MARK: - Account row

    @ViewBuilder
    private func accountRow(_ account: ConnectedAccount) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.sublyPurple.opacity(0.25))
                    .frame(width: 38, height: 38)
                Text(String(account.email.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.sublyPurple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let last = account.lastScannedAt {
                    Text("Scanned \(last.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.40))
                } else {
                    Text("Not scanned yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            Spacer()

            Button(role: .destructive) {
                disconnect(account)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
