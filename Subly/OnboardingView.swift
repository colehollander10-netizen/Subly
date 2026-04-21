import EmailEngine
import SubscriptionStore
import SwiftData
import SwiftUI

/// Two-step onboarding:
///   Step 1 — connect first ("work / school") account.
///   Step 2 — connect second ("personal") account, with option to skip.
/// Once at least one account is connected the onboarding closes and the
/// main tab view takes over. Users can add or remove accounts later from
/// the Settings tab.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step: Step = .welcome
    @State private var errorMessage: String?
    @State private var isBusy = false

    private enum Step {
        case welcome
        case connectWork
        case connectPersonal
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                Spacer()
                header
                    .padding(.bottom, 32)
                content
                Spacer()
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 10)
            Text("Subly")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Track your free trials. Cancel before you're charged.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var content: some View {
        GlassCard {
            switch step {
            case .welcome:
                welcomeStep
            case .connectWork:
                connectStep(title: "Connect your work or school email",
                            subtitle: "We'll scan it for free trials. Read-only.",
                            buttonTitle: "Connect work/school Gmail")
            case .connectPersonal:
                connectStep(title: "Add a personal email?",
                            subtitle: "Many trials show up in personal inboxes too.",
                            buttonTitle: "Connect personal Gmail")
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            bullet("Finds trials where you entered a card")
            bullet("Reminds you 3 days before & the day of")
            bullet("Works across multiple Gmail accounts")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func connectStep(title: String, subtitle: String, buttonTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
            }
            GlassButton(title: buttonTitle, systemImage: "envelope.fill", isBusy: isBusy) {
                Task { await connect() }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .welcome:
            GlassButton(title: "Get started", systemImage: "arrow.right", isBusy: false) {
                withAnimation { step = .connectWork }
            }
        case .connectWork:
            EmptyView()
        case .connectPersonal:
            Button("Skip for now") { finish() }
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(text)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Actions

    private func connect() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        guard let presenter = PresentingHost.rootViewController() else {
            errorMessage = "Could not present sign-in."
            return
        }
        do {
            let account = try await EmailEngine.shared.signInAndAdd(presenting: presenter)
            // Persist to SwiftData too, so other parts of the app can query.
            let record = ConnectedAccount(id: account.userID, email: account.email)
            modelContext.insert(record)
            try? modelContext.save()

            withAnimation {
                if step == .connectWork {
                    step = .connectPersonal
                } else {
                    // Second connect done — main UI takes over automatically.
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        // No-op — the Query on ContentView flips us to RootTabView as soon as
        // one account is persisted. If the user skipped step 2, they're already
        // good to go. We just need to force a re-render to advance past the
        // step 2 screen. Since accounts is non-empty, ContentView will rebuild.
    }
}
