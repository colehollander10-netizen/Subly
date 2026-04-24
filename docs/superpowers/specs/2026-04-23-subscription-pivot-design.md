# Subly — Subscription Pivot Design

**Status:** Validated brainstorm, ready for implementation planning
**Date:** 2026-04-23
**Supersedes:** Original brainstorm doc (`Subly — Subscription Pivot Brainstorm (v2)`)

---

## Thesis

Subly currently tracks free trials. This pivot extends the app to also track recurring subscriptions, without rebuilding what already works. The differentiation wedge is not features — every other subscription tracker has feature parity with the next. Subly's wedge is **a calm, opinionated app with a character at its core**, targeted at college students, manual-only (no bank access), and built around the emotional payoff of *catching* a trial before it charges.

The mascot is load-bearing, not decoration.

---

## Architecture & Data Model

### Unified `SublyEntry` model

One model, renamed from the current trial model. `entryType` is a mutable enum — a trial converting to a subscription flips `entryType` on the same row without creating a new entry. `status` tracks lifecycle independently.

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | existing |
| `serviceName` | String | existing (kept — spec originally said `name`, actual field is `serviceName`) |
| `senderDomain` | String | existing (logo lookup hint; carries forward) |
| `entryType` | `EntryType` enum | **NEW** — `.freeTrial` / `.subscription` |
| `status` | `Status` enum | **NEW** — `.active` / `.cancelled` / `.expired` |
| `chargeDate` | Date | **renamed from `trialEndDate`** — "when money leaves your account" |
| `chargeAmount` | Decimal? | existing (already optional — carries forward) |
| `billingCycle` | `BillingCycle?` enum | **NEW** — `.monthly` / `.yearly` / `.weekly` / `.custom`; nil for trials, required for subscriptions |
| `notificationOffset` | Int? | **NEW** — per-entry override in days; nil = use global default |
| `cancelledAt` | Date? | **NEW** — set when status flips to `.cancelled`; used for "Caught $X" window |
| `detectedAt` | Date | existing (carries forward — when the entry was captured) |
| `userDismissed` | Bool | existing (carries forward — orthogonal to `.status`, used by home-screen banner dismissal) |
| `trialLengthDays` | Int? | existing (carries forward — only meaningful for `.freeTrial` entries) |

**Model name:** The class stays `Trial` in v1 to minimize surface-area churn, but the class effectively represents a `SublyEntry`. A rename pass from `Trial → SublyEntry` is deferred to v1.1 once the pivot settles. This is a pragmatic trade: the class name is technically misleading for subscription rows, but a rename touches every call site and adds migration risk without user-visible payoff. The field `entryType` disambiguates at every read site.

### Status semantics

- `.active` — currently tracked
- `.cancelled` — user completed the cancel-assist flow and confirmed "I canceled it"
- `.expired` — trial `chargeDate` passed without a cancel; informational, does NOT count as "caught"

**Note on conversion:** `.converted` is explicitly NOT a status. A trial becoming a subscription is modeled as `entryType` flipping `.freeTrial → .subscription` on the same row, with `billingCycle` populated. `status` stays `.active` throughout. This preserves history on one row and keeps queries simple.

### SwiftData migration

`VersionedSchema` with one migration step:

1. Rename `trialEndDate → chargeDate`
2. Add new fields with defaults: `entryType: .freeTrial`, `status: .active`, `billingCycle: nil`, `notificationOffset: nil`, `cancelledAt: nil`

All existing trial data migrates cleanly with no data loss. Decide on this migration before writing any model code — doing it later is painful.

### Package impact

- **`SubscriptionStore`** — rename model, update fetch descriptors, add status/type scoped queries (e.g., `fetchActiveSubscriptions()`, `fetchCancelledThisMonth()`)
- **`TrialEngine`** — generalize urgency logic; it already keys off days-until-`chargeDate`, just needs to stop being type-specific internally. External package name stays for v1.
- **`NotificationEngine`** — per-entry offset support, type-aware copy templates, cancel-triggered notification cleanup, reschedule on `entryType` flip
- **`TrialParsingCore`** — no change in v1 (still parses trial emails). Subscription parsing lands in v1.1 via screenshot path.
- **`LogoService`** — no change

