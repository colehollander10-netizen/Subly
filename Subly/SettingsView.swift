import NotificationEngine
import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var allTrials: [Trial]
    @State private var errorMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isUpdatingNotifications = false
    @State private var isFetchingImport = false
    @State private var exportedCSVURL: URL?
    @State private var pendingImports: [ImportableSubscription]?
    @State private var showingDeleteConfirm = false
    @State private var showingImportSheet = false

    private let storeKitImport = StoreKitImport()

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Notifications", trailing: notificationStatusLabel)
                            SurfaceCard(padding: 18) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(notificationSummary)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(SublyTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Button {
                                        Task {
                                            Haptics.play(.primaryTap)
                                            await handleNotificationAction()
                                        }
                                    } label: {
                                        HStack {
                                            if isUpdatingNotifications {
                                                ProgressView().tint(SublyTheme.background)
                                            }
                                            Text(notificationActionTitle).frame(maxWidth: .infinity)
                                        }
                                    }
                                    .buttonStyle(PrimaryButton())
                                    .disabled(isUpdatingNotifications)

                                    if let errorMessage {
                                        Text(errorMessage)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(SublyTheme.urgencyCritical)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Data")
                            SurfaceCard(padding: 0) {
                                VStack(spacing: 0) {
                                    settingsRow(title: "Import subscriptions", subtitle: "Bring in your Apple-billed subscriptions.", tint: SublyTheme.primaryText) {
                                        Haptics.play(.rowTap)
                                        Task { await runImport() }
                                    }
                                    HairlineDivider().padding(.horizontal, 18)
                                    settingsRow(title: "Export trials", subtitle: "Share a CSV of every trial on this device.", tint: SublyTheme.primaryText) {
                                        Haptics.play(.rowTap)
                                        exportTrials()
                                    }
                                    HairlineDivider().padding(.horizontal, 18)
                                    settingsRow(title: "Delete all data", subtitle: "Wipe every trial from this device. This cannot be undone.", tint: SublyTheme.urgencyCritical) {
                                        Haptics.play(.rowTap)
                                        showingDeleteConfirm = true
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "About")
                            SurfaceCard(padding: 18) {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text("Version")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(SublyTheme.primaryText)
                                        Spacer()
                                        Text(appVersion)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(SublyTheme.secondaryText)
                                    }
                                    HairlineDivider()
                                    Button {
                                        Haptics.play(.rowTap)
                                        if let url = URL(string: "https://subly.app/privacy") {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack {
                                            Text("Privacy policy")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(SublyTheme.primaryText)
                                            Spacer()
                                            Ph.arrowUpRight.bold
                                                .color(SublyTheme.tertiaryText)
                                                .frame(width: 14, height: 14)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PressableRowStyle())
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .confirmationDialog("Delete all trials?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                Haptics.play(.destructiveConfirm)
                deleteAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes every trial from this device. Cannot be undone.")
        }
        .sheet(item: $exportedCSVURL) { url in
            ShareSheet(activityItems: [url])
        }
        .onChange(of: exportedCSVURL?.id) { _, newValue in
            if newValue != nil { Haptics.play(.sheetPresent) }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportConfirmationSheet(
                subscriptions: pendingImports ?? [],
                onImport: handleImport
            )
        }
        .overlay {
            if isFetchingImport {
                ZStack {
                    SublyTheme.background.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SublyTheme.accent)
                }
                .transition(.opacity)
            }
        }
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshNotificationStatus() }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    @ViewBuilder
    private func settingsRow(title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SublyTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Ph.caretRight.bold
                    .color(SublyTheme.tertiaryText)
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle())
    }

    @MainActor
    private func runImport() async {
        isFetchingImport = true
        defer { isFetchingImport = false }

        do {
            let results = try await storeKitImport.fetchCurrentEntitlements()
            pendingImports = results
            showingImportSheet = true
        } catch {
            pendingImports = []
            showingImportSheet = true
        }
    }

    @MainActor
    private func handleImport(_ chosen: [ImportableSubscription]) {
        for sub in chosen {
            let chargeDate = sub.nextBillingDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30)
            let trial = Trial(
                serviceName: sub.displayName,
                senderDomain: "",
                chargeDate: chargeDate,
                chargeAmount: sub.amount,
                entryType: .subscription,
                status: .active,
                billingCycle: sub.billingCycle
            )
            modelContext.insert(trial)
        }
        try? modelContext.save()
        Haptics.play(.save)
    }

    private func exportTrials() {
        let header = "Service,End Date,Charge Amount\n"
        let rows = allTrials.map { trial -> String in
            let service = trial.serviceName.replacingOccurrences(of: ",", with: " ")
            let date = ISO8601DateFormatter().string(from: trial.chargeDate)
            let amount = trial.chargeAmount.map { "\($0)" } ?? ""
            return "\(service),\(date),\(amount)"
        }.joined(separator: "\n")
        let csv = header + rows
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("subly-trials.csv")
        try? csv.data(using: .utf8)?.write(to: url)
        exportedCSVURL = url
    }

    private func deleteAllData() {
        for trial in allTrials {
            modelContext.delete(trial)
        }
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
