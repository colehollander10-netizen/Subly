# Finn Task System

Source of truth for what's happening on Finn. Replaces Linear. Lives in the repo so every agent (Claude, Codex, Cursor) reads it natively without an MCP call.

## Files

- `active.md` — what's being worked on right now (cap: 3 items)
- `backlog.md` — ordered. Top of list = next up.
- `done.md` — append-only log. Newest entries go at the top.
- `blocked.md` — only exists when something is waiting on external input

## Task shape

Every task uses this format so agents can parse it deterministically:

```markdown
## TASK-ID: short title
**Status:** active | done | blocked
**Started:** YYYY-MM-DD
**Why:** one line — the user-visible reason this matters

### Acceptance
- [ ] verifiable outcome 1
- [ ] verifiable outcome 2

### Notes
freeform, agent-appendable
```

`TASK-ID` format: `FINN-NNN` (zero-padded, monotonic). Check `done.md` + `backlog.md` for the highest existing number before assigning.

## Rules of the Road

How agents (you, future-you, Codex, Cursor) interact with these files.

- **Agents may** append to `Notes` freely — context, decisions, partial findings, links to commits. More signal is better than less.
- **Agents may** check `[x]` on acceptance criteria they actually verified (build passed, test ran, view rendered). If you didn't verify it, don't check it.
- **Agents may** move tasks between files when status genuinely changed: backlog → active when work starts, active → done when AC are checked, anything → blocked when stuck on external input.
- **Agents may** create new tasks in `backlog.md` when Cole describes work in passing ("we should also handle X") — capture is cheap, losing context is expensive.
- **Agents must** match the task shape above exactly. Frontmatter consistency is what makes this system parseable.
- **Agents must** state the file mutation in chat ("moved FINN-012 to done.md") so Cole can course-correct in one turn if wrong.
- **Agents must not** delete tasks. Wrong/duplicate tasks get marked `Status: dropped` and moved to `done.md` with a one-line note. Git history is the audit log.
- **Agents must not** mark a task done without running verification (build, test, visual sanity) per `superpowers:verification-before-completion`. The check on AC is the assertion that you ran the check.

Cole runs in auto-mode most of the time. Default to action, not asking. If you're unsure whether a task is really done, mark it active with a Note explaining the doubt — don't punt to Cole.

## Daily ledger

End-of-day pull: `done.md` diff + git log + Obsidian edits + Canvas submissions →
`~/Obsidian/Wiki/Knowledge/Systems/Deep Work/YYYY-MM-DD.md`

Manual deep work session entries get added to that file by Cole during the day.
