import NotificationEngine
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @AppStorage(AppPreferences.showDemoData) private var showDemoData = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var errorMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isUpdatingNotifications = false

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TerminalSectionLabel(title: "Notifications", trailing: notificationStatusLabel)
                            .padding(.top, 12)
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

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SublyTheme.critical)
                        }

                        TerminalSectionLabel(title: "Preview data", trailing: showDemoData ? "On" : "Off")
                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Show branded sample trials when your list is empty. Turn this off any time if you want a strictly real-data experience.")
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

                        Text("Subly tracks the free trials you share with it — no email connection, no backend. Everything stays on your device.")
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
