# Finn Design System (v1 — vulpine palette, locked 2026-04-29)

> Brand-level constraints live in `docs/superpowers/specs/2026-04-29-finn-brand-foundation-design.md`. This doc is the design-system layer — colors, type, components, spacing, motion. Re-read the brand foundation before changing anything here.

## Relationship to Brand Foundation

The Brand Foundation governs **voice, fox rules, reference lane, and the three adjectives (Quiet · Tactile · Warm)**. This document governs **tokens, components, spacing, and motion**. They are layered: brand sits above design system. If they conflict, the Brand Foundation wins — re-open it and reconcile this doc, not the other way around.

## Visual Direction

Finn is a **subscription and free-trial tracker that takes the stress out of recurring spending — and makes the act of managing it genuinely satisfying.** The interface is **Quiet · Tactile · Warm**: low chroma on a warm-charcoal base, a single vulpine accent, springs and haptics on every meaningful interaction, and a friendly tone that earns the fox its keep.

Reference lane: **Things 3 (hard)** for pixel rhythm, hierarchy, and discipline; **Sofa (soft)** only for empty-state warmth and onboarding tone.

### Core principles

- **One accent, used sparingly.** Vulpine orange is the brand. Urgency owns its own ramp.
- **Liquid glass as a significant theme, not everywhere.** Cards and surfaces use LG. Chrome, text, and interactive affordances do not.
- **Restraint over decoration.** Every pixel earns its place. No ornamental badges, no fake progress, no chartjunk.
- **Numbers are heroes.** The next charge amount is the most important pixel on the screen.
- **Haptics everywhere.** Taps, threshold crossings, sheet presents, section transitions. Perplexity-level ubiquity.

---

## Fox

Five lines. Full rules in the Brand Foundation (`docs/superpowers/specs/2026-04-29-finn-brand-foundation-design.md`).

- **Three allowed surfaces:** onboarding, empty states, and "Charges in 1 day" urgent nudges. Plus app icon and About/Settings footer for identity.
- **Three moods:** Neutral / Concerned / Sleeping. Swap states, never morph.
- **Vector only.** No raster, no 3D, no Pixar shading.
- **Head-and-bust silhouette is default.** Full body allowed only in onboarding hero moments.
- **The fox does not speak.** No speech bubbles, no captioned dialogue. Microcopy near the fox comes from the *app*, not the *fox*.

Banned everywhere else: HomeView flagship, TrialsView, data-dense surfaces, buttons, pills, inputs, loading indicators, tab bar.

---

## Color System (`FinnTheme` in `GlassComponents.swift`)

All values are dark-mode-only on a **warm charcoal** base. There is no light variant.

| Token | Value | Usage |
|-------|-------|-------|
| `background` | `#1A1614` (warm charcoal) | App background |
| `backgroundElevated` | `#221E1B` (warmer elevated) | Sheet backgrounds, elevated contexts |
| `glassFill` | `white @ 4%` over background | Card fill (combined with `.ultraThinMaterial`) |
| `glassBorder` | `white @ 12%` | Card stroke (1pt) |
| `glassHighlight` | `white @ 18%` | Top-edge inner glow on cards |
| `primaryText` | `#FBF7F2` (warm cream) | Headlines, hero numbers, active labels |
| `secondaryText` | `#B8AFA7` (warm desaturated grey) | Body copy, card subtitles |
| `tertiaryText` | `#827A72` (warm metadata) | Metadata, UPPERCASE section labels |
| `divider` | `white @ 8%` | Hairlines, row separators |
| `accent` | `#F97316` (vulpine orange) | Finn signature — used sparingly |
| `accentSoft` | `#F97316 @ 14%` | Accent fills, badge backgrounds |
| `urgencyCalm` | `#8FA3BE` (cool neutral) | 8+ days |
| `urgencyWarning` | `#F5B366` (amber) | 4–7 days |
| `urgencyCritical` | `#FF7A6B` (warm red) | 1–3 days |
| `urgencyDayOf` | `#FF5A4A` (saturated red) | Charges today |

**Urgency semantic** (`urgencyColor(daysLeft:)`):
- 0 days → `urgencyDayOf`
- 1–3 days → `urgencyCritical`
- 4–7 days → `urgencyWarning`
- 8+ days → `urgencyCalm`

