---
title: Finn Brand Foundation
date: 2026-04-29
status: locked
supersedes_parts_of: 2026-04-24-finn-v1-design.md
vault_canonical: ~/Obsidian/Active/Finn/Finn Brand Foundation.md
---

# Finn Brand Foundation

The brand-level constraint set that sits **above** the design system. Lock these four things first; every visual and interaction decision downstream should be answerable by re-reading this document.

This doc exists because the visual system kept drifting (warm-paper → dark lavender → vulpine orange) every time a model was asked to "design" something. The drift is a symptom: there was no brand layer for the design system to anchor to. This is that layer.

> **Canonical copy lives in the Obsidian vault** at `~/Obsidian/Active/Finn/Finn Brand Foundation.md`. This repo copy is a mirror.

---

## 1. Brand Sentence

> **Finn is a subscription and free-trial tracker that takes the stress out of recurring spending — and makes the act of managing it genuinely satisfying.**

The sentence has two emotional moves: it **removes** stress, and it **adds** satisfaction. The job is stress-removal (visibility, control, no surprise charges). The flavor is satisfaction — and "satisfaction" specifically means **craft fun**, not character fun.

### What "satisfying" means here

- The haptics, the spring motion, the weight of transitions, the polish of every micro-interaction.
- The way Things 3 is "fun" to use — nothing announces fun, but every interaction is satisfying enough that you want to use it again.
- *Not* confetti, not gamification, not jokey microcopy, not stickers, not progress bars that fill with dopamine.

### What this sentence rules out

- Confetti or celebration animations on cancel.
- Gamified streaks, points, levels, or badges.
- Wisecracking microcopy from the fox or anywhere else.
- Decorative motion that doesn't serve user comprehension.

---

## 2. Interface Adjectives

> **Quiet · Tactile · Warm**

Three. Not ten. Each owns a different dimension.

| Adjective | Dimension | Forces | Forbids |
|-----------|-----------|--------|---------|
| **Quiet** | Visual | Low chroma. Generous whitespace. Single accent. No decorative gradients. | Busy backgrounds. Ornamental UI. Color-blocking. |
| **Tactile** | Behavioral | Haptics on every meaningful interaction. Springs over linear motion. Weight in transitions. Numbers count, don't swap. | Hard cuts. Missing haptics. Decorative motion. |
| **Warm** | Emotional | Friendly tone. Soft corners. Room for the fox. Microcopy with personality. | Clinical copy. Surgical sharpness. All-grey palettes. Fox-banned UX. |

### Why these three

- They cover three different dimensions (visual / behavioral / emotional) without overlap.
- "Warm" is what makes the fox legal. Without it, the fox would feel decorative in a financial utility.
- "Tactile" elevates the existing haptics + motion specs from a feature into part of the brand.
- "Quiet" is the counterweight to "satisfying." Satisfaction without quiet becomes Duolingo. Quiet without satisfaction becomes a spreadsheet.

---

## 3. Fox Rules (v1)

The fox is **Finn the fox**. The app is the product; the fox is the warmth.

### Role

- Enhancer, never protagonist.
- If a screen still works without the fox, the fox is doing its job.
- If a screen *requires* the fox to make sense, the fox is doing too much.

### Allowed surfaces

- **Onboarding** — one appearance per screen, max.
- **Empty states** — no trials, no subscriptions, or nothing ending soon.
- **Critical / urgent nudges** — "Charges in 1 day" surfaces may show a small fox in *Concerned* mood. The only place the fox appears inside an active screen.
- **App icon and About / Settings footer** — identity, not interaction.

### Banned surfaces

- HomeView's flagship card or any active trial row.
- TrialsView (the management surface — fox would distract from the list).
- Any data-dense surface (subscription detail, edit form, search results).
- Inside a button, pill, or input field.
- Loading or progress indicators.
- Tab bar.
- Anywhere money is moved or a destructive action is confirmed.

### Style

