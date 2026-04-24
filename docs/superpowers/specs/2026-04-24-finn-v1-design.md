# Finn v1 — Launch Design

**Date:** 2026-04-24
**Status:** Approved for implementation planning
**Epic:** TBD (new Linear epic to be cut after spec review)
**Supersedes context from:** `2026-04-23-subscription-pivot-design.md` (P1–P10 of subscription pivot remain valid; this spec layers on top)

---

## The Pitch

**Track every subscription. Kill every free trial. Completely private and on-device.**

This spec defines the shape of Finn at App Store v1 — not v1.1, not a post-launch polish pass. The decision anchoring everything in this document: **Cole would rather take the time to launch something genuinely great than ship a thin v1 and iterate in public.** Scope in this spec reflects that.

---

## Locked Decisions (summary)

Pulled forward from the brainstorming conversation so anyone reading this doc has context without re-reading the transcript.

### Brand

- **Finn is a hunt partner, not a mascot.** You and Finn hunt trials together. Copy, motion, and personality across the app reinforce the partnership metaphor.
- **Art direction:** Duolingo-style. Thick uniform line weight, primitive shapes (circles, arcs, capsules), flat fills only. **No gradients, no fur texture, no shadows, no AI-mascot feel.** Vulpine orange `#F97316` body, cream belly/inner ears/tail tip, warm charcoal `#1A1614` outline.
- **Celebration tone:** playful, snappy, fun. Not violent, not aggressive. "The kill" language in internal notes refers to the satisfying win of canceling a trial — the *feeling* is a game-win, not combat.
- **Paw prints are a secondary motif** — confetti on celebration, subtle dividers in Settings, an "About Finn" trail, an undocumented long-press easter egg, a pull-to-refresh stamp.

### Product

