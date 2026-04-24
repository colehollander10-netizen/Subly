import NotificationEngine
import PhosphorSwift
import SubscriptionStore
import SwiftData
import SwiftUI

struct CancelAssistSheet: View {
    let trial: Trial
    let notificationEngine: NotificationEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private var guide: CancelGuide? { CancelGuideStore.guide(for: trial.serviceName) }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How to cancel \(trial.serviceName)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(FinnTheme.primaryText)
                            .padding(.top, 12)

                        if let guide {
                            SectionLabel(title: "Steps")

                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(guide.steps.indices, id: \.self) { i in
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text("\(i + 1)")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(FinnTheme.accent)
                                                .frame(width: 20, alignment: .leading)
                                            Text(guide.steps[i])
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(FinnTheme.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }

                            if let directURL = guide.directURL, let url = URL(string: directURL) {
                                Button {
                                    openURL(url)
                                } label: {
                                    Text("Open \(displayDomain(for: directURL)) →")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButton())
                            }
                        }

                        Button {
                            if let url = searchURL {
                                openURL(url)
                            }
                        } label: {
                            Text("Search how to cancel \(trial.serviceName) →")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GhostButton())

                        HairlineDivider()
                            .padding(.vertical, 16)

                        VStack(spacing: 12) {
                            Button {
                                handleCanceled()
                            } label: {
                                Text("I canceled it")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButton())

                            Button("I'll do it later") {
                                dismiss()
                            }
                            .buttonStyle(GhostButton())
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Ph.x.bold
                                .color(FinnTheme.tertiaryText)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var searchURL: URL? {
        let encoded = "how to cancel \(trial.serviceName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://duckduckgo.com/?q=\(encoded)")
    }

    private func displayDomain(for directURL: String) -> String {
        directURL.replacingOccurrences(of: "https://www.", with: "")
    }

    private func handleCanceled() {
        let trialID = trial.id
        trial.status = .cancelled
        trial.cancelledAt = Date()
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate { $0.trialID == trialID && !$0.delivered }
        )
        let pendingAlerts = (try? modelContext.fetch(descriptor)) ?? []
        let pendingIDs = pendingAlerts.map { $0.id.uuidString }
        for alert in pendingAlerts { modelContext.delete(alert) }
        try? modelContext.save()
        Task {
            await notificationEngine.removePending(ids: pendingIDs)
        }
        Haptics.play(.markCanceled)
        dismiss()
    }
}
