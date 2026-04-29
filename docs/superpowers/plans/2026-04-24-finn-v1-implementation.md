---
title: Finn v1 Implementation Plan
date: 2026-04-24
tags: [project, finn, ios, swiftui, implementation-plan, app-store]
type: implementation-plan
status: in-progress
spec: "[[Finn v1 Launch Design]]"
related: [[Finn]], [[Finn v1 Launch Design]]
description: "Master plan + sub-plans for shipping Finn v1 to the App Store. Per-sub-plan detailed task breakdowns lived as separate docs in this folder."
---

# Finn v1 Implementation Plan — Master

> [!important] Reconciled 2026-04-29 against [[Finn Brand Foundation]]
> Sub-plans implementing paw-print confetti, fox moods beyond Neutral/Concerned/Sleeping, and fox in banned surfaces (HuntSheet, Calendar header, HomeView flagship card, etc.) are marked REMOVED or REMAPPED below. The remaining sub-plans are valid as written. When this plan conflicts with [[Finn Brand Foundation]], Brand Foundation wins.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement each sub-plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Finn v1 to the App Store with the full feature set from [[Finn v1 Launch Design]] — ~~Duolingo-art mascot with 7 emotional states~~ quiet vector mascot with **3 moods only (Neutral / Concerned / Sleeping)** per [[Finn Brand Foundation]] §3, screenshot-based hunt flow, red alert calendar, 4 intelligence features (hybrid heuristic + Apple Intelligence), contextual paywall, and the full UI/UX doctrine applied to every surface.

**Architecture:** Extend the existing 6-package Subly app with 4 new Swift packages (`MascotKit`, `VisionCapture`, `IntelligenceCore`, `BillingCalendar`) and an `Entitlements` lightweight module in the app target. Schema extended via `@Attribute(originalName:)` lightweight migration — no `VersionedSchema` pre-TestFlight. Screens get audited + rebuilt against the UI/UX doctrine (grid layouts, one action, hierarchy, instant feedback, motion-with-purpose).

**Tech Stack:** SwiftUI, SwiftData, StoreKit 2, VisionKit (`VNRecognizeTextRequest`), Apple Intelligence / Foundation Models (`SystemLanguageModel` + `LanguageModelSession`), Core ML, `PhaseAnimator` + `TimelineView` for motion, ~~`Canvas` for paw print confetti~~ **REMOVED (Brand Foundation 2026-04-29: confetti is banned)**, `xcodegen` for project file regeneration.

---

## Execution order and dependencies

Each sub-plan is a separate Linear ticket + PR. Execute **strictly in order** where dependencies exist. Where independent, they can parallelize, but stay careful — two parallel Cursor/Codex streams in the same codebase generate merge conflicts fast.

```
1. Rename Subly → Finn             [mechanical, ~45 min]           ────┐
2. P10 HIGH audit fixes             [blocks launch, 1-2h]               │  MUST be first
3. P7 Home rebuild (3-state adaptive) [COL-147 upgrade]                 │
                                                                        ▼
4. MascotKit package + ~~7 states~~ **3 moods (Neutral/Concerned/Sleeping)**  ────┐
5. SubscriptionStore schema expansion                               │  foundations
                                                                    ▼
6. VisionCapture + HuntSheet (flagship)      [depends on 4]  ────┐
7. IntelligenceCore + 4 features             [depends on 5]       │  depends on foundations
8. Entitlements + Finn Pro paywall           [depends on 7]       │
9. BillingCalendar + View                    [depends on 4]       │
10. SavingsView + kill celebration           [depends on 4]       │
11. Onboarding rewrite                        [depends on 4]       │
12. Settings rewrite                          [depends on 7, 8]    │
13. Subscriptions + Trials grid redesign     [depends on 4]       │
14. Detail sheets unified + Finn's-take pill [depends on 7]       │
                                                                    ▼
15. App icon + launch screen     [blocks on illustrator]     ────┐
16. App Store submission prep                                      │  launch gate
```

**Dependency summary:**
- Sub-plans 4 + 5 are strict prerequisites for almost everything after.
- Sub-plans 6–14 can run in some parallel combinations once 4 + 5 are done, but keep it to ≤2 parallel branches at once to avoid merge hell.
- Sub-plans 15 + 16 are the final launch gate.

---

## Sub-plan index

Each sub-plan is a separate document in this folder. Short version here; full detail in the linked docs as they're written.

### 1. [[Finn Plan 01 — Rename Subly to Finn]] ✅ written

- Mechanical rename across bundleIdentifier, Info.plist, Xcode project, CLAUDE.md, README.md, every Swift file that references "Subly" in type or string form.
- `SublyTheme` → `FinnTheme`, `SublyApp` → `FinnApp`, display-name and bundle-id updates.
- Preserves all on-device SwiftData (bundle id change *would* wipe data on real devices, so we keep `com.colehollander.subly` as the bundleIdentifier and only rename the display name + internal types — flagged in the sub-plan).