---

## Iconography Rule (revised)

Supersedes the prior rule that restricted Phosphor from the tab bar.

- **Phosphor everywhere by default** — tab bar, detail rows, section icons, inline glyphs. Use `.regular` weight for default state, `.fill` weight for selected/active. Use `.color()`, not `.foregroundStyle()`.
- **SF Symbols only where Apple HIG expects them** — OS-rendered chrome: keyboard accessories, search bar clear button, share sheet icons. Anywhere the OS renders the icon rather than the app.
- **Why:** Phosphor for app chrome differentiates the app visually; SF Symbols for OS chrome keeps the app feeling native when the OS takes over a surface.

### Caveat

Phosphor glyphs in tab bars render slightly less pixel-perfect than SF Symbols at 17–22pt because Apple hand-tunes SF Symbols for every tab-bar rendering context. Phosphor is an SVG pack — clean but not OS-tuned. At tab-bar sizes it still looks excellent; if something looks off at a specific size, adjust point size or weight rather than reverting.

---

## Tab Structure (4 tabs)

```
┌──────┬──────┬──────────────┬──────────┐
│ Home │Trials│Subscriptions │ Settings │
└──────┴──────┴──────────────┴──────────┘
```

Tabs use Phosphor icons, lavender tint for selected, `tertiaryText` for unselected.

| Tab | Phosphor icon (regular / fill) |
|---|---|
| Home | `HouseSimple` / `HouseSimpleFill` |
| Trials | `Clock` / `ClockFill` (prototype against `Hourglass` / `HourglassHigh`) |
| Subscriptions | `Repeat` / `RepeatFill` |
| Settings | `GearSix` / `GearSixFill` |

---

## HomeView Layout (H1 — trials-forward, subscriptions ambient)

Home is the urgency dashboard. Subscriptions have their own tab; on Home they appear only via the monthly spend card. This gives each surface a distinct job.

```
┌─────────────────────────────────────┐
│  Subly                      [gear] │
│  Thursday, April 23                 │
├─────────────────────────────────────┤
│                                     │
│  TRIALS ENDING SOON                 │  (conditional — only if any trial ≤7 days)
│  ┌────────────────────────────┐    │
│  │  FlagshipCard               │    │
│  │    logo · name · "Ends ..."│    │
│  │    $20.00  (hero number)   │    │
│  │    "Charges in 2 days"     │    │
│  │    [Cancel] alert row       │    │
│  └────────────────────────────┘    │
│  ┌────────────────────────────┐    │
│  │  SurfaceCard (if >1 ending)│    │
│  │    CompactRow · hairline   │    │
│  │    CompactRow              │    │
│  └────────────────────────────┘    │
│                                     │
│  [IF NO TRIALS ≤7 DAYS:             │
│   Sleeping fox card,                │
│   "You're clear for the next 7 days"]│
│                                     │
│  THIS MONTH                         │  (always present)
│  ┌────────────────────────────┐    │
│  │  $47.99                    │    │  hero treatment, monospacedDigit
│  │  6 subscriptions · 2 trials │    │
│  │  ────── hairline ───────── │    │
│  │  Caught $9.99 this month   │    │  (only when > $0)
│  └────────────────────────────┘    │
│                                     │
│                         [ + FAB ]   │
└─────────────────────────────────────┘
```

### Spend calculation (monthly, normalized)

- Monthly billing → amount as-is
- Yearly billing → amount ÷ 12
- Weekly billing → amount × 4.33
- Custom billing → treated as monthly for v1 (refine in v1.1)

### "Caught $X this month"

Sum of `chargeAmount` for entries where `status == .cancelled` AND `cancelledAt` is within the current calendar month. Row hidden when sum is $0.

### FAB behavior

- **Home FAB** → mini pre-sheet with two pill buttons: **Add Trial** / **Add Subscription**
- **Trials FAB** → opens Add Trial sheet directly
- **Subscriptions FAB** → opens Add Subscription sheet directly
- **Settings** → no FAB

---

## TrialsView (existing, lightly adapted)

