# Finn — agent briefing

Slim pointers. Full project context lives in Cole's Obsidian vault (`04 Projects/Finn/Finn.md`) and repo-local `.tasks/`. Linear is archived. **App is renamed Subly → Finn** — display name, project, scheme, and app folder are now "Finn"; protected bundle/App Group identifiers still use `com.colehollander.subly` / `group.com.colehollander.subly` to preserve on-device SwiftData and App Store linkage.

## Right now

- **Brand foundation:** [[Finn Brand Foundation]] (`docs/superpowers/specs/2026-04-29-finn-brand-foundation-design.md`) — sentence, three adjectives, fox rules, reference lane. **Read this before any visual or voice decision.** When this conflicts with DESIGN.md or the v1 Launch Design, Brand Foundation wins.
- **Active spec:** [[Finn v1 Launch Design]] (`docs/superpowers/specs/2026-04-24-finn-v1-design.md`) — full v1 launch spec.
- **Active plan:** [[Finn v1 Implementation Plan]] (`docs/superpowers/plans/2026-04-24-finn-v1-implementation.md`) — 16 sub-plans, sub-plan 01 (rename) fully written.
- **Prior epic done:** COL-140 subscription pivot (P1–P9 merged; P10 audit fixes are sub-plan 02). COL-120 v2 design complete.
- **Paired vault docs:** [[Finn]] (canonical state) + [[Finn v1 Launch Design]] + [[Finn v1 Implementation Plan]] + [[Finn Content Strategy]].

## Custom agents

- When Cole explicitly asks for subagents, delegation, or parallel agent work,
  use `finn-impl` for substantial SwiftUI/SwiftData/StoreKit implementation,
  bug fixes, and scoped refactors in this repo.
- Use `finn-spec` for fuzzy Finn product ideas, UX/spec work, and implementation
  plans before code.
- The main Codex session should coordinate and review agent output while
  preserving all Finn hard rules below.

## Hard rules

- **Phosphor icons only** in app-owned UI. Zero `Image(systemName:)`. Use `Ph.<name>.<weight>.color(...)` — not `.foregroundStyle()`, not `.resizable()`. Exception: SwiftUI `.tabItem` slot — SF Symbols only (SwiftUI doesn't honor custom views there).
- **`FinnTheme.*` tokens only** — no hardcoded colors, no `.regular` font weight. Vulpine palette locked (ratified by [[Finn Brand Foundation]] 2026-04-29).
- **Fox surfaces are gated.** Fox may appear only on: onboarding, empty states, "Charges in 1 day" surfaces, app icon, About/Settings footer. Banned: HomeView flagship card, active trial rows, TrialsView, data-dense surfaces, buttons/pills/inputs, loading indicators, tab bar, money-moving contexts. Three moods only: Neutral / Concerned / Sleeping. See [[Finn Brand Foundation]] §3.
- **`PrimaryButton` contrast:** Vulpine orange fill + `FinnTheme.background` (warm charcoal) label. Never white. Reason: WCAG.
- **No `VersionedSchema` migration plan exists** and it's deliberate — a prior session backed out. Don't rebuild it. Lightweight `@Attribute(originalName:)` migrations only.
- **PR per ticket.** Never push directly to `main`. Never merge to `main` locally.
- **Run `route` skill** before writing non-trivial code. Default pattern: Codex plans, Codex executes, Cursor scaffolds UI, Opus reviews.
- **Docs to vault first.** All specs/plans/design docs go to `/Users/colehollander/Obsidian/Projects/Finn/` as the canonical copy; repo copies (`docs/superpowers/`) are secondary.

## Build

```bash
xcodegen  # after adding files
xcodebuild -project Finn.xcodeproj -scheme Finn \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

cd Packages/<Pkg> && swift test
```

## First moves in a new session

1. `gh pr list --state open`
2. `git log --oneline -10`
3. Read [[Finn]] in the vault for current state — and verify against code (Linear "Done" has been wrong before).

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **Subly** (526 symbols, 506 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/Subly/context` | Codebase overview, check index freshness |
| `gitnexus://repo/Subly/clusters` | All functional areas |
| `gitnexus://repo/Subly/processes` | All execution flows |
| `gitnexus://repo/Subly/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
