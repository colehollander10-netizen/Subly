# Done

Append-only. Newest at top. Each entry: what shipped, when, and the outcome that mattered.

---

## FINN-004: P10 — Integration + adversarial review + final QA
**Status:** done
**Started:** 2026-04-29
**Completed:** 2026-04-29
**Why:** Pre-App-Store hardening after FINN-002 and FINN-003 merged.

### What shipped
- Package tests passed: TrialEngine 4, NotificationEngine 11, TrialParsingCore 10, SubscriptionStore 12.
- Simulator build/run passed on iPhone 17.
- Walked Home, Add Subscription sheet, Subscriptions, Trials, and Settings.
- Fixed two QA regressions: negative countdown labels now render `PAST DUE` instead of `-1D`; Settings now shows `1.0 (1)` instead of `— (—)`.
- Captured the remaining expected-failure issue as FINN-015 (`cancelledAt` not stamped on cancel).

---

## FINN-003: P7 — HomeView H1 rebuild (sleeping-fox empty state)
**Status:** done
**Started:** 2026-04-24
**Completed:** 2026-04-29
**Why:** Last visible phase of the subscription-pivot epic; makes the Home empty state feel intentional.

### What shipped
- Merged PR #42 (`feat/finn-003-sleeping-fox-empty-state`).
- Added the sleeping-fox Home empty state via `FoxView(.sleeping)`.
- Preserved the no-spend-hero-card decision.

---

## FINN-002: Rename Subly → Finn (mechanical)
**Status:** done
**Started:** 2026-04-24
**Completed:** 2026-04-29
**Why:** Align the product name with the locked Finn brand while preserving data-sensitive identifiers where needed.

### What shipped
- Merged PR #38 (`chore/rename-subly-to-finn-20260424`).
- Display name and app-facing copy use Finn.
- Bundle id, Xcode project filename, and folder paths intentionally remain Subly to preserve on-device SwiftData and App Store linkage.

---

## FINN-CONSOLIDATION: Migration cleanup + Linear archive
**Status:** done
**Started:** 2026-04-27
**Completed:** 2026-04-27
**Why:** Initial Linear → markdown migration carried over 18 tickets, but the vault `Finn.md` showed Linear was 3+ days stale. Cleaned `.tasks/` to reflect actual codebase + vault state, then archived Linear.

### What shipped
- `.tasks/active.md` cleared (no actually-in-progress work — COL-149 P9 is already merged per vault PR #28/#32 timeline)
- `.tasks/backlog.md` rewritten down to 13 tickets (from 19) with overlap consolidation:
  - FINN-005 absorbs COL-101 (share sheet → manual entry)
  - FINN-008 absorbs COL-106 (UI friction audit → real-device walk)
  - FINN-009 absorbs COL-131 + COL-132 + COL-139 (v2 polish remainder)
- v2 design epic (COL-120) marked DONE per `Finn.md` § Outstanding (only P7 + P10 of pivot remain)
- Linear "Finn" project archived

---

## FINN-001: Migrate live Linear tickets into this system
**Status:** done
**Started:** 2026-04-27
**Completed:** 2026-04-27
**Why:** Single source of truth. Anything still in Linear that mattered needed to land here.

### What shipped
- 68 total Linear issues reviewed. 50 already done (43 completed + 7 canceled) — left in Linear's history.
- 18 open issues ported. After consolidation pass (above), reduced to 13 active tickets in backlog.
- Original Linear IDs (COL-XXX) preserved in every Notes section for traceability with old commits/PRs.

---
