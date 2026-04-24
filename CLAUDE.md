# Subly — agent briefing

Slim pointers. Full project context lives in Cole's Obsidian vault (`Wiki/Projects/Subly.md`) and in Linear.

## Right now

- **Active epic:** `COL-140` subscription pivot. P1–P4 merged. Recommended next: **P9 (COL-149)** — 4-tab bar + SubscriptionsView. That's what makes the already-shipped `AddSubscriptionSheet` reachable.
- **Source of truth:** `docs/superpowers/specs/2026-04-23-subscription-pivot-design.md` (spec) + `docs/superpowers/plans/2026-04-23-subscription-pivot-implementation.md` (10-phase plan with per-task files + AC). Read both before touching pivot tickets.
- **Prior epic done:** COL-120 v2 design. See `DESIGN.md` for tokens + component library.

## Hard rules

- **Phosphor icons only** in app-owned UI. Zero `Image(systemName:)`. Use `Ph.<name>.<weight>.color(...)` — not `.foregroundStyle()`, not `.resizable()`.
- **`SublyTheme.*` tokens only** — no hardcoded colors, no `.regular` font weight.
- **`PrimaryButton` contrast:** lavender fill + `SublyTheme.background` (dark charcoal) label. Never white. Reason: WCAG.
- **No `VersionedSchema` migration plan exists** and it's deliberate — a prior session backed out. Don't rebuild it.
- **PR per ticket.** Never push directly to `main`. Never merge to `main` locally.
- **Run `route` skill** before writing non-trivial code. Default pattern: Claude plans, Codex executes, Cursor scaffolds UI, Opus reviews.

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
3. Check Linear `COL-140` sub-issues for current phase statuses — but verify against code (Linear "Done" has been wrong before).
