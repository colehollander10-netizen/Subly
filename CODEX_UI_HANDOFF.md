# Subly UI Redesign — Codex Handoff

## What Subly is

Subly is an iOS app that tracks **paid free trials** — the kind where you handed over a credit card and will get auto-charged if you don't cancel. Not a subscription tracker. Not a Mint/Copilot Money clone. An alarm clock for the moment before you get charged.

**The moat:** Privacy-first. No bank login, no Plaid. We read your Gmail (read-only, Google OAuth) and parse trial-start emails ourselves. Everything runs on-device. Competing apps either want your bank credentials (Rocket Money, Truebill) or charge you $40/yr to scan your inbox server-side (Subby, Bobby). Subly does it locally and stays free.

**Who's using it:** just me for now. Shipping to App Store is the #1 priority for this quarter.

**Stack:** SwiftUI + SwiftData, iOS 26+, Gmail API via `GoogleSignIn-iOS`, local UserNotifications for the "3 days before" / "day of" alerts. Xcode project at `/Users/colehollander/Developer/Subly`. Simulator target: iPhone 17, UUID `933CB505-7001-47E5-B4D5-D40896FB042D`.

---

## What you are doing

Redesigning the UI. The underlying product — Gmail OAuth, the 4-gate parser, scan coordinator, trial-alert scheduler, SwiftData models — is **finished and must not be touched**. You are touching views and the design system only.

The last attempt at this redesign (by Claude Code, earlier today) was rejected for looking like default AI-generated "premium" UI. Read the **"What not to produce"** section carefully before you pick a direction.

---

## Current state of the UI (what you're replacing)

Today the app runs a "liquid glass" aesthetic:

- Dark gradient background (`LiquidGlassBackground`) with blurred colored orbs
- Glass cards (`GlassCard`) with ultra-thin material blur + white borders
- Purple + blue gradient CTAs (`sublyBlue` #3AA3FF, `sublyPurple` #B47CFF)
- `UrgencyCard` with colored stripe on the leading edge (red/amber/green by days-remaining)
- 3 tabs: Home (hero + stats + scan button), Trials (list + FAB to add manual), Settings (connected Gmail accounts)
- White text on dark glass throughout
- SF Pro only; SF symbol icons; Clearbit logos via a `ServiceIcon` helper

**Keep these product behaviors regardless of visual direction:**

1. **Hero on Home is the next-ending trial itself**, not a stats number. Show the service, the date it ends, the amount you'll be charged, and the days remaining.
2. **Swipe-left on the hero → opens a cancel-flow sheet** that explains, service by service, how to actually cancel that specific subscription. Not "click here to unsubscribe." Real steps: "Open audible.com → Account Details → Membership → Cancel." With a direct link to the cancel URL. Include a curated list of the top ~50 services (Netflix, Spotify, Adobe, Audible, Apple, YouTube, Disney+, Hulu, HBO Max, Amazon Prime, iCloud, Google One, Microsoft 365, Dropbox, LinkedIn Premium, ChatGPT, Claude, Cursor, Notion, Figma, Canva, Grammarly, 1Password, Headspace, Calm, Duolingo, Peloton, Strava, Kindle Unlimited, NYT, WSJ, GitHub Copilot, Substack, Readwise, Scribd, MasterClass, Blinkist, Bumble, Hinge, Discord Nitro, Every, etc.). Fallback to domain heuristic (`{senderDomain}/account` → Subscriptions) then to a "Search '{service} cancel subscription'" button.
3. **Home also shows the next 3 trials below the hero**, compactly. Full list lives in the Trials tab.
4. **Tabs: 2 not 3.** Home + Trials. Settings moves to a gear icon in the top-right of Home that presents a sheet.
5. **Suggested trials ("leads")** — `@Query` filter `isLead == true`. These live in a separate "Suggested" section on Trials with inline Confirm/Dismiss buttons per row. Leads are parser hits the 4-gate isn't 100% sure about.
6. **Manual add** — top-right `+` on Trials opens an empty detail sheet for manual entry. Reuses the same sheet as editing.
7. **Clearbit logos are required.** The `ServiceIcon` helper fetches `https://logo.clearbit.com/{domain}?size=128`. For hero, 40–48pt. For list rows, 24–28pt. Keep them.
8. **Lowercase `subly` wordmark** as a placeholder logo. No official logo exists yet — don't invent one.

---

## What NOT to produce

I am giving you this list because the last attempt landed on every item here:

1. **Do not use warm cream / off-white paper backgrounds** (`#F5F1E8`, `oldlace`, `#FAF7F0`, etc.). Looks like a Substack newsletter. Instantly reads as "AI designer picked editorial."
2. **Do not use New York serif for display type.** Apple's built-in serif paired with SF Pro body is the Claude Code / ChatGPT default "premium" pairing. It's a tell.
3. **Do not use a single warm accent color** (ember red, burnt orange, rust). Pair with cream + serif and the whole screen screams "AI vomited an editorial direction."
4. **Do not use purple-to-blue gradients** on CTAs. That's what the current app does and it's what Cole is trying to get away from. No filled gradient rectangles anywhere.
5. **Do not use iOS system blue as the accent.** Generic.
6. **Do not use decorative glass/blur panels.** Glass is the current direction; the redesign is moving away from it. Blur is OK only at the system level (sheet presentation, tab bar).
7. **Do not produce a symmetrical 2-column card grid** unless the content genuinely demands it. The hero should dominate.
8. **Do not use emoji as icons.** SF Symbols or custom SVG-style shapes only.
9. **Do not add "Good morning, Cole" greetings**, motivational copy, or sparkle icons. This isn't a wellness app.
10. **Do not invent tokens like `--brand-primary-500`.** Small, opinionated token set only.
11. **Do not add a splash/onboarding animation** with a logo reveal. Not the moment we're designing for.

---

## Three directions to pick from

**You must commit to exactly one.** Don't hedge. Don't mix two. Read all three, then decide and execute.

### Direction A — Swiss terminal (Linear / Vercel / Raycast lineage)

- Stark near-black background (`#0A0A0B` or `#0C0D10`, not pure black — slight cool tint)
- White + 2 gray steps (`#E6E6E9`, `#9B9BA0`, `#5A5A60`) for text hierarchy
- **One** electric accent — pick one: Linear-indigo `#5E6AD2`, Vercel-cyan `#00DC82`, or sharp yellow `#FFDD33`
- Typography: **Inter** or **SF Pro** throughout. Tabular figures for all numbers. Zero serif.
- Hero: big number + service name, tight grid, fine hairline dividers at ~8% white
- No cards with borders — use spacing and dividers to group
- Motion: spring, fast, understated (150–200ms)
- Swipe actions reveal a single flat red button, no rounded pill

This looks like a tool, not a magazine. The hero trial reads as a precise, cold countdown.

### Direction B — Bloomberg terminal × mobile

- Black background (`#000`) — this one IS pure black, for OLED
- Dense data layout. Everything is information, nothing is decoration.
- Single monospace font for everything: **JetBrains Mono**, **IBM Plex Mono**, or **SF Mono**
- Numbers are the heroes. Dollar amounts huge and tabular.
- Color: amber/yellow (`#FFB800`) for amounts at risk, cyan (`#00D4FF`) for dates, white for service names, dim gray for metadata
- No logos hero-sized — Clearbit logos stay small (20pt) to keep the typographic grid intact
- Hero is an ASCII-style divider + a dense stat block, not a glossy card
- Swipe-left reveals terminal-style action text ("CANCEL ⏎"), not a button

This looks like nothing else on the App Store. Not for everyone — it's for Cole.

### Direction C — Minimal white (Copilot Money lineage, executed correctly)

- Pure white background (`#FFFFFF`), not cream
- Near-black ink (`#111114`), one mid-gray (`#6B6B70`), one hairline (`#E5E5E8`)
- **One** bold saturated accent — pick one: spectrum-green `#00B87C` (Copilot-like), poppy-red `#E8344E`, or graphite `#1A1A1C` (accent-free, weight and size only)
- Typography: **SF Pro Display** at display sizes, **SF Pro Text** at body. Tight letter-spacing on display. Tabular figures.
- Clearbit logos at **full color** — they provide all the color the screen needs
- Hero: generous whitespace, large logo (56pt), service name in SF Pro Display Black, amount below in monospace
- Cards have no shadows. Hairline dividers only.
- Motion: Apple-like spring, 250–350ms, subtle

This one is close to the current mainstream "premium iOS" look — the risk is landing back in vibe-coded territory. It works only if executed with restraint: **no gradients, no icons where text would do, no decorative everything.**

---

## My recommendation

**Direction A (Swiss terminal) if you want the highest ceiling for "this doesn't look AI-generated."** Linear and Raycast have trained eyes to read this aesthetic as "made by a real team with taste." Subly already has engineering-heavy DNA — a trial alarm that reads your Gmail with a 4-gate parser — and Swiss terminal leans into that rather than hiding it behind polish.

Pick A unless you have a strong reason for B or C.

---

## Files to modify

| File | Change |
|------|--------|
| `Subly/GlassComponents.swift` | Replace tokens + primitives for your chosen direction. Rename is optional. Delete `LiquidGlassBackground`, `GlassCard`, `UrgencyCard`, `GlassButton`, `CountdownBadge`, `sublyBlue`, `sublyPurple`, `sublyAmber`, `sublyRed`. Keep `ServiceIcon` — it works. |
| `Subly/HomeView.swift` | Full rewrite. Hero = next-ending trial. Then 3 more rows. Gear toolbar. Scan trigger at the bottom as a quiet link, not a gradient CTA. |
| `Subly/TrialsView.swift` | Full rewrite. Sections: "Ending soon" (≤7d), "Later" (>7d), "Suggested" (`isLead == true`). Top-right `+` opens an empty detail sheet. |
| `Subly/SettingsView.swift` | Presented as a sheet from Home now. Keep connected-accounts logic (SwiftData `ConnectedAccount` query, `EmailEngine.shared.signInAndAdd`). Apply new palette. |
| `Subly/OnboardingView.swift` | Palette pass. Keep the two-step flow (connect work/school, then personal with skip). |
| `Subly/ContentView.swift` | 2 tabs (Home + Trials). Remove Settings tab. Pass a `@State selection` and an `onSeeAllTrials` callback to HomeView so "See all" jumps tabs. |
| **New** `Subly/Sheets.swift` | Single file containing `CancelGuide` struct + `CancelGuideResolver` (50+ services, 4-tier fallback), `CancelFlowSheet` view, `TrialDetailSheet` view (form for editing `Trial` fields: `serviceName`, `trialEndDate`, `chargeAmount`, `billingPeriod`, `cancelURL` — all `@Bindable`). Consolidating these keeps file count low. |
| `Subly.xcodeproj/project.pbxproj` | Register the new `Sheets.swift`: add `PBXBuildFile`, `PBXFileReference`, append to the `Subly` `PBXGroup` children, append to the `Subly` target's `PBXSourcesBuildPhase` files. Use fresh 24-hex-char IDs. |

### Files you must NOT touch

- `Packages/EmailEngine/` — the Gmail + parser package. Leave alone.
- `Packages/SubscriptionStore/` — SwiftData models. Leave alone.
- `Packages/NotificationEngine/` — alert scheduler. Leave alone.
- `Subly/ScanCoordinator.swift`, `Subly/TrialAlertCoordinator.swift` — logic. Leave alone.
- `Subly/SublyApp.swift` — entry point + seed data. Leave alone.

---

## Build + verify

```bash
cd /Users/colehollander/Developer/Subly

# Build
xcodebuild -project Subly.xcodeproj -scheme Subly \
  -destination 'platform=iOS Simulator,id=933CB505-7001-47E5-B4D5-D40896FB042D' \
  -configuration Debug build

# Install + launch
xcrun simctl install 933CB505-7001-47E5-B4D5-D40896FB042D \
  ~/Library/Developer/Xcode/DerivedData/Subly-*/Build/Products/Debug-iphonesimulator/Subly.app
xcrun simctl launch 933CB505-7001-47E5-B4D5-D40896FB042D com.subly.Subly
```

Seed data is in `SublyApp.swift` — fresh installs get ~6 trials: Audible (ends today), Adobe Creative (3d), Spotify (7d), Cursor Pro (14d), Netflix (30d), plus an "Every" lead. So you can verify hero urgency, the swipe-to-cancel flow, the 3-tier cancel-guide resolution, and the Suggested section all without scanning Gmail.

---

## Verification checklist

Before declaring done, confirm on the iPhone 17 simulator:

1. App launches without a crash. Seed data visible.
2. Home: wordmark top-left, gear top-right. Hero = Audible (today), showing service name, end date, charge amount, days remaining. Next 3 trials visible below. Scan trigger at the bottom is a **quiet link**, not a big button.
3. Swipe-left on hero → cancel-flow sheet opens with **"How to cancel Audible"** title, 3–4 numbered service-specific steps, `Open audible.com/…` button, and 3 action rows at the bottom: `I cancelled it` / `Remind me in 1 hour` / `I'll do it later`.
4. Tap `I cancelled it` → trial marked cancelled (`userDismissed = true`), slides off the stack, Adobe becomes the new hero.
5. Trials tab: 3 sections visible (Ending soon, Later, Suggested). Bucketing matches days-remaining thresholds. Suggested section has inline Confirm/Dismiss per row.
6. Tap `+` top-right of Trials → empty detail sheet opens, Save inserts a new `Trial`.
7. Tap any trial row → populated detail sheet, Save persists edits.
8. Gear icon on Home → Settings sheet presents (not a tab). Connected Gmail accounts list renders. "Add another email" triggers `EmailEngine.shared.signInAndAdd`.
9. Tab bar has **exactly 2 tabs**: Home, Trials.
10. Zero sightings of: purple/blue gradients, cream backgrounds, New York serif, ember/rust warm accents, glass blur on content surfaces, emoji icons, "Good morning" greetings.
11. Take a screenshot at the end and inspect: does the screen look like it could be a real product, not an AI design demo? If you can imagine someone on Twitter saying "this looks vibe-coded," start over.

---

## Non-negotiables

- No breaking changes to `Trial`, `ConnectedAccount`, or `EmailScanState` SwiftData schemas
- No new third-party dependencies
- No changes to Gmail OAuth scopes or parser logic
- Build must succeed on first try after your last edit — no "left it broken, come back later"
- If you pick Direction A or C and the file count gets out of hand, consolidate into fewer files rather than scattering `TrialRow.swift`, `TrialHeroCard.swift`, etc. as separate modules. Fewer, bigger files are fine.

---

## If you get stuck

Read the prior attempt's plan at `/Users/colehollander/.claude/plans/floating-tickling-horizon.md` for the product-behavior details (cancel flow copy, swipe gestures, sheet structure). Ignore its aesthetic direction — that's the one that got rejected — but reuse its interaction design and information architecture verbatim.

Good luck. Pick a direction and commit.