**Accent usage rule:** **Vulpine is the brand** — use it for the wordmark, the primary CTA fill, and one signature UI affordance per screen (the hero card's inner highlight, a selected tab indicator, etc.). **Never** use vulpine for urgency states. Urgency owns its own color ramp. Amber (`urgencyWarning`) and vulpine sit close on the hue wheel — keep them separated by role: vulpine = brand, amber = 4–7 day urgency. Never use them adjacent on the same surface.

**Never** introduce colors outside this token set. If you need a new semantic, add it here first.

---

## Typography

All type is system — **SF Pro Rounded** for display/numbers, **SF Pro Text** for body. No custom fonts. The premium feel comes from weight discipline and spacing, not the typeface.

| Role | Font | Size | Weight | Notes |
|------|------|------|--------|-------|
| Wordmark ("Finn") | SF Pro Rounded | 30 | `.heavy` | Header only |
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
            .fill(FinnTheme.glassFill) // white @ 4%
    )
    .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(FinnTheme.glassBorder, lineWidth: 1) // white @ 12%
    )
    .overlay(
        // Top-edge highlight for lit-from-within quality
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [FinnTheme.glassHighlight, .clear],
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
- Buttons (flat vulpine fill for primary, ghost for secondary)
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
- `PrimaryButton` — **vulpine fill**, **warm-charcoal label** (`FinnTheme.background`), 16pt radius. Main CTA. Label uses the warm-charcoal token, NOT cream — vulpine-on-cream fails WCAG AA; **vulpine `#F97316` on warm charcoal `#1A1614` passes AA at ~6.6:1** (verified against the actual hex values; comfortably above the 4.5:1 normal-text threshold and the 3:1 large-text threshold).
- `GhostButton` — transparent fill, 1pt vulpine border, vulpine label text. Vulpine-on-warm-charcoal at ~6.6:1 passes AA for normal and large text.
- All buttons: `.frame(minHeight: 44)` to satisfy the 44pt touch-target minimum.
- `HeaderIconButton` — 40pt glass circle, icon inside. (40pt < 44pt is acceptable per HIG when the icon button is paired with a larger tap area via `.contentShape(Rectangle())` or enlarged via padding; verify in ticket 4.)
- `PrimaryAddButton` — FAB, bottom-right, 62pt diameter, glass surface with vulpine icon tint.

### Typography helpers
- `SectionLabel` — UPPERCASE section header. Replaces `TerminalSectionLabel`. Optional trailing count in monospaced digit.
- `AccentPill` — colored urgency badge ("3D LEFT", "TODAY"). Capsule, tinted fill @ 14%, 1pt tinted border.
- `HairlineDivider` — 1pt divider line at `FinnTheme.divider`.

### Icons
- **Phosphor everywhere** in app-owned UI via `Ph.<name>.<weight>.color(...)` — never `.foregroundStyle()`, never `.resizable()`. Exception: SwiftUI `.tabItem` slot uses SF Symbols (the slot doesn't honor custom views).
- `ServiceIcon` — brand logo with fallback monogram. Always use this. Sizes: `72` (flagship), `40` (standard), `32` (compact row).
- `ServiceIcon` background is dark, not light — logos render over `glassFill` on warm charcoal, not over white.

### States
- `EmptyStateBlock` — empty state. The fox is allowed here (Sleeping mood for "nothing ending soon", Neutral for first-run). Single sentence + one CTA. No decorative illustration beyond the fox.
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

Scope: trials ending in **≤7 days**. If nothing is ending soon, show a calm empty state directing user to Trials. The fox (Sleeping mood) is allowed in this empty state only.

```
Header
  └─ [Finn wordmark (vulpine)]        [gear icon]
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

If the flagship trial charges in **1 day**, a small Concerned-mood fox is permitted near the urgency line — the only place the fox appears inside an active screen. Removed from previous: demoBanner, statusLine. Demo data is gone entirely (see COL-105 onboarding).

### TrialsView — "The full list"

Scope: all active trials, grouped. **Fox is banned on this surface** — TrialsView is the management surface and the fox would distract from the list.

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

Scope: notification offset, manual add access, data export/delete. All Gmail/email/connected-account UI is removed. Neutral-mood fox allowed in the About footer only — identity, not interaction.

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
  └─ Small Neutral-mood fox in footer
```

---

## Tab Bar

Native-feel bottom tab bar, 3 tabs: **Home** / **Trials** / **Settings**. Selected tab icon + label tint: `FinnTheme.accent` (vulpine). Unselected: `FinnTheme.tertiaryText`. Tab bar background: glass material. Tab bar uses SF Symbols (SwiftUI `.tabItem` exception); everywhere else is Phosphor. **No fox in the tab bar.**

Do not replace this with a top pill selector. The bottom tab bar is part of what makes the app feel native.

---

## Do's and Don'ts

**Do:**
- Use `ScreenFrame` as the root wrapper — it provides the warm-charcoal background.
- Use `GlassCard` for any surface; `FlagshipCard` / `SurfaceCard` as composed helpers.
- Use `ServiceIcon` for all brand logos.
- Apply `urgencyColor(daysLeft:)` for any urgency-based color.
- Use `.medium` weight as the body default; never `.regular`.
- Wire `Haptics.play(_:)` on every meaningful interaction.
- Keep the hero number the largest pixel on the screen (56pt, monospaced).
- Use Phosphor icons in app-owned UI; SF Symbols only inside `.tabItem`.

**Don't:**
- Use warm/paper colors or light backgrounds — wrong aesthetic direction.
- Hardcode colors outside `FinnTheme`.
- Use vulpine for urgency — vulpine is brand only.
- Put each trial in its own card. Group rows into one `SurfaceCard`.
- Add decorative UI that doesn't carry information.
- Add confetti, illustrations, or celebrations. Finn is calm.
- Show more than one `FlagshipCard` per screen.
- Use SF Pro Text for numbers. Numbers are always SF Pro Rounded.
- Use the fox outside its three allowed surfaces (onboarding, empty states, "Charges in 1 day" nudges) plus app icon and About footer.

---

## Reconciliation completed 2026-04-29

This file was reconciled against the locked Brand Foundation on 2026-04-29. The previous lavender palette (`#B8A4FF` accent on `#0E0F12` cool charcoal) is superseded by the vulpine palette (`#F97316` accent on `#1A1614` warm charcoal). Warm-text tokens (`primaryText`, `secondaryText`, `tertiaryText`) were re-toned to match the warmer base. Urgency ramp, motion choreography, haptics map, layout rules, liquid glass recipe, and screen anatomy survived unchanged — they were brand-foundation-compatible from the start. Going forward, this doc is the design-system layer; the Brand Foundation is the authority above it.