### 2. Finn Plan 02 — P10 HIGH audit fixes [stub]

From `docs/audits/2026-04-24-p10-audit.md`. 4 same-pattern findings:

1. `AddSubscriptionSheet.swift:264-280` — add `modelContext.save()` + `TrialAlertCoordinator.replanAll()` after manual sub create.
2. `SettingsView.swift:225-240` — same, after StoreKit import.
3. `NotificationDelegate.swift:62-76` + `ContentView.swift:119-123` + `HomeView.swift:286-290` + `SubscriptionsView.swift:81-93` — route notification taps by entry type (sub-renewal alerts open Subscriptions tab + detail sheet; trial alerts stay on Home).
4. `SubscriptionsView.swift:293-309` — replan schedule after edit/delete.

Existing ticket: COL-150. Adjust scope to "apply the 4 HIGH findings" + land.

### 3. Finn Plan 03 — HomeView 3-state adaptive rebuild [stub]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> HomeView's flagship card and active trial rows are **banned fox surfaces**. State 2 and State 3 fox usages below are REMOVED. State 1 (empty state) is allowed but the pose remaps to **Sleeping** (already correct). State 3's "Charges in 1 day" surface may show a small **Concerned** fox (allowed exception per Brand Foundation §3).

Extends existing ticket **COL-147** (was: P7 empty state).

New scope:
- **State 1 (quiet):** Sleeping Finn empty state + $X caught pill if > $0. FAB. Covers the original COL-147 goal.
- **State 2 (watching):** ~~`.watching` Finn card~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: HomeView flagship card)** + ≤7-day trial scope + "Upcoming bills" mini-row. No gradient wash, no spend hero.
- **State 3 (urgent):** ~~`.nervous` Finn~~ **REMAPPED → Concerned mood (only on "Charges in 1 day" surfaces per Brand Foundation §3 allowed exception)** + single hero urgent card. Other content receded.

State is derived from `(activeTrials, upcomingBillsWithin48h)` and applied at the top of `HomeView`.

### 4. Finn Plan 04 — MascotKit package [stub — high-value full plan candidate]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> The 7-state enum is **REMAPPED to 3 states (Neutral / Concerned / Sleeping)**. `PawPrintConfetti` is **REMOVED** (confetti banned). Per-state emotional-beat loops are REMOVED — Brand Foundation §3 says "States are swapped, not morphed. No animated transitions between states." The `PawPrintTrail` and the `.color()` rules require human review (see flag below).

**New package:** `Packages/MascotKit/`.

Deliverables:
- ~~`FoxState` 7-case enum (`.sleeping`, `.sitting`, `.watching`, `.nervous`, `.hunting`, `.celebrating`, `.proud`).~~ **REMAPPED:** `FoxState` 3-case enum (`.neutral`, `.concerned`, `.sleeping`).
  - `.sitting` → **`.neutral`**
  - `.proud`, `.celebrating`, `.curious`, `.watching` → **REMOVED**
  - `.nervous`, `.hunting` → **FLAGGED-FOR-REVIEW** (see callout below)
- `FoxView(state:)` — SwiftUI wrapper, asset catalog inside the package, `PhaseAnimator` spring tuning (response 0.35, damping 0.7).
- ~~Per-state emotional-beat loops (watch-tap, celebrating-jump, hunting-tail-flick) via `TimelineView`. Start/stop with state activation.~~ **REMOVED (Brand Foundation 2026-04-29: states swap, not morph; no animated transitions between states).**
- ~~`PawPrintConfetti(trigger:)` — SwiftUI `Canvas`-based particle system. 20–30 paw prints, Vulpine/cream/soft-blue, physics-simulated falling.~~ **REMOVED (Brand Foundation 2026-04-29: confetti is banned).**
- `PawPrintTrail(count:)` — static walking trail view used in onboarding, trials empty, settings footer. **FLAGGED-FOR-REVIEW** (see callout below).
- **Reduce Motion gating:** all motion primitives check `@Environment(\.accessibilityReduceMotion)`. Pose swaps stay, loops strip, ~~confetti → static paw print~~ **(confetti row REMOVED per above)**.
- Package tests target: **3**.

> [!question] Flagged for human review
> 1. `.nervous` and `.hunting` — Brand Foundation §3 enumerates only `.proud`/`.celebrating`/`.curious`/`.watching` for removal and `.sitting` for remap. `.nervous` looks like a candidate for `.concerned`, and `.hunting` looks like REMOVED, but the task constraint says don't introduce new design decisions. Cole to confirm.
> 2. `PawPrintTrail` (static, decorative, not particle/confetti) — Brand Foundation bans "decorative motion that doesn't serve user comprehension" but a static trail isn't motion. Allowed surfaces (onboarding, settings footer, empty states) match — but is a paw-trail compatible with "Quiet"? Cole to confirm.

Placeholder raster assets allowed at first (current `fox-sitting.pdf` + `fox-sleeping.pdf` from COL-146). Final vector assets land in sub-plan 15 (icon + illustration).

