# Active

Cap: 3 tasks. If you need to start a 4th, something here moves back to backlog or forward to done first.

---

## FINN-016: Share From Anywhere — auto-save with trial/subscription chooser
**Status:** active
**Spec:** [[FINN-016 Share From Anywhere]] in vault — read first

### Remaining (4 stacked PRs)
- [x] PR 1 — Extract OCR into shared `OCRCore` package (host app refactor, no behavior change)
- [x] PR 2 — Share extension accepts `public.image`, OCR runs in extension, two-button chooser modal
- [ ] PR 3 — App Group entitlement + SwiftData write directly from extension
- [x] PR 4 — Confirmation toast in host app on next foreground

### Notes
- FINN-005 closed — paste (#46), share-text (#50/#51), OCR-from-Photos (#52) all shipped
- This ticket closes the gap: today the user has to be in Finn to capture; FINN-016 lets them capture from anywhere on iOS without opening Finn
- Auto-save model: user taps "Free trial" or "Subscription" in the share modal — those are the only two taps
- Parser needs a subscription-extraction path (today only does trials) — Option A: extend `TrialParser` with subscription mode (lean), Option B: introduce `ReceiptParser` (cleaner, later)
- Real-device testing required — share extensions can't be fully validated in sim
- Direct SwiftData writes from the extension remain deliberately unstarted. The pending App Group handoff is working enough for the user-visible capture loop; validate on device before taking on PR 3's higher-risk shared-store work.
