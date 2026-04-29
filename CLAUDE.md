# Finn — agent briefing

Slim pointers. Full project context lives in Cole's Obsidian vault (`Projects/Finn/Finn.md`) and in Linear. **App is renamed Subly → Finn as of 2026-04-24** — display name is "Finn" but bundle id, Xcode project filename, and folder paths (`Subly/`, `Subly.xcodeproj`) stay "Subly" to preserve on-device SwiftData + App Store Connect linkage.

## Right now

- **Brand foundation:** [[Finn Brand Foundation]] (`docs/superpowers/specs/2026-04-29-finn-brand-foundation-design.md`) — sentence, three adjectives, fox rules, reference lane. **Read this before any visual or voice decision.** When this conflicts with DESIGN.md or the v1 Launch Design, Brand Foundation wins.
- **Active spec:** [[Finn v1 Launch Design]] (`docs/superpowers/specs/2026-04-24-finn-v1-design.md`) — full v1 launch spec.
- **Active plan:** [[Finn v1 Implementation Plan]] (`docs/superpowers/plans/2026-04-24-finn-v1-implementation.md`) — 16 sub-plans, sub-plan 01 (rename) fully written.
- **Prior epic done:** COL-140 subscription pivot (P1–P9 merged; P10 audit fixes are sub-plan 02). COL-120 v2 design complete.
- **Paired vault docs:** [[Finn]] (canonical state) + [[Finn v1 Launch Design]] + [[Finn v1 Implementation Plan]] + [[Finn Content Strategy]].

## Hard rules

- **Phosphor icons only** in app-owned UI. Zero `Image(systemName:)`. Use `Ph.<name>.<weight>.color(...)` — not `.foregroundStyle()`, not `.resizable()`. Exception: SwiftUI `.tabItem` slot — SF Symbols only (SwiftUI doesn't honor custom views there).
- **`FinnTheme.*` tokens only** — no hardcoded colors, no `.regular` font weight. Vulpine palette locked (ratified by [[Finn Brand Foundation]] 2026-04-29).
- **Fox surfaces are gated.** Fox may appear only on: onboarding, empty states, "Charges in 1 day" surfaces, app icon, About/Settings footer. Banned: HomeView flagship card, active trial rows, TrialsView, data-dense surfaces, buttons/pills/inputs, loading indicators, tab bar, money-moving contexts. Three moods only: Neutral / Concerned / Sleeping. See [[Finn Brand Foundation]] §3.
- **`PrimaryButton` contrast:** Vulpine orange fill + `FinnTheme.background` (warm charcoal) label. Never white. Reason: WCAG.
- **No `VersionedSchema` migration plan exists** and it's deliberate — a prior session backed out. Don't rebuild it. Lightweight `@Attribute(originalName:)` migrations only.
- **PR per ticket.** Never push directly to `main`. Never merge to `main` locally.
- **Run `route` skill** before writing non-trivial code. Default pattern: Claude plans, Codex executes, Cursor scaffolds UI, Opus reviews.
- **Docs to vault first.** All specs/plans/design docs go to `/Users/colehollander/Obsidian/Projects/Finn/` as the canonical copy; repo copies (`docs/superpowers/`) are secondary.

## Build

```bash
xcodegen  # after adding files
xcodebuild -project Subly.xcodeproj -scheme Subly \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

cd Packages/<Pkg> && swift test
```

## First moves in a new session

1. `gh pr list --state open`
2. `git log --oneline -10`
3. Read [[Finn]] in the vault for current state — and verify against code (Linear "Done" has been wrong before).