- **Vector only.** No raster, no 3D, no Pixar shading.
- **Head-and-bust silhouette** as the default. Full-body allowed only in onboarding hero moments.
- **One signature feature** (curling tail or ear notch), chosen during design week, used everywhere.
- **Readable at 32×32.** If the silhouette doesn't read at that size, simplify.
- **Single tonal palette per appearance** — accent color for fur + one neutral for outline/shadow.
- **Phosphor-compatible weight.** Clean strokes, even visual weight; the fox lives next to Phosphor icons constantly.

### Mood states (v1) — three

| State | When it appears | Visual cue |
|-------|----------------|-----------|
| **Neutral** | Default — onboarding, About, app icon | Calm, alert, slight smile |
| **Concerned** | Trial charging in ≤1 day, overdue cancel | Ears forward, brow slightly raised — *not* alarmed |
| **Sleeping** | "Nothing ending soon" empty state, "you're all set" surfaces | Curled, eyes closed |

States are swapped, not morphed. No animated transitions between states.

### Voice

The fox does not speak. No speech bubbles, no captioned dialogue from the fox. Microcopy near the fox can be warm, but the words come from the *app*, not the *fox*.

### Explicitly out of v1

- Milestone moments ("first cancel," "$X saved"). Not a v1 surface; revisit in v2/v3.
- A "Happy" mood state. Earned its keep mostly on milestones; without milestones, Sleeping or Neutral cover the rest.

---

## 4. Reference Lane

**Hard reference: Things 3.**
When Finn faces an unanswered design question — pixel rhythm, spring values, button affordance, hierarchy choices — the answer is whatever Things 3 would do. Things 3 is the decision-making proxy for everything not specified elsewhere.

**Soft reference: Sofa.**
Used sparingly for empty-state warmth and onboarding tone. Not binding. If Sofa's influence isn't earning its keep on a given screen, drop it. Sofa is *permission to be warm*; Things 3 is the *discipline that keeps Finn quiet*.

### Banned references

Do not pull visual or interaction language from:

- Copilot Money — too cold for "warm."
- Rocket Money — too aggressive.
- Cash App — wrong kind of fun.
- Duolingo — character fun, not craft fun.
- Notion — web-flat aesthetic.
- Generic Figma Community "iOS 26 glass" / "liquid glass" kits — slop magnets.

### The three departures from Things 3

These are what make Finn unique inside the Things 3 lane.

1. **The fox.** Quiet mascot in a category (financial utilities) that has none. The single most identifiable departure.
2. **Hero numbers.** Things 3 leads with task names; Finn leads with money amounts. The next-charge dollar amount is the screen's largest pixel.
3. **Time-pressure color system.** Things 3 uses one accent color neutrally; Finn has an urgency ramp (calm → warning → critical → day-of) that semantically shifts the screen's temperature as a trial approaches its charge date. Closer to Flighty than to Things 3.

### Finn in one line

> Things 3 polish, Flighty's time-pressure color logic, and a quiet fox.

That sentence is the prompt. If a model can't produce coherent output from it, the brief is wrong, not the model.

---

## How to use this doc

When making any visual or interaction decision for Finn:

1. **Re-read the brand sentence.** Does the proposed direction add satisfaction or just decoration?
2. **Check it against the three adjectives.** Does it violate Quiet, Tactile, or Warm?
3. **If a fox is involved, check the fox rules.** Allowed surface? Allowed mood? Earning its keep?
4. **If the question isn't answered by 1–3, fall back to Things 3.** What would Things 3 do here?
5. **Sofa is a tiebreaker for warmth in onboarding/empty states only.** Otherwise ignore.

If a proposed direction passes all five checks and still feels wrong, the wrongness is information — re-open this doc and figure out which constraint is missing.

---

## Implementation note (for code agents)

When delegating UI work to Cursor, Codex, or a model via Claude Code, paste **the entire "Finn in one line" sentence** into the prompt as the first sentence after the task description. Do not paste this whole document — that's how slop happens. The one-liner plus the active spec for the screen is enough.

For visual generation tasks (icon, fox, mockups), **never** ask a model to generate without first stating: brand sentence, three adjectives, the fox rule that applies, and the reference lane. If any of those four are missing from the prompt, the output will drift.
