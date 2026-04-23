# COL-134 TrialDetailSheet Overhaul Implementation Plan

> **For agentic workers:** This plan is executed by the orchestrator (Claude) via the `route` skill, NOT by subagent-driven-development. The route skill dispatches Cursor (`composer-2-fast`) for Task 1 and Task 2, and Claude executes Tasks 3 and 4 inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `TrialDetailSheet` in `Subly/Sheets.swift` to feel like a crafted sheet (Copilot Money / Flighty / Sofa tier), not a stock SwiftUI form. Applies to both create and edit modes.

**Architecture:** Compact live-updating preview row at top → one `SurfaceCard` with 4 rows (paste, service, trial-ends, charge amount) divided by `HairlineDivider` → `PrimaryButton` Save → muted "Mark as cancelled" text button in edit mode. All icons via Phosphor (`Ph.{name}.{weight}`). New `TrialPreviewRow` primitive extracted to `GlassComponents.swift`.

**Tech Stack:** SwiftUI, SwiftData, PhosphorSwift (already imported app-wide), UIKit (UIPasteboard).

**Spec:** `docs/superpowers/specs/2026-04-23-col-134-trial-detail-sheet-design.md`
**Linear:** COL-134
**Branch:** `colehollander10/col-134-v2-design-14-trialdetailsheet-complete-overhaul-edit-create` (already checked out)

---

## File structure

| File | Role | Change |
|---|---|---|
| `Subly/GlassComponents.swift` | Shared primitives | **Add** `TrialPreviewRow` after `AccentPill` (~line 164) |
| `Subly/Sheets.swift` | Sheet implementations | **Rewrite** `TrialDetailSheet` (lines 237–522). Leave `CancelGuide`, `CancelGuideResolver`, `CancelFlowSheet`, `ManualTrialExtractor` untouched. |

## Known codebase facts (verified before writing plan)

