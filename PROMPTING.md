# Prompting Opus 4.7 for Subly

A cheat sheet for you, Cole. Not a rule file, not for the model to follow — just tips to reach for when you're about to hit enter on a prompt.

---

## 1. The model in one paragraph

Opus 4.7 is strong at multi-step reasoning, long context, and following explicit constraints. It has three tendencies you need to manage:

1. It will **over-engineer** unless told to stay minimal.
2. It defaults to **older Apple idioms** (`ObservableObject`, `@StateObject`, `@EnvironmentObject`, UIKit) unless you anchor it in iOS 18 / `@Observable` / SwiftData / pure SwiftUI.
3. It will proactively **create files, add defensive code, and narrate in comments** unless you scope the task tight.

Every recipe below exists to neutralize one of those three.

---

## 2. The prompt skeleton (use ~80% of the time)

```
<where>   file path or package
<what>    goal in one sentence
<must>    constraints — hard rules
<done>    success criteria — how you'll know
<ask>     any ambiguity to surface before coding
```

Example:

> In `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Subscription.swift`, add `upcomingRenewal(within days: Int) -> Bool`. No new dependencies. Done = compiles and I can call it from `SubscriptionStore.fetchAll()`. Ask if there's ambiguity about which field is the renewal date.

A prompt that hits all five boxes cuts my over-engineering reflex hard.

---

## 3. Subly defaults — paste at the top of bigger sessions

```
Stack: iOS 18 only, SwiftUI only, SwiftData @Model, Observation framework (@Observable, @Environment — never ObservableObject / @StateObject / @EnvironmentObject), Swift strict concurrency, StoreKit 2.
Modules: Subly (app), TrialParsingCore, SubscriptionStore, TrialEngine, NotificationEngine, LogoService.
Don't: add files I didn't ask for, add emojis, leave narrative comments, write defensive code around impossible states, upgrade dependencies, log PII.
```

Drop that as the first message. It eliminates 90% of the "why did it reach for ObservableObject" moments.

---

## 4. Recipes

### a. Fix a bug

Include:
- Exact Xcode error (copy-paste it, don't paraphrase)
- File + symbol where it fires
- What you already tried

I can't run Xcode. Never let me guess at a build error.

### b. Add a feature across modules

Split it. First prompt in **Plan mode**:

> Plan the change across modules — which files, what data flows, what breaks. Don't write code yet.

Then, one at a time in Agent mode:

> Implement step 1 from the plan.

Opus handles multi-step dramatically better when planning and execution are separate turns.

### c. Design a view

Ground me in references:
- A screenshot in chat beats 500 words of description
- Name the feeling ("iOS system-app calm, not Linear-dense")
- Spec the states: loading, empty, error, loaded
- Spec the edges: dark mode, Dynamic Type, safe area, rotation if it matters

### d. Review my code

Say what you care about. "Review for SwiftData concurrency bugs" gets a better review than "review this." Point at the file and the concern, not the whole module.

### e. Explain something

Pick a level. "Explain like I'm new to SwiftData" vs "point me at the two lines that matter" produce totally different outputs.

---

## 5. Anti-patterns — things to stop doing

- **Vague goals.** "Make this better" → I over-engineer. Say what "better" is.
- **Polite hedging.** "Can you maybe..." → imperatives land cleaner. Say "Do X."
- **Scope creep.** "Also clean up the rest while you're there" adds bugs 9 times out of 10. One change per turn.
- **Sandwich praise.** Be direct. I won't get offended, and hedging dilutes the actual ask.
- **Silent build status.** If the last thing I wrote didn't compile, tell me before asking for more. Paste the error.
- **Screenshots without text.** Always pair an image with "what should change."

---

## 6. Mode selection

| Mode   | Use when                                                                          |
|--------|-----------------------------------------------------------------------------------|
| Plan   | Architectural choices, multi-file refactors, anything spanning packages           |
| Agent  | Single-file changes, bug fixes, well-scoped view implementations                  |
| Ask    | "Explain", "how does X work", "is this the right pattern"                         |

Default to Plan for anything that touches more than one SPM module.

---

## 7. Copy-pasteable starters

**New view:**

> Build `<ViewName>` in `Subly/Views/`. Purpose: `<purpose>`. Owns no state (pure). Bound to: `<@Observable class>`. States: loading / empty / error / loaded. iOS 18 SwiftUI only. Put any preview fixtures in `MockupPreviews.swift`, not inline.

**SwiftData model change:**

> Edit `<Model>.swift` in `SubscriptionStore/Models`. `<goal>`. If you add or remove a `@Model`, update the `Schema([...])` in `SublyApp.swift`. If this forces a breaking migration, stop and tell me — don't guess a migration strategy.

**StoreKit work:**

> StoreKit 2 only. No legacy APIs. Verify transactions server-side? (Ask me — for now assume no.) Don't cache receipts.

**Trial / notification logic:**

> Edit `Packages/TrialEngine` or `Packages/NotificationEngine` (tell me which). Stay inside that module's public API. If you need a new type on `SubscriptionStore`, stop and propose it first.

---

## 8. Pre-send checklist

Before you hit enter, scan for four things:

1. Is there a **file path** in my prompt? (If no, I pick the wrong file.)
2. Is there a **constraint**? (If no, I over-build.)
3. Is there a **done-when**? (If no, I keep polishing.)
4. Am I asking **one thing**? (If no, split it.)

Four seconds of checklist saves a 90-second bad turn.

---

## 9. Things specific to you + me

- I can't build Xcode projects. You are the build validator. Assume I wrote something that doesn't compile until you've proven otherwise.
- I tend to reach for `ObservableObject` on autopilot. Catch me. The correct answer in this repo is almost always `@Observable`.
- I will often suggest adding a package. The default answer in Subly is no — we have five already, and they cover the surface.
- When I write a long explanation before code, skim the first sentence, skip to the code, then come back. The explanation is usually optional.
- When I ask you a clarifying question instead of coding, that's a good sign the prompt was under-specified. Note what was missing so the next prompt has it.