### 5. Finn Plan 05 — SubscriptionStore schema expansion [stub]

Modify `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Trial.swift`:

```swift
@Model final class Trial {
    // existing properties …

    // NEW — all nullable, lightweight migration
    var lastUsedAt: Date?
    var usageConfidence: Double?
    var sourceHint: SourceHint = .manual   // default for existing rows
    // appleOriginalTransactionID: String? — already landed in PR #36
}

public enum SourceHint: String, Codable {
    case screenshot, storekit, manual, suggested
}

@Model final class PredictiveCandidate {
    var merchant: String
    var suggestedBecause: String
    var dismissedAt: Date?
    var confirmedAt: Date?
    var suggestedEntryType: EntryType

    init(merchant: String, suggestedBecause: String, suggestedEntryType: EntryType) {
        self.merchant = merchant
        self.suggestedBecause = suggestedBecause
        self.suggestedEntryType = suggestedEntryType
    }
}
```

Add schema version bump to `SublyApp.swift` `ModelContainer` (stays lightweight-only, no `VersionedSchema`).

Package tests target: **existing 12 + 4 new (sourceHint default, PredictiveCandidate CRUD, lastUsedAt query, usageConfidence clamping)** = **16**.

### 6. Finn Plan 06 — VisionCapture + HuntSheet [stub — high-value full plan candidate]

**New package:** `Packages/VisionCapture/`.

Deliverables:
- `VisionCapture.extract(image:tier:)` — returns `CandidateEntry { merchant, amount, chargeDate?, billingCycle?, entryType, confidence, sourceHint: .screenshot }`.
- Uses `VNRecognizeTextRequest` for OCR. Routes text to `TrialParsingCore.classifyText` (free) OR `IntelligenceCore.vision.enhance` (Pro).
- Pure function in/out. No UI, no SwiftData dep.
- Package tests target: **8** (OCR-to-text, heuristic candidate, FM candidate mock, low-confidence, no-catch, error-in-OCR, empty image, routing by tier).

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> HuntSheet is a **flagship interaction** but not an allowed fox surface — it's a data-dense, money-touching capture flow. **All fox presence inside HuntSheet is REMOVED**, including the "pounce" framing and "the hunt" micro-interaction motion spec. The sheet itself remains; the fox inside it does not.

**App-target view:** `Subly/Hunt/HuntSheet.swift`. Full-screen sheet. Entry cards + paste fallback + manual fallback. ~~Pounce → paw-print progress → success/low-conf/no-catch paths.~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: HuntSheet is a data-dense capture flow; fox not allowed inside it).** Section 3.6 is the screen spec. ~~Section 2 "the hunt" micro-interaction is the motion spec.~~ **REMOVED (banned surface per Brand Foundation 2026-04-29).**

> [!question] Flagged for human review
> "Paw-print progress" indicator is decorative and not a fox visual per se — but it lives inside a banned surface (HuntSheet), so it's removed by surface-banning. Sheet still needs *a* progress indicator — Cole to spec a neutral one.

**FAB routing:** existing `AddEntryRouterSheet` adds a third option ~~"Hunt a trial"~~ **FLAGGED-FOR-REVIEW: copy update — "Hunt a trial" leans on the fox/character framing the Brand Foundation pulls back from. Suggest neutral copy like "Capture from screenshot" — Cole to confirm.** above Trial/Subscription. Trials empty state also wires to HuntSheet directly.

### 7. Finn Plan 07 — IntelligenceCore + 4 features [stub — high-value full plan candidate]

**New package:** `Packages/IntelligenceCore/`.

Shape:

```swift
public struct IntelligenceCore {
    public let smartReminders: SmartRemindersEngine
    public let usageDetection: UsageDetectionEngine
    public let predictiveID: PredictiveIDEngine
    public let vision: VisionEnhancer

    public init(tier: SubscriptionTier, ai: AppleIntelligenceAvailability)
}
```

Each engine has `.heuristic` and `.foundationModels` paths. Routing: `if tier == .pro && ai.available { fm } else { heuristic }`. FM failure → silent heuristic fallback + `OSLog`.

Sub-features (each is its own ~40-step TDD block in the full sub-plan):

- 7a. Smart reminders (free: rolling 10-event window heuristic; Pro: FM schedule).
- 7b. Usage detection (free: monthly explicit nudge + `UNNotification` inline actions; Pro: inferred from in-app interaction pattern).
- 7c. Predictive subscription ID (free: `SubscriptionCorrelations.json` rule table + dismissible Subscriptions-tab card; Pro: FM ranked suggestions + FM receipt/screenshot → sub extraction).
- 7d. Substrate + availability + routing + `LanguageModelSession` lazy/memoized/30s-idle-teardown.

Package tests target: **12**.

### 8. Finn Plan 08 — Entitlements + Finn Pro + paywall + entry caps [stub]

**New module (in app target):** `Subly/Entitlements/`.

