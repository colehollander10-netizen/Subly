# COL-125 — HomeView redesign design

**Ticket:** COL-125
**Date:** 2026-04-23
**Epic:** COL-120 (v2 redesign)

---

## Purpose

Home's one job: **"what's about to charge you in the next 7 days."** Nothing more. Post-pivot, the screen is cluttered with holdover chrome (demo banner, status line, verbose cancellation hints, redundant gear icon). Strip it to a single calm surface.

The retention thesis: users don't come back to Finn because Home is engaging. They come back because Finn reliably warns them before a charge, and Home should radiate *"you're safe, nothing to worry about this week"* when it's quiet. Sparse-on-purpose.

## Scope

Rewrite `Finn/HomeView.swift` per the DESIGN.md § Screen Anatomy → HomeView spec, incorporating four product decisions:

| # | Decision |
|---|----------|
| 1 | Empty state: "Nothing charging soon." + subtitle. No CTA. |
| 2 | No swipe-to-cancel. Tap hero → detail sheet → "Mark cancelled" button inside sheet. |
| 3 | Hide "Also this week" entirely when only hero trial exists. |
| 4 | Remove gear icon from header. Settings accessible only via tab bar. |

Plus: reserve a 120pt slot in the empty state for the future fox mascot (COL-132).

## Non-scope

- Haptics wiring (COL-128)
- Motion choreography (COL-131)
- Actual fox mascot rendering (COL-132 — just reserve the slot with a neutral placeholder)
- Tab bar styling (COL-129)
- TrialsView changes (COL-126)
- Any SwiftData schema changes

## Target layout

### Header

```
[small date stamp: Apr 23]
[Finn wordmark: 30pt rounded heavy, lavender]
```

No subtitle tagline. No gear icon. No right-side element. Centered-left, clean.

### Hero card (trial exists, ending ≤7 days)

Unchanged visual spec (FlagshipCard, 28pt radius, glass, urgency inner-right glow). Content order:
1. ServiceIcon (72pt) + service name + renews date row
2. HairlineDivider
3. Hero charge amount (56pt rounded bold, monospaced) + "Charges in N days" in urgency color
4. Next alert row (bell icon + relative time)

**Removed** from current:
- "Cancellation path ready / Swipe left to open..." block
- "Preview trial / Add a real trial to enable..." block when in demo mode
- Horizontal drag gesture + `horizontalDrag`/`dragCrossedThreshold` state

**Added** tap behavior: entire FlagshipCard is a Button that opens the existing `TrialDetailSheet` for `nextTrial`.

### "Also this week" section

**Shown only if** `upcomingAfterHero.count >= 1` (trials 2–4 in the 7-day window).

```
ALSO THIS WEEK  [n]
[SurfaceCard containing up to 3 CompactTrialRows, separated by HairlineDividers]
```