- `Haptics` enum cases available: `primaryTap`, `primaryLongPress`, `save`, `validationFail`, `scanStart`, `scanComplete`, `markCanceled`, `scheduleReminder`, `swipeThresholdCrossed`, `rowTap`, `sheetPresent`, `tabSwitch`, `destructiveConfirm`. **No `selection` case.** Plan uses `.primaryTap` where spec says "selection" (already the app's light-tap haptic).
- `formatUSD(_ value: Decimal) -> String` lives at `Subly/ContentView.swift:120`, globally callable.
- `urgencyLevel(days:) -> UrgencyLevel` is **private to HomeView** (`Subly/HomeView.swift:252`). Plan computes urgency inline in `TrialPreviewRow` using the same thresholds.
- Phosphor usage pattern: `Ph.briefcase.regular` is a View; apply `.color(...)` then `.frame(width:height:)`. `.foregroundStyle(...)` does nothing — must use `.color()`.
- `SurfaceCard(padding:)` initializer has `padding: 18` default. Plan uses `padding: 0` to let rows manage their own insets.
- `SectionLabel(title:trailing:)` — `trailing` is optional String.
- `PrimaryButton`, `GhostButton` are `ButtonStyle` structs — applied as `.buttonStyle(PrimaryButton())`.
- `AccentPill` body is a `Text`, so `.contentTransition(.numericText())` CAN be applied to the pill directly via a wrapping modifier — but safer to put the numeric text outside the pill. Plan wraps `AccentPill` with the transition modifier and tests in simulator; if it doesn't animate, move the modifier to an internal Text.

---

## Task 1: Add `TrialPreviewRow` primitive to `GlassComponents.swift`

**Worker:** Cursor `composer-2-fast`
**Files:**
- Modify: `Subly/GlassComponents.swift:164` (insert new view after `AccentPill`)

- [ ] **Step 1: Read the surrounding context**

Read `Subly/GlassComponents.swift` lines 149–165 to confirm `AccentPill` is at line 149 and the next view (`GlassCard`) starts at line 166. Insert `TrialPreviewRow` between them.

- [ ] **Step 2: Write `TrialPreviewRow`**

Insert this block after line 164 (after `AccentPill`'s closing brace) in `Subly/GlassComponents.swift`:

```swift
/// Compact live-updating preview row. ~72pt tall. Used in TrialDetailSheet
/// to show the user what their trial entry will look like in Home/Trials.
struct TrialPreviewRow: View {
    let name: String
    let domain: String?
    let endDate: Date?
    let amount: Decimal?

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your trial" : trimmed
    }

    private var daysUntilEnd: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day
    }

    private var urgencyColor: Color {
        guard let days = daysUntilEnd else { return SublyTheme.tertiaryText }
        return SublyTheme.urgencyColor(daysLeft: days)
    }

    private var daysLeftText: String {
        guard let days = daysUntilEnd else { return "—" }
        if days <= 0 { return "TODAY" }
        return "\(days)D LEFT"
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        switch (endDate, amount) {
        case (nil, _):
            return "Set an end date"
        case (let date?, nil):
            return "Ends \(formatter.string(from: date))"
        case (let date?, let amount?):
            return "Ends \(formatter.string(from: date)) · \(formatUSD(amount))"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ServiceIcon(name: displayName, domain: domain, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(SublyTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if daysUntilEnd != nil {
                AccentPill(text: daysLeftText, color: urgencyColor)
                    .contentTransition(.numericText())
                    .breathing((daysUntilEnd ?? 99) <= 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SublyTheme.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SublyTheme.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: Verify the file still compiles**

Run:
```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`. If errors, they will be in `GlassComponents.swift` only (nothing else changed yet).

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/Subly
git add Subly/GlassComponents.swift
git commit -m "feat(col-134): add TrialPreviewRow primitive to GlassComponents"
```

---

## Task 2: Rewrite `TrialDetailSheet` in `Sheets.swift`

**Worker:** Cursor `composer-2-fast`
**Files:**
- Modify: `Subly/Sheets.swift:237-522` (replace entire `TrialDetailSheet` struct body)

**Precondition:** Task 1 committed, `TrialPreviewRow` available in the module.

- [ ] **Step 1: Read the existing struct to preserve call-site signature**

Read `Subly/Sheets.swift:237-291` to confirm the `init` signature. It MUST remain:

```swift
init(
    trial: Trial? = nil,
    onSaveExisting: ((Trial) -> Void)? = nil,
    onCreateNew: ((Trial) -> Void)? = nil,
    onMarkCancelled: ((Trial) -> Void)? = nil
)
```

Call sites in HomeView / TrialsView depend on this shape. Do not change it.

- [ ] **Step 2: Replace `TrialDetailSheet` struct**

Replace `Subly/Sheets.swift` lines 237 through 522 (the entire `struct TrialDetailSheet: View` block, inclusive of its closing `}`) with the following. Leave lines 524+ (the `ManualTrialExtractor` enum) untouched.

```swift
struct TrialDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let trial: Trial?
    let onSaveExisting: ((Trial) -> Void)?
    let onCreateNew: ((Trial) -> Void)?
    let onMarkCancelled: ((Trial) -> Void)?

    private enum Preset: Int, CaseIterable, Identifiable {
        case sevenDays = 7
        case fourteenDays = 14
        case thirtyDays = 30
        case oneYear = 365
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .sevenDays: return "7d"
            case .fourteenDays: return "14d"
            case .thirtyDays: return "30d"
            case .oneYear: return "1y"
            }
        }
    }

    @State private var selectedPreset: Preset? = nil
    @State private var applyingPreset: Bool = false
    @FocusState private var focused: Bool
    @State private var serviceName: String
    @State private var trialEndDate: Date
    @State private var chargeAmountText: String
    @State private var pasteFilledFields: [String] = []
    @State private var pasteShowsSuccess: Bool = false
    @State private var pasteResetTask: Task<Void, Never>? = nil

    init(
        trial: Trial? = nil,
        onSaveExisting: ((Trial) -> Void)? = nil,
        onCreateNew: ((Trial) -> Void)? = nil,
        onMarkCancelled: ((Trial) -> Void)? = nil
    ) {
        self.trial = trial
        self.onSaveExisting = onSaveExisting
        self.onCreateNew = onCreateNew
        self.onMarkCancelled = onMarkCancelled
        _serviceName = State(initialValue: trial?.serviceName ?? "")
        let resolvedEndDate = trial?.chargeDate ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        _trialEndDate = State(initialValue: resolvedEndDate)
        _chargeAmountText = State(initialValue: trial?.chargeAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        if let trial {
            let days = Calendar.current.dateComponents([.day], from: trial.detectedAt, to: trial.chargeDate).day ?? 0
            let match = Preset.allCases.first { abs($0.rawValue - days) <= 1 }
            _selectedPreset = State(initialValue: match)
        } else {
            _selectedPreset = State(initialValue: nil)
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: chargeAmountText.replacingOccurrences(of: "$", with: ""))
    }

    private var previewDomain: String? {
        BrandDirectory.logoDomain(for: serviceName, senderDomain: trial?.senderDomain)
    }

    var body: some View {
        NavigationStack {
            ScreenFrame {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HairlineDivider()
                        TrialPreviewRow(
                            name: serviceName,
                            domain: previewDomain,
                            endDate: trialEndDate,
                            amount: parsedAmount
                        )
                        fieldsCard
                        Button {
                            Haptics.play(.save)
                            save()
                        } label: {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.top, 4)

                        if let trial {
                            VStack(spacing: 16) {
                                HairlineDivider()
                                Button {
                                    Haptics.play(.markCanceled)
                                    onMarkCancelled?(trial)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Ph.checkCircle.regular
                                            .color(SublyTheme.secondaryText)
                                            .frame(width: 16, height: 16)
                                        Text("Mark as cancelled")
                                            .font(.system(size: 15, weight: .medium, design: .default))
                                            .foregroundStyle(SublyTheme.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(SublyTheme.primaryText)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if trial == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focused = true
                }
            }
        }
        .onDisappear {
            pasteResetTask?.cancel()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: trial == nil ? "New trial" : "Edit trial")
            Text(trial == nil ? "Add Trial" : "Edit Trial")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SublyTheme.primaryText)
        }
    }

    @ViewBuilder
    private var fieldsCard: some View {
        SurfaceCard(padding: 0) {
            VStack(spacing: 0) {
                if trial == nil {
                    pasteRow
                    HairlineDivider().padding(.leading, 54)
                }
                serviceField
                HairlineDivider().padding(.leading, 54)
                trialEndsField
                HairlineDivider().padding(.leading, 54)
                chargeAmountField
            }
        }
    }

    @ViewBuilder
    private var pasteRow: some View {
        Button {
            Haptics.play(.primaryTap)
            applyClipboard()
        } label: {
            HStack(spacing: 14) {
                Group {
                    if pasteShowsSuccess {
                        Ph.checkCircle.fill
                            .color(SublyTheme.accent)
                            .frame(width: 22, height: 22)
                    } else {
                        Ph.clipboardText.regular
                            .color(SublyTheme.tertiaryText)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 24, height: 22, alignment: .center)
                .padding(.top, 2)

                Text(pasteShowsSuccess
                     ? "Filled: \(pasteFilledFields.joined(separator: ", "))"
                     : "Paste from clipboard")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(pasteShowsSuccess ? SublyTheme.accent : SublyTheme.primaryText)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var serviceField: some View {
        fieldRow(icon: AnyView(Ph.briefcase.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
                 label: "Service") {
            TextField("Cursor Pro", text: $serviceName)
                .textInputAutocapitalization(.words)
                .focused($focused)
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundStyle(SublyTheme.primaryText)
        }
    }

    @ViewBuilder
    private var trialEndsField: some View {
        fieldRow(icon: AnyView(Ph.calendar.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
                 label: "Trial ends") {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("", selection: $trialEndDate, displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .onChange(of: trialEndDate) { _, _ in
                        if applyingPreset { return }
                        selectedPreset = nil
                    }
                presetRow
            }
        }
    }

    @ViewBuilder
    private var chargeAmountField: some View {
        fieldRow(icon: AnyView(Ph.currencyDollar.regular.color(SublyTheme.tertiaryText).frame(width: 22, height: 22)),
                 label: "Charge amount") {
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(SublyTheme.tertiaryText)
                TextField("20.00", text: $chargeAmountText)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(SublyTheme.primaryText)
            }
        }
    }

    @ViewBuilder
    private func fieldRow<Content: View>(
        icon: AnyView,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.8)
                    .foregroundStyle(SublyTheme.secondaryText)
                content()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                            .foregroundStyle(isSelected ? SublyTheme.background : SublyTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? SublyTheme.accent : SublyTheme.backgroundElevated)
                            )
                            .overlay(
                                Capsule().strokeBorder(isSelected ? Color.clear : SublyTheme.divider, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = parsedAmount
        let inferredDomain = BrandDirectory.logoDomain(for: trimmedName, senderDomain: trial?.senderDomain)
        if let trial {
            trial.serviceName = trimmedName
            if (trial.senderDomain).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                trial.senderDomain = inferredDomain ?? ""
            }
            trial.chargeDate = trialEndDate
            trial.chargeAmount = amount
            onSaveExisting?(trial)
        } else {
            let newTrial = Trial(
                serviceName: trimmedName,
                senderDomain: inferredDomain ?? "",
                chargeDate: trialEndDate,
                chargeAmount: amount
            )
            modelContext.insert(newTrial)
            onCreateNew?(newTrial)
        }
        try? modelContext.save()

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
        guard !filled.isEmpty else { return }
        pasteFilledFields = filled
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            pasteShowsSuccess = true
        }
        pasteResetTask?.cancel()
        pasteResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                pasteShowsSuccess = false
            }
        }
    }
}
```

- [ ] **Step 3: Build and fix any compile errors**

Run:
```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | tail -50
```

Expected: `** BUILD SUCCEEDED **`.

Common issues to watch for:
- `Ph.checkCircle` / `Ph.clipboardText` / `Ph.briefcase` / `Ph.calendar` / `Ph.currencyDollar` — these are standard Phosphor icon names. If the resolver complains, the Phosphor package may use a different casing; try `Ph.CheckCircle` or grep existing usage with `grep -r "Ph\." --include="*.swift" Subly/` to confirm the convention.
- `AnyView` wrapping Phosphor icons — the Phosphor icon type is generic; some SwiftUI builders require type erasure when it's returned from a function parameter. The plan wraps them in `AnyView` deliberately to keep `fieldRow` signature simple.

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/Subly
git add Subly/Sheets.swift
git commit -m "feat(col-134): rewrite TrialDetailSheet with preview row + grouped fields"
```

---

## Task 3: Phosphor audit for `Sheets.swift`

**Worker:** Claude inline
**Files:**
- Modify: `Subly/Sheets.swift` (any remaining `Image(systemName:)` calls)

- [ ] **Step 1: Grep for remaining SF Symbol usage**

Run:
```bash
cd ~/Developer/Subly && grep -n 'Image(systemName:' Subly/Sheets.swift
```

Expected: **0 matches**. The Task 2 rewrite already removed the `doc.on.clipboard` usage at the old line 307.

If matches appear, for each one:
- Map the SF Symbol name to a Phosphor equivalent (e.g., `chevron.right` → `Ph.caretRight.regular`, `sparkle` → `Ph.sparkle.fill`)
- Replace using the `Ph.{name}.{weight}.color(...).frame(...)` pattern
- Match icon size to the original `.font(.system(size:))` value

- [ ] **Step 2: Verify build still passes**

Run:
```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: If no changes were needed, skip commit**

If Step 1 found 0 matches, no commit needed — the Task 2 commit already cleaned `Sheets.swift`. Otherwise:

```bash
cd ~/Developer/Subly
git add Subly/Sheets.swift
git commit -m "chore(col-134): migrate remaining SF Symbols in Sheets.swift to Phosphor"
```

---

## Task 4: Simulator walkthrough + PR

**Worker:** Claude inline
**Files:** none (verification only)

- [ ] **Step 1: Full build on simulator destination**

Run:
```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`. If signing errors: note the error and stop — signing issues block simulator launch but may not block PR.

- [ ] **Step 2: Manual simulator checklist (state in PR body)**

Claude cannot launch the simulator autonomously in this session, so list manual verification steps in the PR description for Cole to walk through:

1. Launch app → tap `+` FAB → sheet presents with drag indicator visible
2. Type "Spotify" in Service field → preview row updates with Spotify icon, "Your trial" → "Spotify"
3. Tap "7d" preset → date updates, preview daysLeft pill shows "7D LEFT", haptic fires
4. Tap "30d" → daysLeft animates (numeric text transition) to "30D LEFT"
5. Type "11.99" in amount → preview subtitle shows "Ends {date} · $11.99"
6. Tap Save → sheet dismisses, entry appears in Trials list
7. Long-press an existing trial row → open edit sheet → confirm no auto-focus on service name (existing edit shouldn't hijack keyboard)
8. In edit mode → scroll to bottom → confirm "Mark as cancelled" appears below HairlineDivider with muted text + Phosphor checkmark
9. Copy a receipt-style string to clipboard (e.g., `"From: Notion <billing@notion.so>\nTrial ends May 15\n$10.00"`) → tap "Paste from clipboard" → fields fill, paste row transforms to `Ph.checkCircle.fill` + "Filled: service, end date, amount" in lavender
10. Wait 3 seconds → paste row auto-reverts to default state

- [ ] **Step 3: Mark route-skill subtask 4 complete**

Route skill Step 6 cross-check: walk through every AC from the spec and the Linear ticket. Each must have a ✅ or a documented miss.

- [ ] **Step 4: Open PR**

```bash
cd ~/Developer/Subly
git push -u origin colehollander10/col-134-v2-design-14-trialdetailsheet-complete-overhaul-edit-create

gh pr create --title "COL-134 — TrialDetailSheet complete overhaul (edit + create)" --body "$(cat <<'EOF'
## Summary

Complete rewrite of `TrialDetailSheet` per COL-134 (Urgent).

Manual entry is the product — this sheet had to stop reading like a stock SwiftUI form. Full design spec lives at `docs/superpowers/specs/2026-04-23-col-134-trial-detail-sheet-design.md`.

### What changed

- **New `TrialPreviewRow` primitive** in `GlassComponents.swift` — compact 72pt live-updating preview that mirrors the Home/Trials list appearance
- **Single `SurfaceCard` with grouped fields** — paste (create only) / service / trial ends / charge amount, divided by `HairlineDivider`
- **Phosphor icons** as field affordances (`briefcase` / `calendar` / `currency-dollar` / `clipboard-text` / `check-circle`) — zero `Image(systemName:)` in `Sheets.swift`
- **Preset chips redesigned** — lavender selected (matches PrimaryButton WCAG combo), charcoal unselected, dropped "Custom" chip (absence of selection isn't a state)
- **Save + Mark cancelled in distinct registers** — `PrimaryButton` Save, muted text-only Mark cancelled (not destructive red; marking cancelled is a WIN state)
- **Paste success banner** — paste row transforms in-place to `check-circle` + "Filled: …" in lavender for 3s
- **Drag indicator** added to sheet chrome
- **Header moved in-scroll** — SectionLabel + 28pt display title, replaces principal toolbar title

### Test plan

- [ ] Create-mode: sheet presents with drag indicator, auto-focuses Service field after 200ms
- [ ] Preview row updates live as Service / date / amount change
- [ ] Preview daysLeft pill animates via `.contentTransition(.numericText())`
- [ ] Preset chips: lavender when selected, `.primaryTap` haptic, 150ms fill crossfade
- [ ] Amount field: `$` prefix, `.monospacedDigit()` rounded design
- [ ] Save disabled when service empty
- [ ] Edit-mode: no auto-focus on Service, Mark as cancelled visible below HairlineDivider
- [ ] Paste-to-prefill: success banner shows for 3s, auto-reverts
- [ ] Paste auto-revert task cancels on sheet dismiss (no leaks)
- [ ] Reduced motion: springs instant, numericText stays (identity transition)
- [ ] Build passes for iOS Simulator destination

### Out of scope

- FAB visual overhaul (COL-138)
- Full-app Phosphor audit — this PR only touches `Sheets.swift`. Remaining SF Symbols in `PrimaryAddButton.swift`, `SettingsView.swift`, `GlassComponents.swift` (HeaderIconButton, EmptyStateBlock) are untouched and will be covered by follow-up tickets.

Closes COL-134.
EOF
)"
```

- [ ] **Step 5: Update Linear**

```bash
# From Claude via linear MCP — not bash. Planning note: update COL-134 to "In Progress" when Task 1 starts, to "In Review" when PR opens, to "Done" when PR merges.
```

---

## Self-Review

**Spec coverage:** Every AC from the spec maps to a task:
- Drag indicator → Task 2 Step 2 (`.presentationDragIndicator(.visible)`)
- In-scroll header → Task 2 Step 2 (`header` private var)
- `TrialPreviewRow` extracted → Task 1
- Live preview updates → Task 2 (preview row wired to `@State`)
- Empty states → Task 1 (`displayName`, `subtitle` computed properties)
- Phosphor icons → Task 2 (all 5 icons) + Task 3 (audit for stragglers)
- `$` prefix + monospaced digit amount → Task 2 `chargeAmountField`
- Preset chips (no Custom) → Task 2 `presetRow`
- Chip labels `7d 14d 30d 1y` → Task 2 `Preset.label`
- Save = PrimaryButton → Task 2 Step 2
- Mark cancelled muted → Task 2 Step 2
- Save/cancelled separated → Task 2 Step 2 (HairlineDivider + `.padding(.top, 20)`)
- Paste success transform → Task 2 `pasteRow` + `applyClipboard` with cancellable task
- Auto-focus: create only → Task 2 `.onAppear`
- No `Image(systemName:)` in Sheets.swift → Task 3
- Reduced-motion → covered by iOS defaults for springs + `.contentTransition(.numericText())` identity
- Build passes → Task 4 Step 1
- Simulator walkthrough → Task 4 Step 2

**Placeholder scan:** None. All code is complete and copy-paste ready.

**Type consistency:** `TrialPreviewRow(name:domain:endDate:amount:)` signature in Task 1 matches call site in Task 2 exactly. `Preset` labels (`7d/14d/30d/1y`) consistent between Task 2 struct and PR description.

**Known deviation from spec:** Spec Risk #4 proposes debouncing `BrandDirectory.logoDomain` in a 250ms Task.sleep. Plan does NOT debounce — the lookup is a dictionary traversal (<1ms), no disk I/O unless `LogoService` caches get involved downstream. If simulator walkthrough shows lag, add debounce in a follow-up.

**Known deviation 2:** Plan uses `Haptics.play(.primaryTap)` for preset taps and paste tap because there is no `.selection` case. This matches existing usage in the current codebase and is the documented light-tick haptic.

---

## Risks captured in plan

1. Phosphor icon name casing (Ph.checkCircle vs Ph.CheckCircle) — Task 2 Step 3 has fallback grep
2. `AnyView` wrapping Phosphor icons in `fieldRow` — intentional type erasure for clean builder signature
3. `.contentTransition(.numericText())` on `AccentPill` — applied externally; if it doesn't animate, move into pill internals in follow-up
4. Paste task leak — Task 2 `.onDisappear` cancels `pasteResetTask`