- `SubscriptionTier { .free, .pro }` — StoreKit 2 via `Transaction.currentEntitlements` + `Transaction.updates` listener.
- `AppleIntelligenceAvailability` — `SystemLanguageModel.default.availability` at launch + scene `.active`.
- `AppEntitlements` observable singleton. Views + `IntelligenceCore` read from this.

**Entry caps:**
- At sub #11 add, show paywall sheet blocking save. Clean dismiss returns to the add flow.
- At trial #4 add, same.
- Paywall copy + layout spec is its own mini-design iteration inside this sub-plan.

**Finn Pro Settings section:**
- Free: "Manage" button → paywall sheet.
- Pro: "You're a Pro. Manage subscription." → App Store subscription management deep link.

**Contextual triggers** (in addition to caps):
- 3rd HuntSheet open in a single session → paywall nudge (dismissible, once per session).
- Day 3+ of app use with no Pro → soft in-context banner in Subscriptions header.

### 9. Finn Plan 09 — BillingCalendar + BillingCalendarView [stub]

**New package:** `Packages/BillingCalendar/`.

Pure logic returns `[CalendarDay]` with `{ date, events: [BillEvent], urgency: .quiet | .normal | .alert }`. `alert` assigned via `IntelligenceCore.usageDetection.isInactive(trial:) == true` OR bill within 48h over threshold (default $10).

**App-target view:** `Subly/Calendar/BillingCalendarView.swift`. Full-screen sheet. Month grid, 7-col. Tap day → bottom sheet with per-item actions. Today's cell Vulpine outline + single pulse on open. Red-alert days glow. Month nav horizontal swipe.

Reached from Home "Upcoming bills" row OR Subscriptions header calendar icon.

### 10. Finn Plan 10 — SavingsView + ~~kill celebration~~ cancel confirmation [stub]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §1 + §3
> "Kill celebration" framing → **"cancel confirmation"** framing. Confetti, `.proud`, `.celebrating`, and any celebratory motion are **REMOVED** (Brand Foundation §1: "Confetti or celebration animations on cancel" is explicitly ruled out). SavingsView itself is data-dense and money-adjacent — **fox is REMOVED from this view per Brand Foundation §3 banned surfaces**.

**New view:** `Subly/Savings/SavingsView.swift`.

- Top: massive "$247 caught" numeric-roll transition. Vulpine orange.
- ~~Finn `.proud` (or `.celebrating` if < $100).~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: SavingsView is data-dense and money-adjacent; `.proud`/`.celebrating` removed per mood-state remap).**
- Last 5 catches as `SurfaceCard` list.
- "See all catches" → history view (simple list).

~~**Kill celebration wire-up (from Section 2):**~~ **REMAPPED → "Cancel confirmation wire-up":**
- Integrated into `CancelFlowSheet` success path + `TrialDetailSheet` "Mark as cancelled" path + HuntSheet post-catch-when-already-ending path.
- ~~Uses `MascotKit.PawPrintConfetti(trigger:)` + `.celebrating` Finn + numeric-roll on savings total + haptic `.markCanceled`.~~ **REMOVED (Brand Foundation 2026-04-29: confetti banned; `.celebrating` mood removed; cancel is a money-moving destructive action — banned fox surface).** Replacement: numeric-roll on savings total + haptic `.markCanceled` only. No fox, no confetti.
- ~~Reduce Motion: confetti → static paw print, numeric roll → crossfade.~~ **REMAPPED:** Reduce Motion: numeric roll → crossfade. (Confetti row REMOVED per above.)

Savings total derivation: sum of `(amount × billingCycle.monthlyMultiplier)` across all `Trial` rows where `status == .cancelled` (trials) OR user-flagged "I stopped using this" from sub cancel.

### 11. Finn Plan 11 — Onboarding rewrite [stub]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> Onboarding is an **allowed fox surface** (one appearance per screen, max). Poses are REMAPPED to the 3 allowed moods. Step 2's `.hunting` and Step 3's `.watching` are FLAGGED-FOR-REVIEW. `.celebrating` (Step 4) is REMOVED (mood not in v1). Step 4's "3s `.watching` Finn pointing at the FAB" lands on HomeView's flagship area and is REMOVED (banned surface). Paw-print trail on step 4 is FLAGGED (decorative, not banned outright).

Modify `Subly/OnboardingView.swift`. Same 4 steps, new copy + Finn poses per Section 3.1:

| Step | ~~Pose~~ Mood | Headline | Action |
|---|---|---|---|
| 1 | ~~`.sitting`~~ → **`.neutral`** | "Never get charged for a trial you forgot." | "Meet Finn →" |
| 2 | ~~`.hunting`~~ **FLAGGED-FOR-REVIEW** (not in 3-mood set; Cole to confirm `.neutral` substitute) | "Screenshot any trial. Finn handles the rest." | "How it works →" |
| 3 | ~~`.watching`~~ **FLAGGED-FOR-REVIEW** (not in 3-mood set; Cole to confirm `.neutral` or `.concerned` substitute) | "You'll hear from him before you're charged." | "Sounds good →" |
| 4 | ~~`.celebrating`~~ **REMOVED (mood not in v1 per Brand Foundation §3)** — substitute `.neutral` | "You're in control now." + Finn Pro teaser line | "Start hunting →" |