- Header: "Trials" title, count metadata
- Groupings: "Ending this week" / "Ending this month" / "Later"
- Row action: tap → detail sheet with **Cancel** CTA launching cancel-assist flow
- FAB: Add Trial directly
- Urgency color ramp unchanged (existing DESIGN.md tokens)

---

## SubscriptionsView (new)

- Header: "Subscriptions" title, count + monthly total
- Groupings: "Charging this week" / "This month" / "Later" (mirrors TrialsView time-based model)
- Row action: tap → detail sheet with edit fields + standard delete (no cancel-assist — subscriptions aren't "caught")
- FAB: Add Subscription directly
- Rows use a calm-only color treatment — `urgencyCalm` by default, with a single `accent`-tinted highlight when charging within 2 days. Subscriptions do NOT use the trial urgency ramp (critical/day-of) — they are expected charges, not urgent events.

---

## Cancel-Assist Flow (trials only)

### Entry points

- Cancel button on trial detail sheet (NEW — does not yet exist in current `TrialsView.swift` detail; the implementation plan must add it)
- Cancel button on HomeView FlagshipCard alert row (NEW — the alert row exists in current HomeView; reuse for this trigger)

### Screen shape (full-screen sheet)

```
┌─────────────────────────────────────┐
│                          [✕ close]  │
│                                     │
│  How to cancel Spotify              │
│                                     │
│  [Curated steps card — SurfaceCard] │  (only if curated guide exists)
│    1. Open Spotify.com/account      │
│    2. Go to Subscription            │
│    3. Tap "Change or cancel"        │
│    4. Select "Cancel Premium"       │
│                                     │
│  [ Open Spotify.com → ]             │  (deep link, opens in Safari)
│                                     │
│  [ Search how to cancel Spotify → ] │  (always shown fallback)
│                                     │
│  ─────────────────────────────────  │
│                                     │
│   [ I canceled it ]   (primary)     │  lavender CTA
│   [ I'll do it later ]  (secondary) │  ghost button
│                                     │
└─────────────────────────────────────┘
```

### "I canceled it" flow

1. Entry `status` → `.cancelled`, `cancelledAt` → now
2. NotificationEngine removes all pending notifications for this entry
3. Sheet dismisses into full-screen `.proud` fox celebration (~2 seconds)
4. Celebration shows: fox illustration + "Caught $XX.XX" + entry name
5. Haptic: `.success` + custom pulse
6. Returns to origin (Home or Trials tab)

### "I'll do it later" flow

No state change. Dismiss sheet.

### Curated guide storage

- `Subly/Resources/CancelGuides.json` — bundled at build time
- Keyed by normalized service name (reuse `LogoService` normalization)
- v1 services (top 15): Spotify, Netflix, Hulu, Disney+, iCloud+, Apple Music, Amazon Prime, HBO Max, YouTube Premium, ChatGPT, Notion, Adobe Creative Cloud, Canva, Duolingo, Audible
- Entry schema: `{ steps: [String], directURL: String?, notes: String? }`
- Unknown service → hide curated-steps card, show only web-search fallback

---

## Add Entry Sheets

Two distinct sheets instead of one shared sheet with a type toggle. Each flow tuned to its type.

### Add Trial sheet

- Title: "Add Trial"
- Fields: SERVICE (name), TRIAL ENDS (quick-pick chips: 7 / 14 / 30 / 1 year / Custom + date display), CHARGE AMOUNT
- Paste-email prefill button at top (existing functionality)
- Save CTA

### Add Subscription sheet

- Title: "Add Subscription"
- Fields:
  - SERVICE (name)
  - NEXT BILLING DATE (date picker, defaults to 30 days from today)
  - BILLING CYCLE (segmented: Monthly / Yearly / Weekly / Custom)
  - CHARGE AMOUNT
- No paste-email prefill in v1 (subscription emails aren't the parser's strength — defer to screenshot import in v1.1)
- Save CTA

### Shared field components

Live in `Subly/AddEntry/Components/`:

- `ServiceNameField`
- `AmountField`
- `DatePickerField`

Both sheets use the same `GlassComponents` recipe, same haptics on save, same dismiss-on-success pattern.

---

## Notifications (type-aware)

| Type | Default offset | Copy template |
|---|---|---|
| Trial | 3 days before | `"Your {service} trial ends in 3 days — ${amount} charges on {date}"` |
| Trial | Day-of (secondary) | `"Your {service} trial charges today"` |
| Subscription | 1 day before | `"{service} renews tomorrow — ${amount}"` |

### Per-entry override

In the entry detail sheet, "Remind me X days before" picker with options: day-of, 1 day, 2 days, 3 days, 5 days, 1 week, off. Stored in `notificationOffset`.

### Lifecycle events

- **On cancel** (`status → .cancelled`) — remove all pending notifications for the entry
- **On `entryType` flip** (trial → subscription) — reschedule using subscription offset defaults, clear trial-specific notifications

---

## Fox System (v1)

### Name

TBD. Ship v1 with a working name; commit before App Store submission. Candidates: **Finn, Juno, Oats, Pilot, Miso, Olive, Pepper, Birch**. Working-name default: **Finn**.

### Code home (v1)

`Subly/Fox/` folder in main target. Promotes to `Mascot` Swift package in v1.1 when the milestone system lands.

```
Subly/Fox/
├── FoxView.swift          // one view, driven by FoxState
├── FoxState.swift         // enum
├── FoxAnimation.swift     // native SwiftUI animation helpers
└── Assets.xcassets         // fox frames / vectors
```

### State machine (v1)

| State | Where | Trigger |
|---|---|---|
| `.sleeping` | HomeView empty state | No trials ending ≤7 days |
| `.curious` | Settings header | Always when Settings tab active |
| `.happy` | Onboarding, bulk import | Each subscription added — minor reaction |
| `.veryHappy` | Onboarding, at milestones | 5, 10, 15 subs added during import |
| `.proud` | Cancel-it celebration | User confirms "I canceled it" |
| `.alert` | (reserved) | Unused in v1, defined for v1.1 milestones |

### Animation approach

Native SwiftUI, not Lottie. Composed fox illustration with state-driven transforms (ear wiggles, eye blinks, tail flicks) via `matchedGeometryEffect` and `withAnimation`. No dependency cost. If the fox becomes a marketing centerpiece in v1.1, upgrade to Lottie without changing the `FoxView` API.

### Placement audit

- ✅ OnboardingView — happiness meter during StoreKit bulk import
- ✅ HomeView empty state — sleeping fox card replaces "TRIALS ENDING SOON" when no trials ≤7 days
- ✅ SettingsView — small (~40pt) curious fox in header, idle blink every ~6s
- ✅ Cancel flow "I canceled it" confirmation — full-screen `.proud` celebration
- ❌ HomeView when trials/subs ARE present
- ❌ TrialsView / SubscriptionsView lists
- ❌ Entry detail / edit sheets
- ❌ Add Entry sheets

### Haptics

- `.proud` celebration — `.success` notification haptic + custom pulse
- Onboarding milestone at 5/10/15 — `.light` impact
- Settings / empty state — no haptic (ambient)

---

## StoreKit Bulk Import ("Import from Apple")

Free, v1. Covers App-Store-billed subscriptions only.

### Entry points

- Onboarding step
- Settings → "Import subscriptions" row

### Flow

1. Tap "Import from Apple"
2. App requests `Transaction.currentEntitlements` via StoreKit 2
3. Returns list of active App-Store-billed subscriptions
4. Confirmation sheet with a checkbox per row (pre-checked):
   - Service name (from `Product.displayName`)
   - Next billing date (from `renewalInfo.renewalDate`)
   - Amount (from `Product.price`)
   - Billing cycle (from `subscriptionPeriod.unit`)
5. User confirms → all checked entries saved as `.subscription` / `.active`
6. Fox state transitions during add: `.happy` each row, `.veryHappy` at 5/10/15
7. Success: "Imported X subscriptions" + fox `.veryHappy` hold ~2s

### Scope honesty

- **Can see:** anything billed through App Store — Apple Music, iCloud+, in-app Spotify, in-app Notion, in-app ChatGPT, any app subscription
- **Cannot see:** direct vendor billing — Netflix (direct), Substack, Adobe, most SaaS

The flow includes honest messaging: "This imports subscriptions billed through Apple. For others, add manually or use Scan Screenshot (coming soon)."

### Implementation

`StoreKitImport.swift` in main target (small surface, no new package). StoreKit 2, iOS 15+. Exposes `fetchCurrentEntitlements() async throws -> [ImportableSubscription]`.

---

## v1 Scope (LOCKED)

### IN v1

- Unified `SublyEntry` model + SwiftData migration (rename `trialEndDate → chargeDate`, add `entryType`, `billingCycle`, `notificationOffset`, `status`, `cancelledAt`)
- 4-tab bar with Phosphor icons
- HomeView rebuild (H1): trials-forward + spend card + "Caught $X" + sleeping-fox empty state
- TrialsView adapted (time-based groupings)
- SubscriptionsView new
- Add Trial sheet (cleaned up)
- Add Subscription sheet (new)
- Cancel-assist flow: full-screen sheet, curated guides for 15 services, web-search fallback, "I canceled it" / "I'll do it later"
- Proud fox celebration on cancel-it confirmation
- NotificationEngine: per-entry offset, type-aware copy, cancellation cleanup, reschedule on `entryType` flip
- TrialEngine: generalized urgency logic
- Fox v1: `FoxState` enum (6 states, 5 used), native SwiftUI `FoxView`, placements = onboarding / empty Home / settings / cancel celebration
- Fox named before App Store submission (working name: Finn)
- StoreKit "Import from Apple" (free)
- `CancelGuides.json` with 15 top services

### DEFERRED to v1.1+

- Screenshot bulk import (premium, on-device Vision)
- Milestone system + fox outfits + unlockable states + shareable cards
- Calendar / timeline view
- Category tagging
- Auto-advance `chargeDate` after billing cycle
- Automated trial → subscription conversion flow (manual edit works in v1)
- Yearly spend projection, per-category breakdown
- Lottie fox upgrade (if native version needs it)
- `Mascot` package extraction

---

## Suggested Build Order

1. Model migration + unified `SublyEntry` with new fields
2. SubscriptionStore updates (fetch descriptors, scoped queries)
3. NotificationEngine updates (per-entry offset, type-aware copy, lifecycle events)
4. TrialEngine generalization
5. 4-tab bar with Phosphor icons
6. SubscriptionsView new
7. Add Subscription sheet
8. Add Trial sheet cleanup (shared components)
9. Cancel-assist flow + `CancelGuides.json`
10. HomeView rebuild (H1 layout, spend card, "Caught $X")
11. Fox system: `FoxState`, `FoxView`, placements (empty Home → settings → cancel celebration → onboarding)
12. StoreKit bulk import
13. QA all existing trial flows — verify no regressions
14. Name the fox
15. Ship v1

---

## Out-of-Scope Notes for Future Brainstorms

- Screenshot import (C1) — on-device Vision + VisionKit OCR + parser extension. Premium feature. Defer to v1.1.
- Milestone system — shareable fox cards, outfits, unlock tiers. Defer to v1.1 as the retention/growth engine.
- Calendar / timeline view — H3 "smart single stack" style on HomeView or its own tab. Defer.
- Auto-advance billing cycle — background task that rolls `chargeDate` forward after a cycle passes. Defer, but worth thinking through the interaction with the migration model before v1 locks.

---

## Design System Compliance

All tokens, typography, spacing, glass recipes, and urgency color rules from `~/Developer/Subly/DESIGN.md` are load-bearing and must be followed exactly. This spec does not override `DESIGN.md`; it extends the existing component library (`GlassComponents.swift`) with:

- Phosphor tab bar (revised from prior SF Symbol constraint — see Iconography Rule above)
- `FoxView` new component (native SwiftUI)
- `CancelAssistSheet` new component
- `AddSubscriptionSheet` new component
- `SpendCard` on HomeView (uses existing hero number treatment + SurfaceCard)

If a new color, weight, or spacing is needed, add it to `SublyTheme` first before using it.
