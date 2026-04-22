# Subly Design System

## Visual Direction

Subly is a **premium, calm financial utility**. The aesthetic is warm off-white paper — not dark glassmorphism. Think: a high-end receipt, a Notion doc, a well-designed bank statement. Light, airy, with sharp typographic hierarchy and semantic color only where it earns it.

Reference: `~/Downloads/Subly Inso Screenshots/` — pull urgency semantics and detail density from those; pull the light background and paper feel over the dark gradient backgrounds.

---

## Color System (`SublyTheme` in `GlassComponents.swift`)

| Token | Usage |
|-------|-------|
| `background` | App background — warm off-white `rgb(240, 237, 230)` |
| `surface` | Cards, rows — near-white `rgb(252, 250, 248)` |
| `elevated` | Flagship card, modals — pure white |
| `primaryText` | Headings, labels |
| `secondaryText` | Subtitles, dates |
| `tertiaryText` | Section labels, metadata |
| `divider` | Hairlines, card borders |
| `accent` | Green — safe/calm state (active, confirmed) |
| `accentSoft` | Green tint — accent backgrounds |
| `highlight` | Gold — notable but not urgent |
| `warning` | Amber — 4–7 days |
| `critical` | Red — 1–3 days |
| `dayOf` | Deep red — charges today |
| `ink` | Near-black — hero numbers only |

**Urgency semantic** (already implemented in `urgencyColor(daysLeft:)`):
- 0 days → `dayOf`
- 1–3 days → `critical`
- 4–7 days → `warning`
- 8+ days → `accent`

**Never** use arbitrary colors outside this token set. If you need a new semantic, add it to `SublyTheme` first.

---

## Typography

All type is system (`SF Pro`). No custom fonts.

| Role | Size | Weight | Notes |
|------|------|--------|-------|
| App title | 34 | `.black` | "Subly" header |
| Hero number | 50 | `.bold` | `.monospacedDigit()`, `minimumScaleFactor: 0.72` |
| Service name (flagship) | 28 | `.bold` | |
| Service name (row) | 15 | `.semibold` | |
| Body | 15 | `.regular` | |
| Section label | 10 | `.medium` | `UPPERCASE`, `tracking: 2.2` |
| Metadata / caption | 12 | `.medium` | dates, scan status |
| Pill text | 10 | `.bold` | `tracking: 0.8`, monospaced |

**Rule:** only scale up from these. Never make body text smaller than 12pt.

---

## Component Library (`GlassComponents.swift`)

### Cards
- `FlagshipCard` — hero "next ending trial". Only one per screen. Supports `urgency: .calm | .warning | .critical` for left-edge gradient.
- `SurfaceCard` — standard content card. Optional `tint` for soft color wash. Optional `emphasized` for deeper shadow.
- `CompactTrialRow` — list row with logo, name, date, urgency badge.

### Buttons
- `TerminalButtonStyle` — primary CTA. Dark fill, white text.
- `SecondaryTerminalButtonStyle` — secondary. White fill, border, no fill color.
- `HeaderIconButton` — 40pt circle icon button for nav bar actions.
- `PrimaryAddButton` — FAB (floating action button). Bottom-right. 62pt diameter.

### Typography helpers
- `TerminalSectionLabel` — section header with optional trailing count.
- `AccentPill` — colored urgency badge (e.g., "3D LEFT", "TODAY").
- `HairlineDivider` — 1pt divider line.

### Icons
- `ServiceIcon` — brand logo with fallback initial. Always use this — never raw `AsyncImage`.
- Sizes: `64` (flagship), `40` (standard), `32` (compact row).

### States
- `EmptyStateBlock` — empty state with icon, title, message, optional CTA.
- `BreathingModifier` — subtle pulse for urgent pills (3 days or less). Apply via `.breathing(days <= 3)`.

---

## Layout Rules

- **Horizontal padding:** `20` on all screen-level content.
- **Bottom padding:** `120` on scroll content (clears FAB).
- **Card corner radius:** `28` (flagship), `22` (surface), `18` (row).
- **Spacing between sections:** `20`.
- **Spacing within a card:** `14–18`.

---

## Screen Anatomy

### HomeView
```
Header (date + title + subtitle + icon buttons)
  → DemoBanner (if showing demo data)
  → HeroSection (FlagshipCard — next ending trial)
  → ComingUpSection (CompactTrialRow list)
  → StatusLine (scan status / error)
FAB (bottom-right, outside scroll)
```

### TrialsView
- Full list of active trials
- Same `CompactTrialRow` pattern
- Empty state when no trials

### SettingsView
- Connected accounts
- Preferences
- Use `SurfaceCard` for grouped settings sections

---

## Do's and Don'ts

**Do:**
- Use `ScreenFrame` as the root wrapper on every screen — it provides `AppBackground`.
- Use `ServiceIcon` for all brand logos.
- Use `AccentPill` for all urgency badges.
- Apply `urgencyColor(daysLeft:)` and `urgencySurface(daysLeft:)` for any urgency-based color.
- Keep hero numbers large (`50pt+`) and monospaced.

**Don't:**
- Add dark backgrounds, glows, or neon accents — wrong aesthetic direction for Subly.
- Hardcode colors outside `SublyTheme`.
- Create new card types — use `FlagshipCard` or `SurfaceCard`.
- Show more than one `FlagshipCard` per screen.
- Add decorative UI that doesn't carry information (badges, ribbons, etc.).

---

## Inspo Reference

Files in `~/Downloads/Subly Inso Screenshots/`:
- Dark glassmorphism with bill grouping → take the **information density and urgency hierarchy**, not the dark color scheme.
- Detail sheet (Spotify) → take the **logo-forward layout and field rows**, apply in `SublyTheme.surface` colors.
- Calendar view → future roadmap — not current scope.