~~Step 4 lands on Home with a 3s `.watching` Finn pointing at the FAB.~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: HomeView flagship is fox-banned; on-Home active fox is not allowed).** Paw print trail walks across bottom on step 4. **FLAGGED-FOR-REVIEW** (decorative paw print on an allowed surface — Cole to confirm).

No paywall in onboarding. Single line in step 4: *"Finn is free. Finn Pro is even better — more on that later."*

### 12. Finn Plan 12 — Settings rewrite [stub]

Extends existing ticket **COL-139**.

New section order:
1. Notifications (existing, copy audit)
2. **Intelligence** (new — master on/off + per-feature toggles: smart reminders, usage nudges, predictive suggestions)
3. **Finn Pro** (new — free: "Manage" → paywall; Pro: "Manage subscription" → App Store)
4. Data (existing)
5. About (existing)

Paw print elements:
- 2 of 5 section dividers use a centered paw print (Intelligence + Finn Pro headers). **FLAGGED-FOR-REVIEW** (decorative paw prints in non-allowed-surface section dividers — Brand Foundation §3 doesn't address these explicitly; Cole to confirm).
- "About Finn" footer: static paw print trail → version number. (About / Settings footer is an allowed fox surface per Brand Foundation §3; still **FLAGGED-FOR-REVIEW** — Cole to confirm decorative trail compatibility with "Quiet" adjective.)
- ~~`.sitting` Finn in header; long-press → Pro easter egg shake + paw print.~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: Settings header is not in the allowed fox-surface list — only About/Settings *footer*).** ~~`.sitting`~~ remap is moot since the surface itself is removed.

### 13. Finn Plan 13 — Subscriptions + Trials grid redesign [stub]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> Active trial rows and TrialsView are **banned fox surfaces**. The `.watching` eye icon on each trial card is REMOVED. Empty states (Subscriptions empty, Trials empty) are **allowed**. "Kill it" CTA is FLAGGED-FOR-REVIEW (copy framing). Pull-to-refresh "paw-print stamp" is FLAGGED.

**Subscriptions tab:**
- Top: search bar + horizontally-scrollable filter chips (All / Active / Cancelled / Inactive).
- Body: `LazyVGrid` 2-col, grid-based cards (logo + name + next-bill-date largest + billing-cycle chip + monthly-normalized amount).
- Sort header cycles next-date / amount / alphabetical.
- Swipe actions: edit, archive, delete with per-action haptics.
- "Last used X ago" pill per card when `lastUsedAt != nil`.
- Calendar icon in header right → `BillingCalendarView`.
- Empty state: ~~`.sitting`~~ → **`.neutral`** Finn + paw-print trail to FAB + "Add your first subscription." (Empty state is an allowed fox surface; pose remapped. Paw-print trail FLAGGED-FOR-REVIEW.)
- Pull-to-refresh: paw-print stamp indicator. **FLAGGED-FOR-REVIEW** (decorative paw print on a data-dense surface — Cole to confirm).

**Trials tab:**
- Populated: "Ending soon" + "Later" sections, grid cards, ~~`.watching` eye icon on each~~ **REMOVED (banned surface per Brand Foundation 2026-04-29: active trial rows; TrialsView in general is a banned fox surface)**, ~~"Kill it" primary CTA~~ **FLAGGED-FOR-REVIEW: copy update — "Kill it" leans on the predator/character framing the Brand Foundation pulls back from. Suggest neutral copy like "Cancel before charge" — Cole to confirm.**
- Empty: ~~`.sleeping`~~ → **`.sleeping`** Finn (already correct mood — kept) + paw print trail + ~~"Hunt a trial"~~ **FLAGGED-FOR-REVIEW: copy update (matches FAB router copy flag in sub-plan 6) — Cole to confirm neutral phrasing** large centered CTA → HuntSheet. (Empty state is allowed; paw-print trail FLAGGED-FOR-REVIEW.)

### 14. Finn Plan 14 — Detail sheets unified + Finn's-take pill [stub]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3
> Detail sheets are **data-dense surfaces** — banned for fox visuals. The "Finn's-take pill" is FLAGGED-FOR-REVIEW: if it's a copy-only pill (text only, no fox visual), it's allowed; if the pill includes a fox icon/avatar, the icon is REMOVED. "Kill celebration" reframed to "cancel confirmation" per sub-plan 10.

Modify `Subly/Sheets.swift`:

- `TrialDetailSheet` (exists) + new `SubscriptionDetailSheet` sharing the same top-level structure: hero row (logo + name + next charge) → grouped fields `SurfaceCard` → Finn's-take pill → primary/secondary actions.
- Finn's-take pill pulls from `IntelligenceCore`. Free tier: rule-based. Pro tier: FM-generated. **FLAGGED-FOR-REVIEW** (copy-only pill is allowed; fox visual inside the pill would be on a banned surface and would need to be REMOVED — Cole to confirm pill composition).
- Primary: "Cancel this" (subs → CancelFlowSheet) / "Mark as cancelled" (trials → ~~kill celebration~~ **cancel confirmation** per sub-plan 10).
- Secondary: "Edit" (GhostButton).

### 15. Finn Plan 15 — App icon + launch screen [stub — blocked on illustrator]

> [!warning] Reconciled 2026-04-29 against [[Finn Brand Foundation]] §3 + §4
> "Duolingo-line" reference is **REMOVED** — Duolingo is an explicitly banned reference per Brand Foundation §4 ("character fun, not craft fun"). App icon is an allowed fox surface. Style mandates: vector only, head-and-bust silhouette default, single signature feature, readable at 32×32, Phosphor-compatible weight, single tonal palette.

Blocks on Cole's illustrator decision (Section 8 open item #1).

Scope:
- App icon (all required iOS sizes, dark+tinted variants).
- Launch screen (`LaunchScreen.storyboard` or SwiftUI replacement).
- Replace placeholder raster fox assets with final vector art catalog imports.
- ~~Both icon + launch reflect Duolingo-line + Vulpine + Finn's sitting pose.~~ **REMAPPED:** Both icon + launch reflect [[Finn Brand Foundation]] §3 fox style (vector head-and-bust, Phosphor-compatible weight, single tonal palette, **`.neutral` mood** — `.sitting` remapped) + Vulpine palette. Duolingo reference REMOVED (banned reference per Brand Foundation §4).

### 16. Finn Plan 16 — App Store submission prep [stub]

- README.md rewrite (currently describes pre-amputation Gmail product).
- legal/privacy.html rewrite.
- App Store Connect app record.
- Screenshots (5 per device size at minimum — Home, Subscriptions, Hunt, Calendar, Savings).
- App Preview video (optional but strongly recommended — 15s showing a Hunt end-to-end).
- Keywords, description, promo text, support URL, marketing URL.
- Pricing: $2.99/mo, $24.99/yr, $59 lifetime (founding).
- App Review notes: explain manual-only capture, no Gmail, no bank; Pro tier feature list; sample accounts if reviewer wants one.
- TestFlight internal beta → external beta (5-15 testers) → production submission.

---

## Writing the remaining sub-plans

Each `[stub]` sub-plan above becomes a full bite-sized TDD plan doc before execution. Full sub-plans contain:

1. Exact file paths (create/modify).
2. Failing test first, run it, watch it fail, with expected error.
3. Minimal implementation.
4. Run test, confirm pass.
5. Commit with conventional-commit message.

**When to write each full sub-plan:** right before you execute it, not all upfront. Writing all 16 to full detail now produces ~6000 lines that go stale fast — Linear tickets get added, priorities shift, intermediate sub-plans teach you things that change later sub-plans. Write the next 1-2 at a time.

**Sub-plan 01 (rename) is written in full** as the template and the next actionable task. See [[Finn Plan 01 — Rename Subly to Finn]].

---

## Self-review pass

Ran against the spec:

**Spec coverage check:**
- Section 1 (architecture) — ✓ covered by sub-plans 4–9 and the Entitlements module in 8.
- Section 2 (mascot) — ✓ sub-plan 4.
- Section 3 (screens) — ✓ sub-plans 3, 6, 9, 10, 11, 12, 13, 14.
- Section 4 (intelligence) — ✓ sub-plan 7.
- Section 5 (data flow) — validated within sub-plans 5, 6, 7.
- Section 6 (error handling) — covered within relevant sub-plans.
- Section 7 (testing strategy) — package test targets called out per sub-plan.
- Section 8 open items — 1 (illustrator) → sub-plan 15. 2 (paywall sheet design) → sub-plan 8. 3 (icon) → sub-plan 15. 4 (App Store assets) → sub-plan 16. 5 (README/privacy) → sub-plan 16. 6 (rename) → sub-plan 1. 7 (P7) → sub-plan 3. 8 (P10 HIGH fixes) → sub-plan 2. 9 (pricing ratification) → already rattified, spec monetization section.

All 9 spec open items map to a sub-plan.

**Placeholder scan:** sub-plan 01 is fully specified below. All other sub-plans are explicitly marked `[stub]` and the rule above says write full detail just-in-time, not upfront. This is a deliberate decomposition, not a TODO.

**Type consistency:** `FoxState` cases, `SourceHint` enum, `IntelligenceCore.SmartRemindersEngine` etc. — all match Section 1 of the spec verbatim.

---

# Sub-plan 01 — Rename Subly → Finn

**Goal:** Rename every user-facing and internal-type occurrence of "Subly" → "Finn" while preserving the bundleIdentifier so on-device SwiftData stores survive.