- **Subscriptions = primary surface.** More of them, always present. The "calm control panel" living room.
- **Trials = episodic surface.** They surge forward when active (Home hero, urgency, Finn's attention) and quiet when not.
- **Screenshot-based vision parsing is the flagship ingestion path.** Gmail amputated. Manual form is a fallback, not the hero.
- **Red alert calendar for upcoming bills ships in v1** (pulled forward from v1.1 deferred list).
- **Savings tally ("$X caught") ships in v1** (pulled forward — makes the core promise visible).

### Intelligence

All four intelligence features ship in v1 with a **hybrid substrate**: heuristics + Core ML for the free path, Foundation Models on Apple Intelligence devices for the Pro path.

1. **Smart reminders** — learn cancel-timing habits, shift alert offsets
2. **Usage detection** — detect inactive subs (free: explicit nudge; Pro: inferred from in-app behavior)
3. **Predictive subscription ID** — suggest related subs; Pro extracts from pasted receipts/screenshots via FM
4. **Local inference substrate** — rules + Core ML for free, FM prompt chain for Pro

### Monetization

- **Free tier:** 10 subs + 3 trials. Full feature access at those caps. Heuristic-tier intelligence for all 4 features.
- **Finn Pro:** $2.99/mo, $24.99/yr, $59 founding lifetime. Unlimited entries + FM-enhanced intelligence + FM-enhanced screenshot hunt + paw-print easter eggs + exclusive Finn states/accessories (see Section 2).
- **Paywall strategy:** NEVER in onboarding. Contextually surfaced after real usage (entry #11, 3rd HuntSheet open, day 3+). Single "Finn Pro — more on that later" line in onboarding step 4. Settings Finn Pro section from day 1 for self-service discovery.

### Tech / Privacy

- **100% on-device.** SwiftData for storage. No backend, no cloud sync (v1), no analytics SDK.
- **App Store Connect is the only analytics.** No PostHog, no Amplitude, no in-app telemetry.
- **No share extension in v1** (deferred to v1.1).
- **No widgets in v1** (deferred to v1.1).

### Deferred to v1.1 (explicit list)

- Safari / Chrome extension
- Home screen + lock screen widgets
- Share extension target
- Category tagging, theme presets
- Fox outfits / skins system, milestone unlocks
- Auto-advance `chargeDate` on renewal
- Automated trial → subscription conversion flow
- Lottie upgrade for mascot animation
- Standalone `MascotKit` published as external SPM

---

## 1. System Architecture

### New Swift packages

#### `MascotKit`

Finn's emotional state machine, asset loader, and animation primitives.

- Exposes `FoxState` (7-case enum — see Section 2), `FoxView(state:)`, `PawPrintConfetti(trigger:)`, `PawPrintTrail()`, and motion primitives (`PhaseAnimator` wrappers with tuned spring defaults).
- Pure SwiftUI. No Lottie v1.
- **Dependency direction:** depends on nothing above it (no app-target types, no other Finn packages). Consumed by the app target only.
- Owns all mascot-related timing, haptic-coupling, and Reduce Motion gating.
- Asset catalog lives *inside the package* so the package is self-contained and future-extractable.

#### `VisionCapture`

Screenshot → structured trial/subscription extraction.

- Wraps `VNRecognizeTextRequest` for OCR.
- Routes extracted text to either `TrialParsingCore` rules (free path) or `IntelligenceCore.foundationModels.extract(_:)` (Pro path on AI devices).
- Returns `CandidateEntry { merchant, amount, chargeDate?, billingCycle?, entryType, confidence, sourceHint: .screenshot }`.
- Pure function in/out. No UI, no SwiftData dependency. The app target decides what to do with a `CandidateEntry`.

#### `IntelligenceCore`

Hybrid inference substrate for the 4 intelligence features.

Shape:

```swift
public struct IntelligenceCore {
    public let smartReminders: SmartRemindersEngine
    public let usageDetection: UsageDetectionEngine
    public let predictiveID: PredictiveIDEngine
    public let vision: VisionEnhancer   // hook used by VisionCapture

    public init(tier: SubscriptionTier, ai: AppleIntelligenceAvailability)
}
```

- Each engine has two internal paths: `.heuristic` and `.foundationModels`. Routing picks based on `(tier, ai)` at call time.
- Heuristic path: rules + optionally a small Core ML classifier (trained offline by Cole, shipped as a Core ML asset in the package).
- FM path: composed `LanguageModelSession` prompts. `LanguageModelSession` is only instantiated when (tier == .pro && ai.available). Instantiation is lazy and memoized per engine.
- Graceful degradation: if FM session fails (device thermals, user revoked AI, etc.), engine falls back to heuristic path silently. No error bubbling to UI.

#### `BillingCalendar`

Pure domain logic for the red-alert calendar.

- Input: `[Trial]` (from SwiftData).
- Output: `[CalendarDay]` where each day carries `{ date, events: [BillEvent], urgency: .quiet | .normal | .alert }`.
- `alert` is assigned to days with a bill where `IntelligenceCore.usageDetection.isInactive(trial:) == true`, OR where the day is within the next 48h and the amount > $10 (configurable threshold).
- No UI. Returns raw model consumed by `BillingCalendarView`.

### Existing package changes

#### `SubscriptionStore`

Add to `Trial` (all nullable, lightweight-migrated via `@Attribute(originalName:)` where needed, no `VersionedSchema` because the app is still pre-TestFlight):

```swift
var lastUsedAt: Date?
var usageConfidence: Double?       // 0.0–1.0, populated by IntelligenceCore
var sourceHint: SourceHint          // .screenshot, .storekit, .manual, .suggested
var appleOriginalTransactionID: String?   // already landed in PR #36
```

Add new entity:

```swift
@Model final class PredictiveCandidate {
    var merchant: String
    var suggestedBecause: String    // "You imported Netflix, Disney+ often follows"
    var dismissedAt: Date?
    var confirmedAt: Date?
    var suggestedEntryType: EntryType
}
```

Add new enum `SourceHint`: `.screenshot`, `.storekit`, `.manual`, `.suggested`.

#### `TrialEngine`

- `plan(trialID:chargeDate:...)` and `planSubscription(entryID:chargeDate:...)` now accept an optional `IntelligenceCore.SmartRemindersEngine` to pull user-specific offset learning.
- Default offsets unchanged (3d/1d/day-of for trials, 1d for subs) if `IntelligenceCore` returns `nil` or user has intelligence off.
- Public API surface shape preserved — no breaking changes to existing call sites.

#### `NotificationEngine`

- `NotificationCopy` helper gets new "nervous Finn" variants — subject/body templates that match Finn's watch-tapping state (*"Finn's tapping his watch — Netflix charges you tomorrow."*).
- Copy is plain text only. No rich push attachments in v1.
- Actor model unchanged.

#### `TrialParsingCore`

Unchanged. Now consumed by `VisionCapture` as the free-tier substrate. Kept as a standalone package so `VisionCapture` dependency stays narrow.

#### `LogoService`, `PhosphorSwift`

Unchanged.

### Pro-tier gate

New lightweight module `Entitlements` (lives in app target — does not warrant a package):

- `SubscriptionTier { .free, .pro }` — read from StoreKit 2 `Transaction.currentEntitlements` + `Transaction.updates` listener.
- `AppleIntelligenceAvailability { .unavailable, .available }` — read from `SystemLanguageModel.default.availability` at launch and on scene-phase `.active`.
- One observable `AppEntitlements` singleton. Views and `IntelligenceCore` read from it.
- No in-app server verification in v1 — StoreKit 2 on-device entitlement check is sufficient.

### App-target surface changes

- New view: `BillingCalendarView` — full-screen sheet, reached from Home "Upcoming bills" row or Subscriptions header.
- New view: `HuntSheet` — full-screen sheet, reached from FAB → "Hunt a trial" or Trials empty state.
- New view: `SavingsView` — full-screen sheet, reached from Home "$X caught" pill or Settings savings pill.
- `ContentView` — Home rebuild (Section 3.2), Trials empty-state rebuild (Section 3.4).
- `SettingsView` — Intelligence section + Finn Pro section added (Section 3.9).
- `FoxView` (existing) — now thin wrapper delegating to `MascotKit.FoxView`.
- `Sheets.swift` — `TrialDetailSheet` + new `SubscriptionDetailSheet` unified; Finn's-take pill added (Section 3.7).
- Onboarding — 4-step copy rewrite + "first subscription add" interaction on step 4 (Section 3.1).

---

## 2. Finn Mascot System

Finn's system is the single largest "feels premium" lever in the product and the largest art-direction deliverable in v1.

### Art brief

- **Line language:** uniform-weight strokes, same thickness across body, face, accessories. No tapering, no calligraphic lines.
- **Shape language:** primitives only — perfect circles, arcs, capsules, straight segments. Body = capsule. Head = circle. Ears = arcs. Tail = thick curve.
- **Color:** flat fills only. Body `#F97316`, belly/inner ears/tail tip cream `#FAF4E8`, outline `#1A1614`. No gradients, highlights, rim lights, ambient occlusion, fur texture, shadows.
- **Eyes:** solid dots or arcs keyed to emotion. No whites-of-eyes unless `.nervous`. No anime sparkles.
- **Accessories** (3 in v1): watch, hunter's cap, celebratory flag. Same line weight, same flat fills. Composed as overlay layers where practical so poses can recompose without redrawing the base.

### Deliverable format

- **Vector (SVG + PDF)** imported to Xcode asset catalog as **Single Scale** with **Preserve Vector Data** enabled.
- One asset per pose. Accessories as separate overlay layers where practical.
- Placeholder raster assets (`fox-sitting`, `fox-sleeping`) are replaced in v1. No raster assets ship to the App Store.

### Artist decision

**Launch-blocking, TBD.** Options Cole is weighing: (a) self-illustrate from this brief, (b) hire an illustrator with this brief, (c) placeholder vectors → hire before submission. Decision does not block spec acceptance but must resolve before App Store submission. Recommend option (b) — the polish level in this brief matches paid illustrator work, not afternoon-Cole work.

### `FoxState` — 7 emotional states

| State | Trigger | Pose | Accessory | Surface |
|---|---|---|---|---|
| `.sleeping` | No active trials, no bills within 7 days | Curled, eyes closed | — | Home empty, Trials empty |
| `.sitting` | Idle default | Upright, ears relaxed | — | Settings header, Onboarding intro |
| `.watching` | Trials active, no urgency | Alert, ears perked, eyes forward | — | Home (trials exist, quiet state) |
| `.nervous` | Bill in <48h OR trial charging in <24h | Tense, tapping watch | Watch | Home urgency, Calendar red-alert headers |
| `.hunting` | HuntSheet active | Crouched, tail low, focused | Cap | HuntSheet only |
| `.celebrating` | Trial killed / sub canceled | Arms up, happy-arc eyes | Flag | Cancel-assist success, savings roll |
| `.proud` | Cumulative savings > $100 | Hero pose, chest out | Flag tucked | Savings screen, Settings savings pill |

### Motion rules

- All state transitions use `PhaseAnimator` with a tuned spring (response ~0.35, damping ~0.7). Discrete pose snap with slight overshoot bounce.
- Emotional beats (nervous watch-tap, celebrating jump, hunting tail-flick) are short repeating loops (1.5–2.5s) via `TimelineView`. Loops start with state activation, stop with deactivation. No always-on battery-burners.
- **Reduce Motion respected:** state changes become instant pose swaps, confetti becomes a single static flag, nervous watch-tap becomes a still pose with watch visible. Functionality preserved, motion stripped. Accessibility audit in P10.

### "The hunt" flagship interaction

See Section 3.6 for full screen-level spec. Motion choreography:

1. Sheet opens → Finn enters in `.hunting` pose from off-screen-right, 0.4s slide + settle bounce.
2. User picks screenshot → screenshot shrinks to preview at top-left of sheet.
3. Finn does a **pounce** phase: crouch deeper (0.3s) → leap off-screen-top (0.3s).
4. VisionCapture runs. On-screen progress indicator is a row of paw prints stamping left-to-right (one every 300ms, max 3 visible). Paw prints use `MascotKit.PawPrintTrail`.
5. **Success path:** Finn returns from off-screen-bottom in `.celebrating` pose with the extracted card materializing to his right. Caption: *"Caught one — [Service] trial ends [Date]."* Haptic `.save`. Two buttons: "Looks right ✓" (saves + triggers "the kill" celebration short-form) | "Edit" (opens pre-filled manual form).
6. **Low-confidence path:** Finn returns in `.sitting` with a head-tilt animation. Caption: *"I think I got it — check the details."* Same two buttons, "Edit" pre-highlighted.
7. **No-catch path:** Finn returns in `.sitting`. Caption: *"Nothing to catch here. Want to add it manually?"* Single button.

### "The kill" celebration

Fires on cancel-assist success OR trial marked as cancelled from TrialDetailSheet OR the "Looks right ✓" path after a caught trial that was already ending.

1. Sheet (if any) dismisses up-and-away, 0.25s.
2. Finn pops in from the bottom of the current view in `.celebrating` pose, 0.3s spring.
3. **Paw print confetti burst** — `MascotKit.PawPrintConfetti` with ~20-30 paw prints. Vulpine + cream + soft blue accent, physics-simulated falling via SwiftUI `Canvas` + simple particle system. No third-party lib.
4. "Caught $X" amount rolls from last cumulative value to new value. Numeric roll (`ContentTransition.numericText()`), not fade.
5. Haptic `.markCanceled` (strong).
6. Finn holds pose 1.2s, then spring-bounces back to idle (previous state).
7. Under Reduce Motion: confetti replaced with a single static paw print, Finn does pose swap only, numeric roll replaced with crossfade.

### Paw print system

Shared motif used across confetti + delighters.

- **Confetti:** primary moment, fires on celebration.
- **Settings section dividers:** 2 of N section dividers use a centered paw print instead of `HairlineDivider`. Do not apply to all — overuse kills the detail.
- **"About Finn" footer:** static trail of 4-5 paw prints walking across the bottom of Settings, leading into the app version number.
- **Onboarding step 4 finale:** paw prints walk across the bottom as the user lands on Home for the first time.
- **Trials empty state:** paw print trail leading off-screen into "Finn's resting" copy.
- **Pull-to-refresh on Subscriptions:** refresh indicator is a paw print that stamps down.
- **Long-press Finn in Settings header (easter egg):** Finn shakes, leaves a paw print on screen that fades after 2s. Undocumented. Pro tier only — this is one of the "warm" Pro delighters.

---

## 3. Screen-by-Screen Redesign

Every shipped surface is audited against the UI/UX doctrine: grid layouts, one clear action per screen, visual hierarchy, instant feedback on every tap, motion only when it supports understanding.

### 3.1 Onboarding (copy + tone rewrite, 4 steps)

Currently explains what the app does. After rewrite: sells the result of *being in control*.

| Step | Finn pose | Headline | Subcopy | Action |
|---|---|---|---|---|
| 1 | `.sitting` | "Never get charged for a trial you forgot." | "Finn catches them before they charge you." | "Meet Finn →" |
| 2 | `.hunting` (peeking from behind a screenshot frame graphic) | "Screenshot any trial. Finn handles the rest." | "No email. No bank. Nothing leaves your phone." | "How it works →" |
| 3 | `.watching` | "You'll hear from him before you're charged." | "Smart reminders, on your clock." | "Sounds good →" |
| 4 | `.celebrating` | "You're in control now." | "Let's catch your first one." + small line: *"Finn is free. Finn Pro is even better — more on that later."* | "Start hunting →" |

- Step 4 lands on Home with an inline nudge to the FAB (`.watching` Finn pointing at the FAB for 3s, then settles). First-add celebration (Section 2 "kill") fires on the user's first real save. This is the "hook" moment, not a paywall.
- **One clear action per screen** ✓ — only the forward button is active.

### 3.2 Home (adaptive by state)

Home is not a dashboard. Home is **"what does Finn want you to know right now."**

**State 1 — quiet (no trials, no imminent bills):**
- Finn `.sleeping`, centered, takes ~40% of the viewport.
- "All clear." Large. No sub-copy.
- If cumulative savings > $0, a small "$X caught" pill at the top, tap → SavingsView.
- FAB present, calm.
- **One clear action:** FAB (add something).

**State 2 — watching (trials exist, no urgency):**
- `.watching` Finn in a compact card at the top, with a single line: *"Finn's watching [N] trials."*
- Below: ≤7-day trial scope as `SurfaceCard`s (max 3, with "See all" link to Trials tab if more).
- Below: "Upcoming bills" mini-row — next 3 bills in 30 days as tappable pills → BillingCalendarView.
- FAB present.
- **One clear action:** tap the most-urgent trial card.

**State 3 — urgent (trial charging <24h OR bill <48h):**
- `.nervous` Finn at the top, watch-tap animation live.
- Single hero card for the urgent item. Large.
- "Handle it" CTA in Vulpine orange.
- All other content pushed below, visually receded.
- FAB present but muted.
- **One clear action:** handle the urgent item.

**Not in v1:** spend-over-time charts, monthly total hero, category breakdowns. Explicit anti-patterns.

### 3.3 Subscriptions (primary living room)

Real-time-spent surface. Calm, complete, scannable.

- **Top:** search bar + horizontally-scrollable filter chips (All / Active / Cancelled / Inactive).
- **Body:** grid layout, 2 columns on phone, `LazyVGrid`. Each card shows: logo + name + next bill date (largest text) + billing cycle chip + monthly-normalized amount.
- **Sort header:** tap cycles "next date / amount / alphabetical." Default = next date ascending.
- **Empty state:** Finn `.sitting` + paw-print trail to FAB + "Add your first subscription." One clear action: tap FAB.
- **Card interactions:**
  - Tap → `SubscriptionDetailSheet`
  - Swipe left → quick actions (edit, archive, delete) each with haptic
  - Long-press → quick-actions bottom sheet
- **"Last used" pill on each card** if `Trial.lastUsedAt != nil` — shows e.g. "Used 3d ago." Free tier: populated by the explicit monthly nudge. Pro tier: populated by inferred in-app behavior via `IntelligenceCore.usageDetection`.
- **Calendar access:** small calendar icon in the header right → `BillingCalendarView`.
- **Free tier cap:** at 10 subs, adding the 11th triggers a Pro upsell sheet ("Unlock unlimited — $2.99/mo"). Clean dismiss, no punishment.

### 3.4 Trials (episodic surface)

Matches "trials fade when they aren't happening" instinct.

**Populated state:**
- Two sections: *"Ending soon"* (next 7 days, urgency-tinted) and *"Later"*.
- Same grid-card treatment as Subscriptions.
- Small `.watching` Finn eye icon on each card signaling "Finn is tracking this."
- Prominent "Kill it" action on each card (primary visual CTA, Vulpine orange Capsule).
- **One clear action:** tap "Kill it" on the most-urgent card.

**Empty state:**
- Full-surface empty: Finn `.sleeping`, paw-print trail leading off-screen.
- "No trials to hunt. Finn's resting."
- Large centered button: "Hunt a trial" → `HuntSheet`.
- **One clear action:** "Hunt a trial."

**Free tier cap:** at 3 trials, adding the 4th triggers the same Pro upsell.

### 3.5 Billing Calendar (new)

Red alert calendar. Month grid. Reached from Home "Upcoming bills" row or Subscriptions header.

- **Month grid:** standard 7-col calendar. Each day cell shows:
  - Day number.
  - 0–N colored dots, one per bill on that day, tinted:
    - Vulpine orange = normal
    - Red `#E03B3B` = flagged by `IntelligenceCore.usageDetection` OR bill within 48h over threshold
  - Subtle amount total at bottom of cell if bills present.
- **Tap a day** → bottom sheet with bills on that day + per-item actions (open detail, mark cancelled, snooze reminder).
- **Today's cell:** Vulpine outline. Pulse animation once on view open, then still.
- **Red-alert day glow:** subtle red drop-shadow glow on the dot. Respected by Reduce Motion.
- **Month nav:** horizontal swipe between months. Header: month/year + "Today" button (right-aligned).
- **Finn in the header:** `.nervous` if the visible month has any red-alert days; `.sitting` otherwise.
- **One clear action:** tap a day.

### 3.6 HuntSheet (flagship interaction)

Full-screen sheet. Reached from FAB → "Hunt a trial" OR Trials empty-state CTA.

**Entry:**
- Finn enters in `.hunting` pose from off-screen-right, 0.4s slide + settle bounce.
- Two large tappable cards, stacked vertically, 50/50 viewport split:
  - **"Take a screenshot"** — camera. Flat-line Duolingo-style camera icon. Paw-print watermark behind.
  - **"Pick from library"** — photo picker. Flat-line stack-of-photos icon. Paw-print watermark behind.
- Below, muted: link "Have text? Paste instead" → small paste field.
- Below that, smaller: link "Add manually" → existing manual form sheet. Still accessible, not hidden, not primary.

**Screenshot chosen → capture flow** (see Section 2 motion choreography for full sequence): pounce → paw-print progress row → success | low-confidence | no-catch paths.

**Pro upsell placement:**
- Shown at most once per session.
- Never mid-hunt.
- Non-intrusive dismissible banner at the bottom of the entry screen: *"Finn Pro catches more on Apple Intelligence phones."* → paywall sheet.
- Free-tier users' hunt path is fully functional. Pro path is better, not gate-kept-core.

### 3.7 Trial/Subscription Detail Sheet (unified)

`TrialDetailSheet` already rewritten in COL-134. This spec extends it to `SubscriptionDetailSheet` with a unified treatment.

- **Top:** large logo + service name + "Next charge [Date] • $X" hero row.
- **Grouped fields** in a `SurfaceCard`: amount, billing cycle, chargeDate, notes, notificationOffset.
- **"Finn's take" pill** under the fields — one line, subtle. Examples:
  - Free: *"You've had this for 3 months."* | *"Not used in 28 days — consider canceling?"*
  - Pro: *"You haven't opened Netflix in 41 days. Want me to remind you before it renews?"* (generated by FM)
- **Primary action:** "Cancel this" (subs → cancel-assist) or "Mark as cancelled" (trials → kill celebration). Vulpine orange Capsule.
- **Secondary action:** "Edit" (muted GhostButton).
- **One clear action:** the primary Vulpine button always wins hierarchically.

### 3.8 Cancel-assist flow (Section 2 integration)

Shipped in P5 (COL-145). v1 extends it with the kill celebration (Section 2).

- Curated guides unchanged, 15 services + web fallback.
- On "I canceled it": sheet dismisses → kill celebration fires (Section 2 choreography) → user lands on Home (or wherever they came from).
- Audit against doctrine: ✓ full-screen = one action, ✓ guides = visual hierarchy, ✓ "I canceled it" is THE button.

### 3.9 Settings (COL-139 follow-through + paw prints)

Structural cleanup + intelligence + Finn Pro sections added.

- **Header:** Finn `.sitting` (long-press → Pro easter egg shake + paw print).
- **"$X caught" savings pill** prominent at top of header. Tap → `SavingsView`.
- **Sections** (in order):
  - **Notifications** — existing toggles. Copy audit (COL-139).
  - **Intelligence** — master on/off toggle + per-feature toggles (Smart reminders, Usage nudges, Predictive suggestions). Descriptions explain what each does in plain language.
  - **Finn Pro** — from day 1. Free users see a "Manage" button that opens the paywall sheet with features + price. Pro users see "You're a Pro. Manage subscription." → opens App Store subscription management.
  - **Data** — export, delete all, preview-data toggle.
  - **About** — version, credits, privacy policy link, terms link.
- **Paw print dividers:** 2 of the above 5 section headers get a centered paw print divider (proposal: Intelligence + Finn Pro, because those are the "Finn-personality" sections).
- **"About Finn" footer:** static trail of paw prints leading into version number.

### 3.10 SavingsView (new)

"$X caught" proof-of-promise screen. The screenshotted-to-social moment.

- **Top:** massive number — "$247 caught." Vulpine orange. `ContentTransition.numericText()` for live updates.
- **Subtitle:** "since you started hunting with Finn"
- **Finn `.proud`** center-left. Flag tucked if savings > $100, otherwise `.celebrating`.
- **Last 5 catches** list below — service + amount + date, small `SurfaceCard`s.
- **"See all catches"** link → full history view (simple list, not spec'd deeply).
- **One clear action:** "See all catches" OR close.

---

## 4. Intelligence Features — Behavior Spec

Per-feature behavior for the 4 v1 intelligence features. Each has a heuristic path (free) and an FM path (Pro on AI devices).

### 4.1 Smart reminders

**Free path (heuristic):**
- Track when user opens cancel-assist relative to `chargeDate` for killed trials (rolling 10-event window in `UserDefaults`, no SwiftData needed).
- If median cancel-lead-time < 24h, shift next trial's notification offset from 3d/1d/day-of → 1d/day-of/morning-of.
- If median > 5d, keep default or widen to 5d/2d/day-of.

**Pro path (FM):**
- FM session receives `{userHistory: [(merchant, leadTime, killed: Bool)]}` and returns a recommended offset schedule per trial, with a "why" string shown in the TrialDetailSheet Finn's-take pill.

### 4.2 Usage detection

**Free path (explicit nudge):**
- Monthly `UNNotification` per active sub: *"Still using Netflix?"* with inline actions "Yes" / "No."
- Response updates `Trial.lastUsedAt` (yes) or flags the sub on BillingCalendar as red-alert (no).
- Max one of these nudges per user per week to avoid fatigue. Quiet until opted-out via Settings.

**Pro path (inferred):**
- Track in-app behavior per sub: how often the user opens its detail sheet, taps its card, scrolls past it without pausing (via visibility observers).
- `IntelligenceCore.usageDetection.isInactive(trial:)` returns `true` if `lastInteractionAt > 30 days ago`.
- Inferred usage updates `usageConfidence` and quiets the explicit monthly nudge proportionally.

### 4.3 Predictive subscription ID

**Free path (correlation rules):**
- Static rule table in `Resources/SubscriptionCorrelations.json` ("If Netflix, suggest Disney+." "If Spotify, suggest Apple Music?" "If ChatGPT Plus, suggest Claude Pro.").
- Surfaces as a dismissible "Finn suggests" card on Subscriptions tab above the grid. Max 1 visible at a time. Dismissed suggestions don't re-surface for 90 days.

**Pro path (FM):**
- FM session receives the current sub list + merchant context and returns ranked suggestions with "why" strings.
- Bigger win: Pro users can paste/screenshot *any* receipt, FM extracts the sub directly (handled via `VisionCapture` FM enhancement path, not here).

### 4.4 Local inference substrate

- Shared `IntelligenceCore` runtime.
- **Availability detection:** at launch, `SystemLanguageModel.default.availability` populates `AppEntitlements.aiAvailable`. Re-read on scene `.active`.
- **Routing:** every engine call does `if tier == .pro && aiAvailable { fm } else { heuristic }`.
- **Failure mode:** FM call throws → silent fallback to heuristic path + log via `OSLog`. No UI error surface. User should never know FM failed.
- **Thermals / throttling:** `LanguageModelSession` is instantiated lazily, kept on a serial queue, and torn down after 30s of idle. Prevents background thermals.

---

## 5. Data Flow

End-to-end for the flagship interaction so the skeleton is concrete:

**User taps FAB → "Hunt a trial" → picks screenshot:**

1. `HuntSheet` captures `UIImage` from `PhotosUI` or `UIImagePickerController`.
2. Calls `VisionCapture.extract(image:tier:)`.
3. `VisionCapture` runs `VNRecognizeTextRequest` → raw text.
4. Routes:
   - Free: `TrialParsingCore.classifyText(rawText, source: .screenshot)` → `CandidateEntry`.
   - Pro + AI: `IntelligenceCore.vision.enhance(rawText, heuristicResult:)` → enriched `CandidateEntry`.
5. Returns `CandidateEntry` with confidence.
6. `HuntSheet` receives candidate → shows success/low-confidence/no-catch path.
7. On "Looks right ✓": app target creates a `Trial` in SwiftData with `sourceHint = .screenshot`, entryType from candidate, chargeDate, amount, merchant.
8. `TrialAlertCoordinator.replanAll()` fires.
9. Kill celebration (if applicable) triggers (Section 2).

**User opens Subscriptions tab (quiet morning):**

1. `SubscriptionsView` queries SwiftData for `entryType == .subscription`.
2. For each sub, `IntelligenceCore.usageDetection` returns `isInactive` + `lastInteractionAt`.
3. Cards render with "Last used X ago" pill.
4. `IntelligenceCore.predictiveID.suggestions(currentSubs:)` returns up-to-1 suggestion → rendered as a "Finn suggests" card above the grid.

**User cancels a sub (from SubscriptionDetailSheet "Cancel this"):**

1. Sheet opens cancel-assist (reuses P5 CancelFlowSheet).
2. User taps "I canceled it" → writes `Trial.status = .cancelled`, stamps `cancelledAt = Date()` (also fixes the P10 audit finding in `Trial.swift:61`).
3. `modelContext.save()` + `TrialAlertCoordinator.replanAll()`.
4. Kill celebration fires (Section 2).
5. Savings accumulator increments.

---

## 6. Error Handling

- **VisionCapture failure:** OCR returns empty OR all extraction paths return nil → HuntSheet shows no-catch path. Never error dialog.
- **FM unavailable mid-call (Apple Intelligence revoked, thermals, etc.):** silent fallback to heuristic. Logged via `OSLog` subsystem `com.colehollander.finn.intelligence`. No UI error.
- **StoreKit tier fetch failure:** defaults to `.free` (fail-closed for Pro features, fail-open for usability). Retries on next `Transaction.updates` emission.
- **SwiftData migration failure:** existing keyword-classified wipe-on-incompatibility fallback stays. No `VersionedSchema` in v1 (deliberate; app is pre-TestFlight).
- **Notification permission denied:** Settings surfaces a banner explaining the core promise relies on notifications. One tap → iOS Settings deep link. No nagging beyond this.

---

## 7. Testing Strategy

### Unit / package tests (target coverage 80%+)

- `SubscriptionStore`: 7 existing + ~4 new tests for `sourceHint`, `PredictiveCandidate`, `lastUsedAt`. Target: **12**.
- `TrialEngine`: 3 existing + 4 new tests for SmartReminders-informed offsets. Target: **7**.
- `NotificationEngine`: 11 existing + 3 new tests for nervous-Finn copy variants. Target: **14**.
- `TrialParsingCore`: 10 existing, unchanged. Target: **10**.
- `VisionCapture`: new — 8 tests. OCR-to-text success, heuristic-path candidate generation, FM-path candidate generation (mocked), low-confidence path, no-catch path. Target: **8**.
- `IntelligenceCore`: new — 12 tests. Smart reminders rolling window, usage-detection threshold, predictive-ID rule matching, FM fallback routing (mocked). Target: **12**.
- `BillingCalendar`: new — 6 tests. Month computation, urgency classification, edge cases (leap year, DST). Target: **6**.
- `MascotKit`: limited — 3 tests. State resolution from app state, Reduce Motion passthrough, confetti lifecycle. Target: **3**.

**Total package tests target: 72** (current: 31).

### Integration / UI tests

- Add Trial end-to-end (manual form): 1 test.
- Hunt a trial (screenshot mock): 1 test.
- Kill a trial → savings increment: 1 test.
- Pro paywall surfaces at entry #11: 1 test.
- Pro paywall surfaces at 3rd HuntSheet open: 1 test.

### Manual QA checklist (before App Store submission)

- Every Finn state appears in at least one screen under real conditions.
- Reduce Motion strips every animation correctly; functionality preserved.
- VoiceOver reads every surface in logical order; Finn states are announced.
- Dynamic Type at XXL doesn't break any grid.
- Free → Pro transition updates entitlements within one session without restart.
- FM unavailable on a non-AI device: entire Pro path still functions via heuristics.
- App Store Connect analytics populated after 3 days of TestFlight dogfood.

---

## 8. Open Items (launch-blocking)

These items do NOT block spec acceptance, but must resolve before App Store submission:

1. **Finn final vector illustrator decision.** Cole to decide between self-illustration, hired illustrator, or placeholder-then-hire.
2. **Finn Pro paywall sheet design.** Copy + layout not fully specified in this doc. Ships in implementation phase; needs its own mini-design iteration.
3. **App icon + launch screen.** Still default. Duolingo-art-direction applies here too.
4. **App Store assets.** Screenshots, preview video, keywords, description. Positioning doc gives raw material.
5. **README.md + legal/privacy.html.** Still describe pre-amputation Gmail product. Rewrite.
6. **Rename Subly → Finn (~45 min mechanical).** BundleIdentifier, Info.plist, wordmark, CLAUDE.md, vault, repo.
7. **P7 (COL-147) HomeView empty-state.** Folded into Section 3.2 State 1 here; existing ticket remains the implementation vehicle.
8. **P10 (COL-150) audit findings — 4 HIGH fixes.** All same pattern (save + replan after mutations). Must land before submission. Existing ticket remains the vehicle.
9. **Pricing ratification with Cole.** Spec assumes $2.99/$24.99/$59 from prior vault state + conversation.

---

## 9. Non-Goals (explicit, for anti-creep)

These do NOT ship in v1:

- Bank-link, Plaid, any financial data provider integration.
- Gmail, IMAP, or any email ingestion.
- Cloud sync, iCloud KV, CloudKit.
- Web app, Safari extension, Chrome extension.
- Home screen widgets, lock screen widgets, Live Activities.
- Share extension target.
- Share-to-Finn flow (deferred; manual paste stays the free-tier text path).
- Category tagging, theme presets.
- Fox outfits system, milestone unlocks.
- Social leaderboards, "friends are catching" features.
- Spend-over-time charts, category breakdowns, monthly hero total. **These are explicit anti-patterns.**
- Lottie or third-party animation libraries.
- Third-party analytics (PostHog, Amplitude, Mixpanel, anything).

---

## Appendix A — Doctrine Compliance Summary

UI/UX doctrine scored against every v1 surface:

| Surface | Grid | One action | Hierarchy | Feedback | Motion-w/-purpose |
|---|---|---|---|---|---|
| Onboarding | n/a | ✓ | ✓ | ✓ | ✓ |
| Home (quiet) | n/a | ✓ | ✓ | ✓ | ✓ |
| Home (watching) | partial | ✓ | ✓ | ✓ | ✓ |
| Home (urgent) | n/a | ✓ | ✓ | ✓ | ✓ |
| Subscriptions | ✓ | ✓ | ✓ | ✓ | ✓ |
| Trials (populated) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Trials (empty) | n/a | ✓ | ✓ | ✓ | ✓ |
| BillingCalendar | ✓ (7-col) | ✓ | ✓ | ✓ | ✓ |
| HuntSheet (entry) | ✓ (2-card) | ✓ | ✓ | ✓ | ✓ |
| HuntSheet (capture) | n/a | ✓ | ✓ | ✓ | ✓ |
| TrialDetail / SubDetail | n/a | ✓ | ✓ | ✓ | ✓ |
| Cancel-assist | n/a | ✓ | ✓ | ✓ | ✓ |
| Settings | n/a | n/a (menu) | ✓ | ✓ | ✓ |
| SavingsView | n/a | ✓ | ✓ | ✓ | ✓ |

---

## Appendix B — Mapping to Existing Linear Tickets

| Scope from this spec | Existing ticket | Action |
|---|---|---|
| Home (all 3 states) | COL-147 (P7) | Extend existing ticket scope |
| P10 audit fixes | COL-150 (P10) | Complete as scoped |
| Rename Subly → Finn | TBD | Cut dedicated ticket |
| MascotKit package | TBD | Cut dedicated ticket |
| VisionCapture package + HuntSheet | TBD | Cut dedicated epic (multi-phase) |
| IntelligenceCore package + 4 features | TBD | Cut dedicated epic (one ticket per feature) |
| BillingCalendar package + view | TBD | Cut dedicated ticket |
| SavingsView | TBD | Cut dedicated ticket |
| Onboarding rewrite | TBD | Cut dedicated ticket |
| Settings COL-139 + intelligence + Finn Pro | COL-139 | Extend existing ticket scope |
| Pro tier + paywall + entry caps | TBD | Cut dedicated epic |
| Final vector art | TBD (external or self) | Cut tracking ticket, block on illustrator decision |
| App icon + launch screen | TBD | Cut dedicated ticket, block on illustrator decision |
