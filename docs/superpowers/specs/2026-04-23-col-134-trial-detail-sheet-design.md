# COL-134 — TrialDetailSheet complete overhaul (edit + create)

**Linear:** https://linear.app/colehollander/issue/COL-134
**Branch:** `colehollander10/col-134-v2-design-14-trialdetailsheet-complete-overhaul-edit-create`
**Date:** 2026-04-23

---

## Goal

Rewrite `TrialDetailSheet` in `Finn/Sheets.swift` so the most-used sheet in the app feels crafted — on the level of Copilot Money, Flighty, Sofa. Manual entry IS the product; the sheet has to stop reading like a stock SwiftUI Form.

Applies to both create mode (`trial: nil`) and edit mode (`trial: Trial`). Not a tweak — a full rewrite.

---

## Non-goals

- No SwiftData schema changes
- No edits to HomeView, TrialsView, SettingsView, OnboardingView
- No new Swift Package dependencies
- No changes to `CancelGuide` / `CancelGuideResolver` / `CancelFlowSheet` / `ManualTrialExtractor` (same file, different types, leave alone)
- No new backend/network features
- No redesign of the save-success → card-rises-into-list choreography (DESIGN.md already specifies it; reuse existing flow)

---

## Final structure (top to bottom)

```
┌────────────────────────────────────────┐
│ ─── (drag indicator, iOS native) ───   │
│                                        │
│  Cancel                                │  ← toolbar top-left only
│                                        │
│  NEW TRIAL                             │  ← SectionLabel
│  Add Trial                             │  ← 28pt bold rounded, in-scroll (not toolbar)
│  ─────────────────────────             │  ← HairlineDivider
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ [🏷] Cursor Pro       14D LEFT   │  │  ← compact preview row (~72pt)
│  │      Ends May 7 · $20.00         │  │    live-updates as user types
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ 📋  Paste from clipboard         │  │  ← paste row (create mode only)
│  │ ────────────────────────────     │  │
│  │ 💼  Service                      │  │  ← Phosphor briefcase
│  │     Cursor Pro                   │  │
│  │ ────────────────────────────     │  │
│  │ 📅  Trial ends                   │  │  ← Phosphor calendar
│  │     May 7, 2026                  │  │
│  │     [ 7d ] [ 14d ] [ 30d ] [1y]  │  │  ← preset chips, no Custom
│  │ ────────────────────────────     │  │
│  │ 💲  Charge amount                │  │  ← Phosphor currency-dollar
│  │     $  20.00                     │  │  ← monospacedDigit rounded
│  └──────────────────────────────────┘  │  ← single SurfaceCard, radius 24
│                                        │
│  ┌──────────────────────────────────┐  │
│  │            Save                  │  │  ← PrimaryButton full-width
│  └──────────────────────────────────┘  │    lavender fill, dark text
│                                        │
│  ─────────────────────────             │  ← HairlineDivider (edit mode only)
│  ✓ Mark as cancelled                   │  ← muted text button (edit mode only)
│                                        │    Phosphor check-circle, secondaryText
└────────────────────────────────────────┘
```

---

## Component-by-component spec

### 1. Sheet chrome

- `.presentationDetents([.large])` — keep, no half-sheet
- `.presentationDragIndicator(.visible)` — **ADD** (currently missing)
- `NavigationStack { ScreenFrame { ScrollView { VStack … } } }` — keep
- **Remove** the `ToolbarItem(placement: .principal)` Text title. Move to in-scroll header.
- Keep `ToolbarItem(placement: .topBarLeading)` "Cancel" button as-is.

### 2. In-scroll header

Replaces the current toolbar-principal title. Inside the VStack, first content after `.padding(.top, 12)`:

```swift
VStack(alignment: .leading, spacing: 6) {
    SectionLabel(title: trial == nil ? "New trial" : "Edit trial")
    Text(trial == nil ? "Add Trial" : "Edit Trial")
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(FinnTheme.primaryText)
}
HairlineDivider()
```

### 3. Compact preview row (new `TrialPreviewRow` primitive)

**Extract to `Finn/GlassComponents.swift`** as a reusable primitive. 72pt tall. Live-updates from the sheet's `@State` values.

Layout:
```
HStack(spacing: 12):
  ServiceIcon(name: previewName, domain: previewDomain, size: 40)
  VStack(alignment: .leading, spacing: 4):
    Text(previewName)              // 17pt semibold rounded, primaryText
    Text(previewSubtitle)          // 12pt medium, secondaryText, monospacedDigit
                                   // format: "Ends {date} · {amount}"
  Spacer()
  AccentPill(text: daysLeftText, color: urgencyColor)
    .breathing(days <= 3)
```