**Critical constraint:** `CFBundleIdentifier` stays `com.colehollander.subly`. Changing the bundle id invalidates all on-device SwiftData stores, Keychain items, and App Store Connect record. That is a worse launch regression than a mismatched identifier. Display name + every internal type + every user-visible string becomes "Finn."

**Dependencies:** none. Do this first.

**Expected branch:** `docs/rename-subly-to-finn-20260424` — wait, this is code, not docs. Rename: `chore/rename-subly-to-finn-20260424`.

### Task 1: Audit all "Subly" occurrences

**Files:** none modified yet. Just discovery.

- [ ] **Step 1: Grep the repo**

```bash
cd ~/Developer/Subly
grep -rn "Subly" \
  --include="*.swift" \
  --include="*.md" \
  --include="*.plist" \
  --include="*.yml" \
  --include="*.yaml" \
  --include="*.json" \
  --include="*.pbxproj" \
  --include="*.entitlements" \
  | wc -l
```

Expected: 200–500 matches. Record the number.

- [ ] **Step 2: Save the match list**

```bash
grep -rn "Subly" \
  --include="*.swift" \
  --include="*.md" \
  --include="*.plist" \
  --include="*.yml" \
  --include="*.yaml" \
  --include="*.json" \
  --include="*.pbxproj" \
  --include="*.entitlements" \
  > /tmp/subly-occurrences.txt
wc -l /tmp/subly-occurrences.txt
```

Review this file. Bucket matches into categories:

1. **Type / symbol names** — `SublyTheme`, `SublyApp`, `SublyEntry`, etc. → rename to `Finn*`.
2. **User-visible strings** — wordmarks, onboarding copy, app name — → rename to "Finn."
3. **Bundle identifier references** — `com.colehollander.subly` → LEAVE UNCHANGED.
4. **File paths** — `Subly/`, `Subly.xcodeproj/` etc. → LEAVE UNCHANGED (renaming the folder breaks Xcode project paths; too risky for this phase; address in a follow-up if ever).
5. **Doc references** — vault + CLAUDE.md + README.md mentions. Many already say "Finn"; update remaining Subly references per doc.

### Task 2: Rename type symbols

**Files to modify:** every `.swift` file that declares or references `SublyTheme`, `SublyApp`, and any other `Subly*` type names.

- [ ] **Step 1: List declared Subly types**

```bash
grep -rn --include="*.swift" -E "(class|struct|enum|protocol|typealias|extension)\s+Subly[A-Z]" ~/Developer/Subly
```

Expected output includes:
- `SublyTheme` (in `GlassComponents.swift`)
- `SublyApp` (in `SublyApp.swift`)
- Possibly others — record the full list.

- [ ] **Step 2: Commit a baseline before renaming**

```bash
cd ~/Developer/Subly
git checkout main
git pull --rebase
git checkout -b chore/rename-subly-to-finn-20260424
```

- [ ] **Step 3: Rename `SublyTheme` → `FinnTheme`**

Use Xcode's refactor tool via project open:
```bash
open ~/Developer/Subly/Subly.xcodeproj
```
- Right-click `SublyTheme` in the Project navigator or any usage → Refactor → Rename → `FinnTheme` → Save.
- Xcode refactors every call site. Verify with:

```bash
grep -rn --include="*.swift" "SublyTheme" ~/Developer/Subly
```
Expected: 0 matches.

- [ ] **Step 4: Rename `SublyApp` → `FinnApp`**

Same Xcode refactor flow. Verify:

```bash
grep -rn --include="*.swift" "SublyApp" ~/Developer/Subly
```
Expected: 0 matches (except the file name `SublyApp.swift` — leave the filename or rename separately in Task 3).

- [ ] **Step 5: Rename any remaining Subly* type symbols**

Repeat the Xcode refactor flow for each entry in the Task 2 Step 1 list. Verify zero remaining refs.

- [ ] **Step 6: Build**

```bash
cd ~/Developer/Subly
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run package tests**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test
cd ~/Developer/Subly/Packages/TrialEngine && swift test
cd ~/Developer/Subly/Packages/NotificationEngine && swift test
cd ~/Developer/Subly/Packages/TrialParsingCore && swift test
```
Expected: all green.

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/Subly
git add -A
git commit -m "refactor: rename Subly type symbols to Finn

SublyTheme → FinnTheme
SublyApp → FinnApp
(additional renames per grep audit)

Build green, all package tests pass. Bundle identifier, file paths, and
Xcode project name unchanged — preserving on-device SwiftData and App Store
Connect linkage."
```

### Task 3: Update user-visible strings

**Files to modify:** `Subly/OnboardingView.swift`, `Subly/SettingsView.swift`, `Subly/HomeView.swift`, any other view file that renders "Subly" as copy, and `Info.plist` display name.

- [ ] **Step 1: Find user-visible Subly strings**

```bash
grep -rn --include="*.swift" '"[^"]*Subly[^"]*"' ~/Developer/Subly
```

Review the results. Each string literal containing "Subly" is either:
- A wordmark / user-facing copy — rename.
- A log message or reverse-domain identifier — leave.

- [ ] **Step 2: Update Info.plist display name**

```bash
grep -n "CFBundleDisplayName\|CFBundleName" ~/Developer/Subly/Subly/Info.plist
```

Modify `CFBundleDisplayName` → `Finn`. Leave `CFBundleIdentifier` alone.

- [ ] **Step 3: Update each wordmark/copy string**

For each identified string, edit in place. Examples:
- `"Subly"` → `"Finn"`
- `"Welcome to Subly"` → `"Welcome to Finn"`

- [ ] **Step 4: Build**

```bash
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Visual verification on simulator**

