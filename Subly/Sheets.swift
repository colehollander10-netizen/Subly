import NotificationEngine
import SubscriptionStore
import SwiftData
import SwiftUI
import UIKit

struct CancelGuide {
    let title: String
    let steps: [String]
    let url: URL?
    let searchQuery: String
}

enum CancelGuideResolver {
    private struct Entry {
        let aliases: [String]
        let title: String
        let steps: [String]
        let url: String
    }

    private static let entries: [Entry] = [
        Entry(aliases: ["audible"], title: "Audible", steps: ["Open Audible in your browser.", "Go to Account Details.", "Open Membership details.", "Choose Cancel membership and confirm."], url: "https://www.audible.com/account/overview"),
        Entry(aliases: ["adobe", "creative cloud"], title: "Adobe", steps: ["Open your Adobe account.", "Go to Plans and payments.", "Choose Manage plan.", "Select Cancel your plan and follow the prompts."], url: "https://account.adobe.com/plans"),
        Entry(aliases: ["spotify"], title: "Spotify", steps: ["Open your Spotify account page.", "Choose Your plan.", "Select Change plan.", "Scroll to Cancel Premium and confirm."], url: "https://www.spotify.com/account/subscription/"),
        Entry(aliases: ["netflix"], title: "Netflix", steps: ["Open Netflix in your browser.", "Go to Account.", "Select Cancel Membership.", "Confirm the cancellation screen."], url: "https://www.netflix.com/YourAccount"),
        Entry(aliases: ["disney", "disney+"], title: "Disney+", steps: ["Open Disney+ account settings.", "Choose your subscription.", "Select Cancel Subscription.", "Finish the confirmation flow."], url: "https://www.disneyplus.com/account"),
        Entry(aliases: ["hulu"], title: "Hulu", steps: ["Open Hulu account settings.", "Choose Cancel under Your Subscription.", "Continue through the offer screens.", "Confirm cancel."], url: "https://secure.hulu.com/account"),
        Entry(aliases: ["max", "hbo"], title: "Max", steps: ["Open Max account.", "Go to Subscription.", "Choose Cancel Your Subscription.", "Complete the confirmation screen."], url: "https://www.max.com/account/subscription"),
        Entry(aliases: ["youtube", "youtube premium"], title: "YouTube Premium", steps: ["Open purchases and memberships in YouTube.", "Select Premium.", "Tap Deactivate.", "Choose Continue to cancel."], url: "https://www.youtube.com/paid_memberships"),
        Entry(aliases: ["prime", "amazon prime"], title: "Amazon Prime", steps: ["Open your Prime membership page.", "Choose Manage membership.", "Select End membership.", "Confirm on the final page."], url: "https://www.amazon.com/primecentral"),
        Entry(aliases: ["icloud", "apple one", "apple"], title: "Apple", steps: ["Open Settings on iPhone.", "Tap your Apple ID.", "Open Subscriptions.", "Select the subscription and tap Cancel."], url: "https://support.apple.com/en-us/118428"),
        Entry(aliases: ["google one"], title: "Google One", steps: ["Open Google subscriptions.", "Select Google One.", "Choose Manage.", "Select Cancel subscription."], url: "https://one.google.com/settings"),
        Entry(aliases: ["microsoft 365", "office 365"], title: "Microsoft 365", steps: ["Open Services & subscriptions.", "Find Microsoft 365.", "Choose Manage.", "Turn off recurring billing or cancel the plan."], url: "https://account.microsoft.com/services"),
        Entry(aliases: ["dropbox"], title: "Dropbox", steps: ["Open Dropbox account.", "Go to Billing.", "Choose Change plan.", "Select cancel or downgrade."], url: "https://www.dropbox.com/account/plan"),
        Entry(aliases: ["linkedin"], title: "LinkedIn Premium", steps: ["Open LinkedIn Premium settings.", "Choose Manage Premium account.", "Select Cancel subscription.", "Finish the confirmation flow."], url: "https://www.linkedin.com/premium/products"),
        Entry(aliases: ["chatgpt", "openai"], title: "ChatGPT", steps: ["Open ChatGPT settings.", "Choose Subscription.", "Select Manage plan.", "Cancel from the billing portal."], url: "https://chatgpt.com/"),
        Entry(aliases: ["claude"], title: "Claude", steps: ["Open Claude settings.", "Find Billing.", "Select Manage subscription.", "Cancel in the billing portal."], url: "https://claude.ai/settings/billing"),
        Entry(aliases: ["cursor"], title: "Cursor", steps: ["Open Cursor dashboard.", "Go to Billing.", "Choose Manage subscription.", "Cancel the active plan."], url: "https://www.cursor.com/settings"),
        Entry(aliases: ["notion"], title: "Notion", steps: ["Open Notion settings.", "Go to Billing.", "Select your plan.", "Cancel or downgrade the subscription."], url: "https://www.notion.so/settings"),
        Entry(aliases: ["figma"], title: "Figma", steps: ["Open Figma workspace settings.", "Go to Billing.", "Review the active plan.", "Cancel or downgrade from the billing page."], url: "https://www.figma.com/settings/billing"),
        Entry(aliases: ["canva"], title: "Canva", steps: ["Open Canva billing settings.", "Select the plan.", "Choose Cancel subscription.", "Confirm the cancellation."], url: "https://www.canva.com/settings/billing-plans"),
        Entry(aliases: ["grammarly"], title: "Grammarly", steps: ["Open Grammarly account.", "Go to Subscription.", "Choose Cancel subscription.", "Confirm the flow."], url: "https://account.grammarly.com/subscription"),
        Entry(aliases: ["1password"], title: "1Password", steps: ["Open 1Password billing.", "Review your subscription.", "Choose Cancel subscription.", "Confirm the cancellation."], url: "https://start.1password.com/profile/subscription"),
        Entry(aliases: ["headspace"], title: "Headspace", steps: ["Open Headspace account.", "Go to Manage subscription.", "Choose Cancel renewal.", "Confirm the flow."], url: "https://www.headspace.com/account"),
        Entry(aliases: ["calm"], title: "Calm", steps: ["Open Calm subscription settings.", "Select Manage subscription.", "Choose cancel.", "Finish the cancellation prompts."], url: "https://www.calm.com/account"),
        Entry(aliases: ["duolingo"], title: "Duolingo", steps: ["Open Duolingo settings.", "Go to Super billing.", "Select Cancel subscription.", "Confirm the change."], url: "https://www.duolingo.com/settings/account"),
        Entry(aliases: ["peloton"], title: "Peloton", steps: ["Open your Peloton membership page.", "Choose Billing.", "Select Cancel membership.", "Confirm cancellation."], url: "https://members.onepeloton.com/preferences/membership"),
        Entry(aliases: ["strava"], title: "Strava", steps: ["Open Strava settings.", "Go to My Account.", "Choose Downgrade.", "Confirm the change."], url: "https://www.strava.com/settings/account"),
        Entry(aliases: ["kindle"], title: "Kindle Unlimited", steps: ["Open Kindle Unlimited membership.", "Choose Cancel Kindle Unlimited.", "Follow the Amazon confirmation flow.", "Verify the cancellation date."], url: "https://www.amazon.com/kindle-dbs/hz/my-items"),
        Entry(aliases: ["new york times", "nyt"], title: "New York Times", steps: ["Open NYT account.", "Go to Subscription overview.", "Select Cancel subscription.", "Confirm the prompts."], url: "https://www.nytimes.com/subscription"),
        Entry(aliases: ["wall street journal", "wsj"], title: "Wall Street Journal", steps: ["Open WSJ customer center.", "Find your subscription.", "Choose Cancel subscription.", "Confirm the cancellation."], url: "https://customercenter.wsj.com/"),
        Entry(aliases: ["github copilot", "copilot"], title: "GitHub Copilot", steps: ["Open GitHub Billing and plans.", "Find Copilot.", "Choose Cancel Copilot.", "Confirm the cancellation."], url: "https://github.com/settings/billing"),
        Entry(aliases: ["substack"], title: "Substack", steps: ["Open your Substack subscriptions.", "Choose the publication.", "Select Manage subscription.", "Cancel recurring payment."], url: "https://substack.com/account"),
        Entry(aliases: ["readwise"], title: "Readwise", steps: ["Open Readwise account.", "Go to Billing.", "Choose Cancel plan.", "Confirm the cancellation."], url: "https://readwise.io/accounts/profile/"),
        Entry(aliases: ["scribd", "everand"], title: "Everand", steps: ["Open account settings.", "Go to Membership.", "Choose End membership.", "Confirm cancellation."], url: "https://www.everand.com/account-settings"),
        Entry(aliases: ["masterclass"], title: "MasterClass", steps: ["Open your MasterClass account.", "Go to Membership.", "Choose Cancel membership.", "Confirm the cancellation."], url: "https://www.masterclass.com/settings"),
        Entry(aliases: ["blinkist"], title: "Blinkist", steps: ["Open Blinkist account settings.", "Choose Subscription.", "Select Cancel subscription.", "Confirm cancellation."], url: "https://www.blinkist.com/en/nc/account"),
        Entry(aliases: ["bumble"], title: "Bumble", steps: ["Open Bumble in the platform you subscribed on.", "Open subscriptions or billing.", "Choose Bumble Premium.", "Cancel the renewal."], url: "https://bumble.com/en/help"),
        Entry(aliases: ["hinge"], title: "Hinge", steps: ["Open the App Store or Play Store subscriptions page.", "Find Hinge.", "Select Cancel subscription.", "Confirm the cancellation."], url: "https://hinge.co/help"),
        Entry(aliases: ["discord"], title: "Discord Nitro", steps: ["Open Discord User Settings.", "Go to Subscriptions.", "Select Nitro.", "Choose Cancel."], url: "https://discord.com/channels/@me"),
        Entry(aliases: ["every"], title: "Every", steps: ["Open Every account settings.", "Go to Billing.", "Choose Manage membership.", "Cancel the subscription."], url: "https://every.to/account"),
        Entry(aliases: ["readwise reader"], title: "Readwise Reader", steps: ["Open Readwise account.", "Go to Billing.", "Choose Cancel plan.", "Confirm the cancellation."], url: "https://readwise.io/accounts/profile/"),
        Entry(aliases: ["slack"], title: "Slack", steps: ["Open workspace administration.", "Go to Billing.", "Select Cancel subscription.", "Finish the prompts."], url: "https://my.slack.com/admin/billing"),
        Entry(aliases: ["loom"], title: "Loom", steps: ["Open Loom workspace settings.", "Go to Billing.", "Choose Cancel plan.", "Confirm."], url: "https://www.loom.com/settings/workspace/billing"),
        Entry(aliases: ["superhuman"], title: "Superhuman", steps: ["Open Superhuman settings.", "Go to Billing.", "Choose Cancel membership.", "Confirm the flow."], url: "https://mail.superhuman.com/settings"),
    ]