**Derived values** (computed in sheet body from `@State`):
- `previewName`: `serviceName.trimmed()`, fallback `"Your trial"` when empty
- `previewDomain`: `BrandDirectory.logoDomain(for:serviceName)` — resolves live
- `previewSubtitle`:
  - empty state: `"Set an end date"`
  - with date, no amount: `"Ends {formatted}"`
  - with both: `"Ends {formatted} · {formatUSD(amount)}"`
- `daysLeftText`: `"{N}D LEFT"`, or `"TODAY"` if days ≤ 0
- `urgencyColor`: `FinnTheme.urgencyColor(daysLeft:)`

**Animations:**
- `.contentTransition(.numericText())` on daysLeftText + amount text
- Preset chip tap changes both; the numbers flip in place

**Why extract:** 72pt compact preview is reusable for future confirm-new-trial flows. Extraction keeps `Sheets.swift` from bloating further (currently 578 lines; target post-rewrite: ≤ 500).

### 4. Fields SurfaceCard

One `SurfaceCard(padding: 0)` containing the paste row (create mode) + 3 fields, divided by `HairlineDivider` between rows (matching DESIGN.md's SurfaceCard rule).

**Phosphor API (verified from existing `Finn/HomeView.swift` usage):**

```swift
// Usage pattern — icon is a View, weight is a property, color via .color() modifier
Ph.briefcase.regular
    .color(FinnTheme.tertiaryText)
    .frame(width: 22, height: 22)
```

All icons go on `.regular` weight for field affordances. The Phosphor variant enum is accessed via property syntax: `.thin`, `.light`, `.regular`, `.bold`, `.fill`, `.duotone`. Use `.color()` not `.foregroundStyle()`.

**Row template** — new private `SheetFieldRow<Content: View>` helper inside `Sheets.swift`:

```swift
HStack(alignment: .top, spacing: 14):
  icon                                           // Ph.{name}.regular, sized 22×22
    .color(FinnTheme.tertiaryText)
    .frame(width: 24, height: 22, alignment: .center)
    .padding(.top, 2)
  VStack(alignment: .leading, spacing: 6):
    Text(label.uppercased())                     // 10pt semibold, tracking 1.8
      .foregroundStyle(FinnTheme.secondaryText)
    content()                                    // 17pt medium, primaryText
.padding(.horizontal, 16)
.padding(.vertical, 14)
```

**Field 1 — Paste (create mode only):** Special case, no label. Pure tap target.
- Default state: `Ph.clipboardText.regular` + `Text("Paste from clipboard")` 15pt medium primaryText
- Post-paste (3s): `Ph.checkCircle.fill` + `Text("Filled: service, end date, amount")` 15pt medium in `FinnTheme.accent`
- After 3s: auto-fades back to default state via `Task.sleep` + `withAnimation`, cancellable `@State` task handle
- Tapping invokes existing `applyClipboard()` logic (unchanged)
- `Haptics.play(.selection)` on tap

**Field 2 — Service:**
- Icon: `Ph.briefcase.regular`
- Content: `TextField("Cursor Pro", text: $serviceName)` .textInputAutocapitalization(.words) .focused($focused)

**Field 3 — Trial ends:**
- Icon: `Ph.calendar.regular`
- Content:
  ```
  VStack(alignment: .leading, spacing: 12):
    DatePicker("", selection: $trialEndDate, displayedComponents: .date)
      .labelsHidden()
      .colorScheme(.dark)
    presetRow                                    // preset chips
  ```
- `.onChange(of: trialEndDate)`: if not applyingPreset, clear selectedPreset (unchanged logic)

**Field 4 — Charge amount:**
- Icon: `Ph.currencyDollar.regular`
- Content:
  ```
  HStack(spacing: 4):
    Text("$")                                    // 20pt semibold rounded, tertiaryText
    TextField("20.00", text: $chargeAmountText)
      .keyboardType(.decimalPad)
      .monospacedDigit()
      .font(.system(size: 20, weight: .medium, design: .rounded))
  ```

### 5. Preset chip row (no Custom chip)

4 chips: `7d`, `14d`, `30d`, `1y`. NO "Custom" chip — absence of selection is not a state that needs a label.

```swift
ScrollView(.horizontal, showsIndicators: false):
  HStack(spacing: 8):
    ForEach(Preset.allCases) { preset in
      Button { … } label: {
        Text(preset.label)
          .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(isSelected ? FinnTheme.background : FinnTheme.secondaryText)
          .padding(.horizontal, 14).padding(.vertical, 8)
          .background(
            Capsule().fill(
              isSelected ? FinnTheme.accent : FinnTheme.elevated
            )
          )
          .overlay(
            Capsule().strokeBorder(
              isSelected ? .clear : FinnTheme.divider, lineWidth: 1
            )
          )
      }
      .buttonStyle(.plain)
    }
```

**Selected state:**
- Fill: `FinnTheme.accent` (lavender)
- Text: `FinnTheme.background` (dark — matches PrimaryButton's WCAG-passing combo)
- No border

**Unselected state:**
- Fill: `FinnTheme.elevated` (charcoal, muted)
- Text: `FinnTheme.secondaryText`
- 1pt `FinnTheme.divider` border

**Tap:** `.selection` haptic, 150ms `.easeInOut` transition on fill color.

**Preset enum unchanged:** `sevenDays=7, fourteenDays=14, thirtyDays=30, oneYear=365`. Labels: `"7d", "14d", "30d", "1y"` (lowercase, tighter than current `"7 days"`).

### 6. Save button

```swift
Button { Haptics.play(.save); save() } label: {
    Text("Save").frame(maxWidth: .infinity)
}
.buttonStyle(PrimaryButton())
.disabled(serviceName.trimmed().isEmpty)
.padding(.top, 16)
```

Lavender fill, dark text (existing PrimaryButton behavior — don't modify the style itself).

### 7. Mark as cancelled (edit mode only)

```swift
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
                    .color(FinnTheme.secondaryText)
                    .frame(width: 16, height: 16)
                Text("Mark as cancelled")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(FinnTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    .padding(.top, 20)
}
```

Muted text button, NOT destructive red. Reason: marking cancelled is the win state of the app ("I handled it"), not a warning. Destructive-red treatment would misread the emotional register.

### 8. Motion

Per DESIGN.md § Motion Choreography:

- **Sheet present:** spring `response: 0.36, dampingFraction: 0.84`, content fades in at +80ms — already the iOS default for sheets, no custom code needed.
- **Preview row live-updates:** `.contentTransition(.numericText())` on daysLeft text and amount text. Numbers flip in place.
- **Preset chip selected-state change:** 150ms `.easeInOut` on fill color.
- **Paste success transform:** 200ms `.spring(response: 0.32, dampingFraction: 0.86)` on the icon+text crossfade.
- **Save success:** existing `dismiss()` path, don't reinvent. (The card-rises-into-list choreography in DESIGN.md is for HomeView; not this ticket's scope.)
- **Reduced motion:** all springs → instant, `.contentTransition(.numericText())` stays (it's identity under reduced motion).

### 9. Haptics

Unchanged except for additions:
- Sheet present: `.impactLight` (system default, no code)
- Paste button tap: **ADD** `Haptics.play(.selection)` on success path
- Preset chip tap: `Haptics.play(.primaryTap)` (keep existing — already `.selection`-equivalent)
- Save tap: `Haptics.play(.save)` (keep)
- Mark cancelled tap: `Haptics.play(.markCanceled)` (keep)

---

## Phosphor migration scope (bundled into this ticket)

Per Cole's instruction (2026-04-23): Phosphor EVERYWHERE, zero `Image(systemName:)` in Finn app code (excluding OS-required places like toolbar chevron).

Audit and migrate any `Image(systemName:)` found in:
- `Finn/Sheets.swift` (known: `doc.on.clipboard` line 307)
- All Finn/*.swift

Out of scope for this ticket (flag but don't migrate):
- `Finn/OnboardingView.swift` — will be re-touched in later motion ticket; don't churn twice
- Swift packages under `Packages/` — those are isolated, separate tickets

If the audit finds more than ~5 unrelated SF Symbol usages outside `Sheets.swift`, file a follow-up ticket instead of bundling. Keep PR scope tight.

---

## Acceptance criteria

- [ ] Drag indicator visible on sheet
- [ ] In-scroll header replaces toolbar principal title
- [ ] `TrialPreviewRow` extracted to `GlassComponents.swift`
- [ ] Preview row updates live as user types in all 3 fields
- [ ] Preview row empty states render correctly (no name, no date, no amount)
- [ ] Preview row days-left pill uses correct urgency color + breathing ≤ 3 days
- [ ] Fields live in ONE `SurfaceCard` with `HairlineDivider` between
- [ ] All field icons are Phosphor (briefcase / calendar / currency-dollar / clipboard-text / check-circle)
- [ ] Amount field shows `$` prefix, uses `.monospacedDigit()` with rounded design
- [ ] Preset chips: no Custom chip, lavender selected, charcoal unselected
- [ ] Preset chip labels: `7d`, `14d`, `30d`, `1y` (lowercase, tight)
- [ ] Save = PrimaryButton (lavender fill, dark text), full-width
- [ ] Mark as cancelled = muted text-only button with Phosphor check-circle (edit mode only)
- [ ] Save and Mark as cancelled separated by HairlineDivider + padding (no accidental-tap risk)
- [ ] Paste button transforms to success banner for 3s after successful paste
- [ ] Auto-focus on Service field in create mode, no auto-focus in edit mode
- [ ] No `Image(systemName:)` in `Sheets.swift` after migration
- [ ] Reduced-motion respected (springs instant, numericText stays)
- [ ] `xcodebuild` passes for Finn target
- [ ] Simulator walkthrough confirms "crafted sheet, not form" feel

---

## Files to modify

- `Finn/Sheets.swift` — rewrite `TrialDetailSheet` body (lines 237–522), keep everything else untouched
- `Finn/GlassComponents.swift` — add `TrialPreviewRow` primitive

## Files NOT to modify

- `Finn/HomeView.swift`
- `Finn/TrialsView.swift`
- `Finn/SettingsView.swift`
- `Finn/OnboardingView.swift`
- `Finn/PrimaryAddButton.swift`
- Any file under `Packages/`
- `DESIGN.md`

---

## Routing plan (for writing-plans / route)

| Subtask | Scope | Worker | Model |
|---|---|---|---|
| 1. Extract `TrialPreviewRow` primitive to `GlassComponents.swift` | New view, ~60 LOC, pure UI | Cursor | `composer-2-fast` |
| 2. Rewrite `TrialDetailSheet` body per spec | UI-heavy, ~300 LOC, touches field layout + preset chips + save/cancelled | Cursor | `composer-2-fast` |
| 3. Phosphor audit + migrate any remaining `Image(systemName:)` in `Sheets.swift` | Find/replace, ~5-15 LOC | Claude inline | — |
| 4. `xcodebuild` + simulator walkthrough | Verification | Claude inline | — |

Subtasks 1 and 2 have file overlap (2 imports what 1 exports). Execute sequentially: 1 first, then 2.

No Codex in this plan — this is entirely UI work, which per route skill belongs with Cursor. No business-logic changes, no tests (manual entry UI is verified in simulator walkthrough per Finn's existing testing rhythm).

---

## Risks

1. **Phosphor API** — verified: `Ph.{iconName}.{weight}` is a View; apply `.color(...)` then `.frame(width:height:)`. Weight variants: `.thin`, `.light`, `.regular`, `.bold`, `.fill`, `.duotone`. Field affordances use `.regular`.
2. **Auto-fade on paste success banner** — `Task.sleep` + `withAnimation` can leak if the sheet dismisses mid-timer. Store the task as `@State var pasteResetTask: Task<Void, Never>?`, cancel it on new paste and on `onDisappear`.
3. **`.contentTransition(.numericText())` inside `AccentPill`** — may not animate if AccentPill uses a non-Text container. Implementer must read `AccentPill` in `GlassComponents.swift` before wiring; if it already contains a `Text` at its root, the modifier should work. Fallback: apply `.contentTransition` on the preview's own `daysLeftText` Text before it goes into AccentPill.
4. **Preview domain resolution** — `BrandDirectory.logoDomain(for:senderDomain:)` runs in `save()`. Running on every keystroke could hit disk. Mitigation: wrap in `.onChange(of: serviceName)` with 250ms debounce via `Task.sleep`, not on every render.

---

## Out of scope (separate tickets)

- COL-138 — FAB visual overhaul
- COL-131 — Motion pass
- COL-132 — Fox mascot
- COL-139 — Settings polish

---

## References

- `DESIGN.md` § Component Library, § Typography, § Motion Choreography, § Haptics
- `Finn/GlassComponents.swift` — existing primitives (SurfaceCard, FlagshipCard, AccentPill, PhosphorIcon)
- `Finn/HomeView.swift` lines 107–174 — FlagshipCard usage pattern (preview row mirrors this, compact)
- Previous ticket: COL-126 (TrialsView grouped-rows pattern — same SurfaceCard+HairlineDivider structure)
- Previous ticket: COL-133 (Mark cancelled action on TrialDetailSheet — preserves destructive action, this ticket changes its visual register)
