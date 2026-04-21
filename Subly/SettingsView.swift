import EmailEngine
import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @AppStorage(AppPreferences.showDemoData) private var showDemoData = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectedAccount.addedAt) private var accounts: [ConnectedAccount]

    @State private var errorMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isUpdatingNotifications = false

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TerminalSectionLabel(title: "Connected emails", trailing: "\(accounts.count)")
                            .padding(.top, 12)
                        HairlineDivider()

                        ForEach(accounts) { account in
                            accountRow(account)
                            if account.id != accounts.last?.id {
                                HairlineDivider()
                            }
                        }

                        Button {
                            Task { await connectAdditional() }
                        } label: {
                            Text("Add another email")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TerminalButtonStyle(background: SublyTheme.accent, foreground: .white))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SublyTheme.critical)
                        }

                        TerminalSectionLabel(title: "Notifications", trailing: notificationStatusLabel)
                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(notificationSummary)
                                .font(.system(size: 15))
                                .foregroundStyle(SublyTheme.secondaryText)

                            Button {
                                Task { await handleNotificationAction() }
                            } label: {
                                HStack {
                                    if isUpdatingNotifications {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text(notificationActionTitle)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(TerminalButtonStyle(background: SublyTheme.accent, foreground: .white))
                            .disabled(isUpdatingNotifications)
                        }

                        TerminalSectionLabel(title: "Preview data", trailing: showDemoData ? "On" : "Off")
                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Show branded sample trials when your inbox is empty. Turn this off any time if you want a strictly real-data experience.")
                                .font(.system(size: 15))
                                .foregroundStyle(SublyTheme.secondaryText)

                            Toggle(isOn: $showDemoData) {
                                Text("Show demo data when empty")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(SublyTheme.primaryText)
                            }
                            .tint(SublyTheme.accent)
                        }

                        TerminalSectionLabel(title: "About")
                        HairlineDivider()

                        Text("Subly tracks paid free trials from Gmail, keeps the scan local to your device, and warns you before you get charged.")
                            .font(.system(size: 15))
                            .foregroundStyle(SublyTheme.secondaryText)
                    }
                    .padding(.horizontal, 20)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await refreshNotificationStatus()
        }
    }

    @ViewBuilder
    private func accountRow(_ account: ConnectedAccount) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.email)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SublyTheme.primaryText)
                Text(account.lastScannedAt.map { "Scanned \($0.formatted(.relative(presentation: .named)))" } ?? "Not scanned yet")
                    .font(.system(size: 12))
                    .foregroundStyle(SublyTheme.secondaryText)
            }
            Spacer()
            Button("Disconnect") {
                disconnect(account)
            }
            .buttonStyle(SecondaryTerminalButtonStyle())
        }
    }

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

    private var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "On"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Setup"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationSummary: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Subly will remind you before a trial charges and can send a follow-up nudge if you put cancellation off."
        case .denied:
            return "Alerts are off right now. Turn them back on in iPhone Settings so Subly can warn you before a free trial bills your card."
        case .notDetermined:
            return "Turn on alerts so Subly can catch upcoming charges in time and follow up if you meant to cancel later."
        @unknown default:
            return "Subly uses notifications to warn you before trial charges land."
        }
    }

    private var notificationActionTitle: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Refresh alerts"
        case .denied:
            return "Open iPhone Settings"
        case .notDetermined:
            return "Enable notifications"
        @unknown default:
            return "Check notifications"
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    private func handleNotificationAction() async {
        errorMessage = nil
        isUpdatingNotifications = true
        defer { isUpdatingNotifications = false }

        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            let coordinator = TrialAlertCoordinator(
                modelContainer: modelContext.container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()

        case .notDetermined:
            let granted = await NotificationEngine().requestAuthorization()
            await refreshNotificationStatus()
            if granted || notificationStatus == .authorized {
                let coordinator = TrialAlertCoordinator(
                    modelContainer: modelContext.container,
                    notificationEngine: NotificationEngine()
                )
                await coordinator.replanAll()
            }

        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { break }
            _ = await UIApplication.shared.open(url)

        @unknown default:
            await refreshNotificationStatus()
        }
    }
}