Rows inside the SurfaceCard (grouped pattern from COL-126, but Home's version). Each row tappable → opens `TrialDetailSheet`.

**Hidden entirely** if only hero exists or empty state applies.

### Empty state (no trials ending ≤7 days)

```
                    [120pt mascot slot — placeholder for COL-132]

              Nothing charging soon.

    The next 7 days are clear. Your full list lives in Trials.
```

Centered vertically and horizontally within available scroll height. No button. No link. Calm.

**Placeholder rendering until COL-132 lands:**
```swift
Image(systemName: "moon.stars.fill")
    .font(.system(size: 64, weight: .light))
    .foregroundStyle(FinnTheme.accent.opacity(0.4))
    .frame(width: 120, height: 120)
```

This slot must be a single clear location in the code (e.g. a `heroMascotSlot` view property) so COL-132 swaps in `FoxMascot(state: .sleeping)` with a one-line change.

### FAB (unchanged)

`PrimaryAddButton` bottom-right, 62pt, opens `TrialDetailSheet` in create mode. No changes from current — COL-129 restyles it.

## Data scope change

Current query:
```swift
@Query(
    filter: #Predicate<Trial> { !$0.userDismissed },
    sort: \Trial.trialEndDate,
    order: .forward
) private var activeTrials: [Trial]
```

New query: same, but `displayedActiveTrials` no longer falls back to `DemoContent`. When empty, we show the empty state.

**Derived:**
- `nextTrial`: first trial where `daysUntil(trialEndDate) <= 7`, else nil
- `upcomingAfterHero`: next 3 trials where `daysUntil(trialEndDate) <= 7`, after `nextTrial`
- If `nextTrial == nil` → empty state
- If `upcomingAfterHero.isEmpty` → hide "Also this week" section entirely

## State removed

- `@AppStorage(AppPreferences.showDemoData) var showDemoData` — no longer referenced in HomeView
- `@State private var showingSettings` — settings no longer sheet-opened from Home
- `@State private var horizontalDrag: CGFloat` — drag gesture removed
- `@State private var dragCrossedThreshold: Bool` — drag gesture removed
- `@State private var selectedCancelTrial: Trial?` — cancellation moves to detail sheet
- `.sheet(item: $selectedCancelTrial)` presenting CancelFlowSheet — cancellation from Home no longer uses a separate sheet; user taps hero → detail sheet → in-sheet "Mark cancelled"

## State preserved

- `@Environment(AppRouter.self) var appRouter` — still needed for `pendingCancelTrialID` deep-link routing
- `resolvePendingNotificationRoute()` still runs `onAppear` and on `pendingCancelTrialID` change, BUT now routes by opening the detail sheet for the target trial (not the cancel sheet directly)
- `@State private var selectedTrial: Trial?` — new; drives the detail sheet
- `@State private var showingManualAdd: Bool` — unchanged, drives add-trial sheet from FAB

## Notification deep-link routing change

Current: notification tap → AppRouter sets `pendingCancelTrialID` → HomeView `resolvePendingNotificationRoute` opens `CancelFlowSheet` directly.

New: notification tap → AppRouter sets `pendingCancelTrialID` (rename optional but not required for this ticket) → HomeView opens `TrialDetailSheet` for that trial. The "Mark cancelled" button lives inside the detail sheet.

**Important:** this depends on `TrialDetailSheet` surfacing a "Mark cancelled" action. If it doesn't today, this ticket does NOT add it — we create a follow-up if needed. Check before implementing.

## Error handling

No new error paths introduced. SwiftData read failures propagate as empty `activeTrials` (existing behavior).

## Accessibility

- Hero card as Button: `.accessibilityLabel("\(nextTrial.serviceName), charges \(relativeDateString), \(formatUSD(amount))")`
- Empty state: `.accessibilityElement(children: .combine)` so screen readers announce the full message
- Mascot placeholder: `.accessibilityHidden(true)` — decorative
- Wordmark: `.accessibilityLabel("Finn")`

## File changes

| File | Change |
|------|--------|
| `Finn/HomeView.swift` | Full rewrite per above |
| `Finn/GlassComponents.swift` | None. CompactTrialRow already exists and works |
| `Finn/Sheets.swift` | Verify `TrialDetailSheet` exposes a "Mark cancelled" action; if absent, flag as follow-up (do NOT implement in this ticket) |

No new files. No new types. No new dependencies.

## Acceptance

- [ ] Hero card is a tappable Button that opens `TrialDetailSheet` for `nextTrial`
- [ ] No drag gesture, no `horizontalDrag` state, no `CancelFlowSheet` presented from HomeView
- [ ] "Also this week" section hidden when `upcomingAfterHero.isEmpty`
- [ ] Empty state renders with 120pt placeholder (moon.stars.fill, lavender 40% opacity) when `nextTrial == nil`
- [ ] Gear icon and `showingSettings` removed from HomeView
- [ ] No `showDemoData` / `DemoContent` / `demoBanner` / `statusLine` references remain in HomeView
- [ ] Notification deep-link routing opens `TrialDetailSheet`, not `CancelFlowSheet`
- [ ] Build passes (`xcodebuild ... build`)
- [ ] App launches on simulator, empty state visible when no trials, hero card visible when trials exist

## Verification

After code lands:
1. `xcodebuild -project Finn.xcodeproj -scheme Finn -destination 'generic/platform=iOS Simulator' build` — must succeed
2. Open in simulator with no trials in SwiftData → empty state visible, centered
3. Add a trial ending in 3 days → hero card visible, tap opens detail sheet
4. Add 3 more trials ending in 4/5/6 days → "Also this week" section appears with all 3
5. Remove all trials → empty state returns