```bash
xcrun simctl boot 'iPhone 16' 2>/dev/null; open -a Simulator
# Install fresh build:
DERIVED_DATA=$(ls -td ~/Library/Developer/Xcode/DerivedData/Subly-* | head -1)
APP_PATH=$(ls -td "$DERIVED_DATA"/Build/Products/Debug-iphonesimulator/Subly.app | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.colehollander.subly
```

Walk onboarding → home → settings. Every user-facing "Subly" should now read "Finn." Home screen app icon label reads "Finn."

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: rename user-visible Subly → Finn strings + Info.plist display name

Bundle identifier preserved. Display name updated to Finn. Onboarding,
settings, and home wordmarks all say Finn. Visual verification on iPhone 16
simulator confirms rename end-to-end."
```

### Task 4: Update CLAUDE.md + docs

**Files to modify:** `CLAUDE.md`, `README.md`, `DESIGN.md`, any other repo markdown.

- [ ] **Step 1: Find Subly in markdown**

```bash
grep -rn --include="*.md" "Subly" ~/Developer/Subly
```

- [ ] **Step 2: Review each match**

Some will remain — historical session logs, commit references, links to `docs/superpowers/specs/2026-04-23-subscription-pivot-*.md`. These are historical. Do not rewrite history.

Update active / current-state descriptions only:
- `CLAUDE.md` header / project description.
- `README.md` (full rewrite per sub-plan 16, but at least change the title + tagline now).
- `DESIGN.md` — `SublyTheme` references → `FinnTheme`.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md DESIGN.md
git commit -m "docs: update CLAUDE.md, README.md, DESIGN.md to Finn naming"
```

### Task 5: Push + PR

- [ ] **Step 1: Push**

```bash
git push -u origin chore/rename-subly-to-finn-20260424
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "chore: rename Subly → Finn (display + types)" --body "$(cat <<'EOF'
## Summary

Rename to Finn across type symbols, user-visible strings, and docs. Bundle
identifier + Xcode project name + file paths preserved to avoid invalidating
on-device SwiftData and App Store Connect linkage.

## Changes

- Swift type renames via Xcode refactor: SublyTheme → FinnTheme, SublyApp
  → FinnApp (+ any others discovered in audit).
- Info.plist CFBundleDisplayName → Finn.
- User-visible wordmarks, onboarding copy, home header → Finn.
- CLAUDE.md, README.md, DESIGN.md active descriptions updated. Historical
  session logs unchanged.

## Preserved unchanged

- CFBundleIdentifier (com.colehollander.subly)
- Xcode project file name (Subly.xcodeproj)
- Swift package folder paths (Packages/SubscriptionStore etc.)
- Historical doc references in session logs

## Test plan

- [ ] xcodebuild green
- [ ] Package tests all green (SubscriptionStore, TrialEngine, NotificationEngine, TrialParsingCore)
- [ ] Simulator visual walk: onboarding, home, trials, subscriptions, settings — every wordmark reads "Finn"
- [ ] Home screen app icon label reads "Finn"
- [ ] Existing on-device store opens without data loss (test on simulator with pre-existing trials)

EOF
)"
```

- [ ] **Step 3: Merge after review**

```bash
gh pr merge --merge --delete-branch
```

### Task 6: Post-merge verification

- [ ] **Step 1: Pull main**

```bash
git checkout main
git pull --rebase
```

- [ ] **Step 2: Confirm zero remaining refs**

```bash
grep -rn --include="*.swift" -E "Subly(Theme|App|Entry)" ~/Developer/Subly | wc -l
```
Expected: 0.

- [ ] **Step 3: Update Linear**

Mark the rename ticket Done. Move on to sub-plan 02 (P10 HIGH fixes).

---

# Ready to execute

Sub-plan 01 is fully specified above. Sub-plan 02–16 stubs are written; each gets expanded to full bite-sized-task detail the session before execution.

**Recommended execution order starting now:**

1. Sub-plan 01 (rename) — fully written, execute now.
2. Sub-plan 02 (P10 HIGH fixes) — expand to full TDD detail, then execute.
3. Sub-plan 03 (Home 3-state) — expand, execute.
4. Sub-plan 04 (MascotKit) — expand, execute. After this lands, many others unblock.
5. Sub-plan 05 (schema expansion) — can run parallel with 04 if needed.
6. Continue per the dependency graph above.