    static func resolve(serviceName: String, senderDomain: String) -> CancelGuide {
        let lower = serviceName.lowercased()
        if let entry = entries.first(where: { entry in
            entry.aliases.contains(where: { lower.contains($0) })
        }) {
            return CancelGuide(
                title: entry.title,
                steps: entry.steps,
                url: URL(string: entry.url),
                searchQuery: "\(entry.title) cancel subscription"
            )
        }

        if !senderDomain.isEmpty {
            let trimmed = senderDomain.replacingOccurrences(of: "www.", with: "")
            return CancelGuide(
                title: serviceName,
                steps: [
                    "Open \(trimmed) in your browser.",
                    "Look for Account, Billing, or Subscription settings.",
                    "Open the active plan details.",
                    "Turn off auto-renew or cancel the subscription."
                ],
                url: URL(string: "https://\(trimmed)"),
                searchQuery: "\(serviceName) cancel subscription"
            )
        }

        return CancelGuide(
            title: serviceName,
            steps: [
                "Open the service account page.",
                "Look for Billing or Subscription settings.",
                "Find the active plan.",
                "Cancel the subscription before the renewal date."
            ],
            url: nil,
            searchQuery: "\(serviceName) cancel subscription"
        )
    }
}

struct CancelFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let trial: Trial
    let onCancelled: () -> Void
    let onSnooze: () -> Void

    var guide: CancelGuide {
        CancelGuideResolver.resolve(serviceName: trial.serviceName, senderDomain: trial.senderDomain)
    }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionLabel(title: "Cancel flow")
                            .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("How to cancel \(guide.title)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(SublyTheme.primaryText)
                            if let amount = trial.chargeAmount {
                                Text("At risk: \(formatUSD(amount)) on \(trial.trialEndDate.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(SublyTheme.urgencyWarning)
                            } else {
                                Text("Renews on \(trial.trialEndDate.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }
                        }

                        HairlineDivider()

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(SublyTheme.accent)
                                        .frame(width: 18, alignment: .leading)
                                    Text(step)
                                        .font(.system(size: 15, weight: .medium, design: .default))
                                        .foregroundStyle(SublyTheme.primaryText)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            if let url = guide.url {
                                Button {
                                    openURL(url)
                                } label: {
                                    Text("Open \(url.host() ?? guide.title)")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButton())
                            }

                            Button {
                                let escaped = guide.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? guide.searchQuery
                                if let url = URL(string: "https://www.google.com/search?q=\(escaped)") {
                                    openURL(url)
                                }
                            } label: {
                                Text("Search cancel instructions")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GhostButton())
                        }

                        HairlineDivider()

                        VStack(spacing: 10) {
                            Button {
                                onCancelled()
                                dismiss()
                            } label: {
                                Text("I cancelled it")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButton())

                            Button {
                                onSnooze()
                                dismiss()
                            } label: {
                                Text("Remind me in 1 hour")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GhostButton())

                            Button("I'll do it later") {
                                dismiss()
                            }
                            .buttonStyle(GhostButton())
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Cancel")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct TrialDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trial: Trial?
    let onSaveExisting: ((Trial) -> Void)?
    let onCreateNew: ((Trial) -> Void)?

    private enum Preset: Int, CaseIterable, Identifiable {
        case sevenDays = 7
        case fourteenDays = 14
        case thirtyDays = 30
        case oneYear = 365
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .sevenDays: return "7 days"
            case .fourteenDays: return "14 days"
            case .thirtyDays: return "30 days"
            case .oneYear: return "1 year"
            }
        }
    }

    @State private var selectedPreset: Preset? = nil
    @State private var applyingPreset: Bool = false
    @FocusState private var focused: Bool
    @State private var serviceName: String
    @State private var trialEndDate: Date
    @State private var chargeAmountText: String
    @State private var pasteFeedback: String?

    init(trial: Trial? = nil, onSaveExisting: ((Trial) -> Void)? = nil, onCreateNew: ((Trial) -> Void)? = nil) {
        self.trial = trial
        self.onSaveExisting = onSaveExisting
        self.onCreateNew = onCreateNew
        _serviceName = State(initialValue: trial?.serviceName ?? "")
        let resolvedEndDate = trial?.trialEndDate ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        _trialEndDate = State(initialValue: resolvedEndDate)
        _chargeAmountText = State(initialValue: trial?.chargeAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        if let trial {
            let days = Calendar.current.dateComponents([.day], from: trial.detectedAt, to: trial.trialEndDate).day ?? 0
            let match = Preset.allCases.first { abs($0.rawValue - days) <= 1 }
            _selectedPreset = State(initialValue: match)
        } else {
            _selectedPreset = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(title: trial == nil ? "New trial" : "Edit trial")
                            .padding(.top, 12)
                        HairlineDivider()

                        if trial == nil {
                            Button {
                                applyClipboard()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste email to prefill")
                                }
                            }
                            .buttonStyle(GhostButton())

                            if let pasteFeedback {
                                Text(pasteFeedback)
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundStyle(SublyTheme.secondaryText)
                            }
                        }

                        field(title: "Service") {
                            TextField("Cursor Pro", text: $serviceName)
                                .textInputAutocapitalization(.words)
                                .focused($focused)
                        }

                        field(title: "Trial ends") {
                            VStack(alignment: .leading, spacing: 10) {
                                presetRow
                                DatePicker("", selection: $trialEndDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .onChange(of: trialEndDate) { _, _ in
                                        if applyingPreset { return }
                                        selectedPreset = nil
                                    }
                            }
                        }

                        field(title: "Charge amount") {
                            TextField("20.00", text: $chargeAmountText)
                                .keyboardType(.decimalPad)
                                .monospacedDigit()
                        }

                        VStack(spacing: 10) {
                            Button {
                                save()
                            } label: {
                                Text("Save")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButton())
                            .disabled(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(trial == nil ? "Add Trial" : "Edit Trial")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if trial == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focused = true
                }
            }
        }
    }

    @ViewBuilder
    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Preset.allCases) { preset in
                    let isSelected = selectedPreset == preset
                    Button {
                        applyingPreset = true
                        selectedPreset = preset
                        trialEndDate = Calendar.current.date(byAdding: .day, value: preset.rawValue, to: Date()) ?? trialEndDate
                        Haptics.play(.primaryTap)
                        Task { @MainActor in applyingPreset = false }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? SublyTheme.background : SublyTheme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? SublyTheme.primaryText : SublyTheme.backgroundElevated)
                            )
                            .overlay(
                                Capsule().strokeBorder(isSelected ? Color.clear : SublyTheme.divider, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                let customSelected = selectedPreset == nil
                Button {
                    selectedPreset = nil
                    Haptics.play(.primaryTap)
                } label: {
                    Text("Custom")
                        .font(.system(size: 13, weight: customSelected ? .semibold : .medium, design: .default))
                        .foregroundStyle(customSelected ? SublyTheme.background : SublyTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(customSelected ? SublyTheme.primaryText : SublyTheme.backgroundElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(customSelected ? Color.clear : SublyTheme.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .tracking(1.8)
                .foregroundStyle(SublyTheme.secondaryText)
            content()
                .font(.system(size: 20, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.primaryText)
                .padding(.vertical, 10)
            HairlineDivider()
        }
    }

    private func save() {
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Decimal(string: chargeAmountText.replacingOccurrences(of: "$", with: ""))
        let inferredDomain = BrandDirectory.logoDomain(for: trimmedName, senderDomain: trial?.senderDomain)
        if let trial {
            trial.serviceName = trimmedName
            if (trial.senderDomain).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                trial.senderDomain = inferredDomain ?? ""
            }
            trial.trialEndDate = trialEndDate
            trial.chargeAmount = amount
            onSaveExisting?(trial)
        } else {
            let newTrial = Trial(
                serviceName: trimmedName,
                senderDomain: inferredDomain ?? "",
                trialEndDate: trialEndDate,
                chargeAmount: amount
            )
            modelContext.insert(newTrial)
            onCreateNew?(newTrial)
        }
        try? modelContext.save()
        Haptics.play(.save)

        let container = modelContext.container
        Task {
            let coordinator = TrialAlertCoordinator(
                modelContainer: container,
                notificationEngine: NotificationEngine()
            )
            await coordinator.replanAll()
        }

        dismiss()
    }

    private func applyClipboard() {
        guard let raw = UIPasteboard.general.string, !raw.isEmpty else {
            pasteFeedback = "Clipboard is empty."
            return
        }
        let extracted = ManualTrialExtractor.extract(from: raw)
        var filled: [String] = []
        if let name = extracted.serviceName, serviceName.isEmpty {
            serviceName = name
            filled.append("service")
        }
        if let end = extracted.trialEndDate {
            trialEndDate = end
            filled.append("end date")
        }
        if let amount = extracted.chargeAmount, chargeAmountText.isEmpty {
            chargeAmountText = amount
            filled.append("amount")
        }
        pasteFeedback = filled.isEmpty ? "Couldn't detect trial details." : "Filled \(filled.joined(separator: ", "))."
    }
}

enum ManualTrialExtractor {
    struct Result {
        let serviceName: String?
        let trialEndDate: Date?
        let chargeAmount: String?
    }

    static func extract(from text: String) -> Result {
        Result(
            serviceName: extractServiceName(from: text),
            trialEndDate: extractDate(from: text),
            chargeAmount: extractAmount(from: text)
        )
    }

    private static func extractServiceName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()
            guard lower.hasPrefix("from:") || lower.hasPrefix("from ") else { continue }
            let rest = String(line.dropFirst(5))
            if let lt = rest.firstIndex(of: "<") {
                let display = rest[..<lt].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !display.isEmpty { return display }
            }
            if let at = rest.lastIndex(of: "@") {
                let domain = rest[rest.index(after: at)...]
                    .trimmingCharacters(in: CharacterSet(charactersIn: "> \t\n\r"))
                let parts = domain.split(separator: ".")
                if parts.count >= 2 { return String(parts[parts.count - 2]).capitalized }
            }
        }
        return nil
    }

    private static func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let future = Date().addingTimeInterval(60 * 60 * 6)
        for match in detector.matches(in: text, options: [], range: range) {
            if let date = match.date, date >= future { return date }
        }
        return nil
    }

    private static func extractAmount(from text: String) -> String? {
        let pattern = #"\$\s?(\d{1,4}(?:\.\d{2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.matches(in: text, options: [], range: range).first,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }
}
