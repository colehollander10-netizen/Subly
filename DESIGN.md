# Subly Design System

## Visual Direction

Subly is a **premium, calm financial utility** with a **dark liquid-glass aesthetic**. The goal is a single-purpose app that feels as polished and intentional as the ones users open every day without thinking — iMessage, Reminders, Sofa, Copilot Money, Flighty. Restrained, adult, opinionated, and built around one job: know before your trial charges you.

### Core principles

- **Dark charcoal base, lavender accent.** Not Copilot navy. Not Rocket Money loud. Our own thing.
- **Liquid glass as a significant theme, not everywhere.** Cards and surfaces use LG. Chrome, text, and interactive affordances do not.
- **Restraint over decoration.** Every pixel earns its place. No ornamental badges, no fake progress, no chartjunk.
- **Numbers are heroes.** The next charge amount is the most important pixel on the screen.
- **Haptics everywhere.** Taps, threshold crossings, sheet presents, section transitions. Perplexity-level ubiquity.
- **Two sharpened screens.** Home = what's about to charge you (<7 days). Trials = the full list.

---

## Color System (`SublyTheme` in `GlassComponents.swift`)

All values are dark-mode-only. There is no light variant.

| Token | Value (approx) | Usage |
|-------|----------------|-------|
| `background` | `#0E0F12` (deep charcoal, slight cool shift) | App background |
| `backgroundElevated` | `#14161A` | Sheet backgrounds, elevated contexts |
| `glassFill` | `white @ 4%` over background | Card fill (combined with `.ultraThinMaterial`) |
| `glassBorder` | `white @ 12%` | Card stroke (1pt) |
| `glassHighlight` | `white @ 18%` | Top-edge inner glow on cards |
| `primaryText` | `#F5F5F7` (near-white) | Headlines, hero numbers, active labels |
| `secondaryText` | `#A6A8B5` (desaturated lavender-grey) | Body copy, card subtitles |
| `tertiaryText` | `#6E7080` | Metadata, UPPERCASE section labels |
| `divider` | `white @ 8%` | Hairlines, row separators |
| `accent` | `#B8A4FF` (soft lavender) | Subly signature — used sparingly |
| `accentSoft` | `#B8A4FF @ 14%` | Accent fills, badge backgrounds |
| `urgencyCalm` | `#8FA3BE` (cool neutral) | 8+ days |
| `urgencyWarning` | `#F5B366` (amber) | 4–7 days |
| `urgencyCritical` | `#FF7A6B` (warm red) | 1–3 days |
| `urgencyDayOf` | `#FF5A4A` (saturated red) | Charges today |

**Urgency semantic** (`urgencyColor(daysLeft:)`):
- 0 days → `urgencyDayOf`
- 1–3 days → `urgencyCritical`
- 4–7 days → `urgencyWarning`
- 8+ days → `urgencyCalm`

**Accent usage rule:** Lavender is the brand — use it for the wordmark, the primary CTA fill, and one signature UI affordance per screen (the hero card's inner highlight, a selected tab indicator, etc.). **Never** use lavender for urgency states. Urgency owns its own color ramp.

**Never** introduce colors outside this token set. If you need a new semantic, add it here first.

---

## Typography

All type is system — **SF Pro Rounded** for display/numbers, **SF Pro Text** for body. No custom fonts. The premium feel comes from weight discipline and spacing, not the typeface.

| Role | Font | Size | Weight | Notes |
|------|------|------|--------|-------|
| Wordmark ("Subly") | SF Pro Rounded | 30 | `.heavy` | Header only |
| Screen title | SF Pro Rounded | 28 | `.bold` | E.g. "Trials" on TrialsView |
| Hero number | SF Pro Rounded | 56 | `.bold` | `.monospacedDigit()`, `minimumScaleFactor: 0.72` |
| Service name (flagship) | SF Pro Rounded | 22 | `.semibold` | |
| Service name (row) | SF Pro Text | 16 | `.semibold` | |
| Body | SF Pro Text | 15 | `.medium` | Default for subtitles, descriptions |
| Section label | SF Pro Text | 10 | `.semibold` | `UPPERCASE`, `tracking: 1.8` |
| Metadata / caption | SF Pro Text | 12 | `.medium` | Dates, counts |
| Pill text | SF Pro Rounded | 10 | `.bold` | `tracking: 0.8`, monospaced |

**Rule:** `.regular` weight is disallowed. Default body weight is `.medium` — it reads more intentional against dark backgrounds.

**Rule:** Only scale up from these. Never go below 12pt for anything legible. Never go above 56pt (the hero number is the ceiling).

---

## Liquid Glass Recipe

The canonical glass card composition:

```swift
RoundedRectangle(cornerRadius: 24, style: .continuous)
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(SublyTheme.glassFill) // white @ 4%
    )
    .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(SublyTheme.glassBorder, lineWidth: 1) // white @ 12%
    )
    .overlay(
        // Top-edge highlight for lit-from-within quality
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [SublyTheme.glassHighlight, .clear],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 1
            )
            .blendMode(.plusLighter)
    )
```

All cards route through `GlassCard`. `FlagshipCard` and `SurfaceCard` become thin wrappers that set padding, corner radius, and any urgency tint.

**Where liquid glass is used:**
- `FlagshipCard` (hero)
- `SurfaceCard` (grouped content)
- Floating nav / FAB containers
- Sheet backgrounds (subtle)
- Selected tab indicator

**Where liquid glass is not used:**
- Plain text rows inside a card (content, not surface)
- Buttons (flat lavender fill for primary, ghost for secondary)
- Pills (simple tinted capsule, no material)
- Icons / dividers

---

## Component Library (`GlassComponents.swift`)

### Cards
- `GlassCard` — the primitive. All other cards compose on this.
- `FlagshipCard` — hero "next ending trial". Only one per screen. `urgency: .calm | .warning | .critical` adds a soft inner glow on the right edge in the urgency color (not left-gradient — the number leads on the right).
- `SurfaceCard` — grouped content container. **Rows live inside one SurfaceCard**, not one card per row. This is the Copilot move that makes lists feel calm.
- `CompactTrialRow` — row inside a `SurfaceCard` (logo, name, date, urgency value). Rows are divided by `HairlineDivider`, not their own cards.

### Buttons
- `PrimaryButton` — lavender fill, **dark text** (`SublyTheme.background`), 16pt radius. Main CTA. Label uses the dark charcoal token, NOT near-white — lavender-on-white fails WCAG AA (2.05:1); lavender-on-dark-charcoal passes at ~10.7:1.
- `GhostButton` — transparent fill, 1pt lavender border, lavender text. Lavender-on-charcoal ~7.9:1 passes AA for 14pt.
- All buttons: `.frame(minHeight: 44)` to satisfy the 44pt touch-target minimum.
- `HeaderIconButton` — 40pt glass circle, icon inside. (40pt < 44pt is acceptable per HIG when icon button is paired with a larger tap area via `.contentShape(Rectangle())` or enlarged via padding; verify in ticket 4.)
- `PrimaryAddButton` — FAB, bottom-right, 62pt diameter, glass surface with lavender icon tint.

### Typography helpers
- `SectionLabel` — UPPERCASE section header. Replaces `TerminalSectionLabel`. Optional trailing count in monospaced digit.
- `AccentPill` — colored urgency badge ("3D LEFT", "TODAY"). Capsule, tinted fill @ 14%, 1pt tinted border.
- `HairlineDivider` — 1pt divider line at `SublyTheme.divider`.

### Icons
- `ServiceIcon` — brand logo with fallback monogram. Always use this. Sizes: `72` (flagship), `40` (standard), `32` (compact row).
- `ServiceIcon` background is dark, not light — logos are rendered over `glassFill` on dark, not over white.

### States
- `EmptyStateBlock` — empty state. No decorative illustration. Single sentence + one CTA.
- `BreathingModifier` — subtle pulse for urgent elements (3 days or less). Apply via `.breathing(days <= 3)`.

### Removed from previous system
- `TerminalButtonStyle`, `SecondaryTerminalButtonStyle` — replaced by `PrimaryButton` / `GhostButton`
- `TerminalSectionLabel` — renamed to `SectionLabel`
- Warm paper background, gradient blobs, color-wash "tint" on SurfaceCards — all removed

---

## Motion & Haptics

**Haptics are a signature feature.** Every meaningful interaction gets a haptic. Use `Haptics.play(_:)` from `Haptics.swift`.

| Event | Haptic |
|-------|--------|
| Any button / row tap | `.selection` (light tick) |
| Sheet present | `.impactLight` |
| Sheet dismiss | none |
| Tab switch | `.selection` |
| Scroll section boundary crossed | `.selection` |
| Swipe threshold crossed | `.impactMedium` |
| Trial marked cancelled | `.notificationSuccess` |
| Destructive action confirmed | `.notificationWarning` |
| Reminder scheduled | `.impactLight` |
| Pull to refresh triggered | `.impactMedium` |

**Motion:**
- All transitions: `.spring(response: 0.32, dampingFraction: 0.86)` unless specified.
- Press: `scaleEffect(0.975)` + `opacity(0.92)`, spring `response: 0.22, dampingFraction: 0.82`.
- Breathing (urgent): 2s ease-in-out, scale 1.0 ↔ 1.03, repeat forever.
- No decorative motion. Everything animates in response to user intent.
- Respect `@Environment(\.accessibilityReduceMotion)` — if true, replace spring transitions with instant state changes and disable parallax/stagger.

---

## Motion Choreography

Intentional motion is a signature of apps people open every day. The rule: **break complex animations into small, sequenced sub-animations**, each 100–200ms. Never animate a whole screen's worth of change as one large transition — it reads cheap. Stage it. Each sub-animation must serve user comprehension (what changed? where did it go?).

### Principles

1. **Stage, don't dump.** When a hero card first appears, it is NOT one fade-in. It is: card slide+fade (200ms) → divider draws left-to-right (150ms) → number scales from 0.9 → 1.0 (150ms, delayed 100ms after card) → pill fades in (100ms, delayed 200ms). Total time budget ≤ 500ms.
2. **Sub-animations are reliably implementable.** Break transitions into named `withAnimation` blocks chained via `.delay()` or separate `@State` triggers with staggered `onAppear`. Avoid one giant custom `AnimatablePair`.
3. **Numbers count, don't swap.** Any hero numeric value uses `.contentTransition(.numericText())` — the digits flip in place when the amount updates.
4. **Navigation is directional.** Tab switch = crossfade + 4pt subtle scale from 0.98 → 1.0 (feels like "settling in"). Sheet present = spring from bottom with 0.02 overshoot. Sheet dismiss = straight linear dismiss, no overshoot (feels slower if overshoot dismissal).
5. **Response to user intent, never decoration.** No looping animations except `Breathing` on urgent items. No confetti. No fake progress.
6. **Async state changes animate too.** When a trial's urgency tier crosses a threshold (e.g., 4 days → 3 days, so color flips warning → critical), animate the color over 400ms `.easeInOut`. Don't just hard-switch.

### Transition recipes (canonical)

| Event | Recipe |
|-------|--------|
| Screen first appears | Container slides up 24pt + fades in, 350ms spring. Child sections stagger in at +80ms each. |
| Hero card content update | `.contentTransition(.numericText())` for amount. Pill fades 200ms. Card itself does not reflow. |
| Sheet present | Spring `response: 0.36, dampingFraction: 0.84`, slight overshoot. Content fades in on beat 2 (delay 80ms). |
| Sheet dismiss | Linear 250ms, no bounce. |
| Tab switch | 160ms crossfade + scale 0.98 → 1.0 on the incoming tab. |
| Row tap → detail sheet | Row lifts (shadow opacity 0 → 0.15) 60ms BEFORE the sheet begins presenting. |
| Urgency color shift | `.easeInOut(duration: 0.4)` on the foreground/background color transition. |
| Onboarding page transition | Horizontal slide with parallax: foreground moves at `translationX`, background at `translationX * 0.6`. |
| Add-trial save success | Form collapses (200ms), card rises from form's position into the list (400ms spring), list items re-order (300ms). Three sub-animations, sequenced. |

### Reduced motion

When `accessibilityReduceMotion` is true:
- All springs → `.none` (instant)
- Parallax → disabled (foreground and background move together)
- Stagger delays → 0 (everything appears simultaneously)
- `.contentTransition(.numericText())` stays (it's an identity transition when motion is reduced)
- Press feedback (`scaleEffect(0.975)`) stays — it's a tap confirmation, not decoration

---

## Layout Rules

- **Horizontal padding:** `20` on all screen-level content.
- **Bottom padding:** `120` on scroll content (clears FAB).
- **Top padding:** `16` after safe area.
- **Card corner radius:** `28` (flagship), `24` (surface), `18` (row inside card).
- **Card padding:** `22` (flagship), `18` (surface), `14` (compact row).
- **Spacing between sections:** `24`.
- **Spacing within a card:** `14–18`.
- **Section label → content:** `12`.

---

## Screen Anatomy

### HomeView — "What's about to charge you"

Scope: trials ending in **≤7 days**. If nothing is ending soon, show a calm empty state directing user to Trials.

```
Header
  └─ [Subly wordmark (lavender)]        [gear icon]
  └─ small date stamp underneath wordmark

FlagshipCard (next ending trial)
  └─ Service icon (72pt) · Service name · Renews date
  └─ Hero number ($18.99) — 56pt rounded bold
  └─ "Charges in 3 days" — urgency-colored
  └─ HairlineDivider
  └─ Next alert row (bell + relative time)
  └─ Swipe-to-cancel hint (if not demo)

SectionLabel "Also this week"
SurfaceCard
  └─ CompactTrialRow
  └─ HairlineDivider
  └─ CompactTrialRow
  └─ ...

FAB (bottom-right, outside scroll): PrimaryAddButton
```

Removed from previous: demoBanner, statusLine. Demo data is gone entirely (see COL-105 onboarding).

### TrialsView — "The full list"

Scope: all active trials, grouped.

```
Header
  └─ "Trials" title
  └─ small subtitle (trial count)

SectionLabel "Ending soon" (≤7 days)
SurfaceCard
  └─ rows, HairlineDivider between

SectionLabel "Later" (>7 days)
SurfaceCard
  └─ rows, HairlineDivider between

FAB (bottom-right): PrimaryAddButton
```

Rows are **tappable** to open the trial detail sheet. Rows on HomeView are **not** tappable — Home is read-only urgency awareness; Trials is the management surface.

### SettingsView — "Preferences"

Scope: notification offset, manual add access, data export/delete. All Gmail/email/connected-account UI is removed.

```
Header
  └─ "Settings" title

SectionLabel "Notifications"
SurfaceCard
  └─ Notification offset preference
  └─ HairlineDivider
  └─ Test notification button

SectionLabel "Data"
SurfaceCard
  └─ Export trials
  └─ HairlineDivider
  └─ Delete all data

SectionLabel "About"
SurfaceCard
  └─ Version
  └─ HairlineDivider
  └─ Privacy policy link
```

---

## Tab Bar

Native-feel bottom tab bar, 3 tabs: **Home** / **Trials** / **Settings**. Selected tab icon + label tint: `SublyTheme.accent` (lavender). Unselected: `SublyTheme.tertiaryText`. Tab bar background: glass material.

Do not replace this with a top pill selector. The bottom tab bar is part of what makes the app feel native.

---

## Do's and Don'ts

**Do:**
- Use `ScreenFrame` as the root wrapper — it provides the dark background.
- Use `GlassCard` for any surface; `FlagshipCard` / `SurfaceCard` as composed helpers.
- Use `ServiceIcon` for all brand logos.
- Apply `urgencyColor(daysLeft:)` for any urgency-based color.
- Use `.medium` weight as the body default; never `.regular`.
- Wire `Haptics.play(_:)` on every meaningful interaction.
- Keep the hero number the largest pixel on the screen (56pt, monospaced).

**Don't:**
- Use warm/paper colors or light backgrounds — wrong aesthetic direction.
- Hardcode colors outside `SublyTheme`.
- Use lavender for urgency — lavender is brand only.
- Put each trial in its own card. Group rows into one `SurfaceCard`.
- Add decorative UI that doesn't carry information.
- Add confetti, illustrations, or celebrations. Subly is calm.
- Show more than one `FlagshipCard` per screen.
- Use SF Pro Text for numbers. Numbers are always SF Pro Rounded.

---

## Migration Checklist (from warm-paper DESIGN.md)

- [ ] Replace `SublyTheme` values with dark palette
- [ ] Replace `AppBackground` — solid `SublyTheme.background`, no gradients, no blur blobs
- [ ] Add `GlassCard` primitive; make `FlagshipCard`/`SurfaceCard` wrap it
- [ ] Change `ServiceIcon` background to glass-over-dark
- [ ] Rename `TerminalSectionLabel` → `SectionLabel`
- [ ] Replace `TerminalButtonStyle` / `SecondaryTerminalButtonStyle` with `PrimaryButton` / `GhostButton`
- [ ] Update all hero numbers to `SF Pro Rounded` `.bold` 56pt
- [ ] Wire haptics map per table above
- [ ] Kill `DemoContent` from live surfaces (gated behind a dev-only flag, not `showDemoData` in production)
- [ ] Strip demoBanner + statusLine from HomeView
- [ ] Collapse row-cards into grouped `SurfaceCard` with `HairlineDivider`
- [ ] Remove all connected-account/Gmail/email UI from SettingsView

Each checklist item is a self-contained Cursor ticket. Do not bundle.
