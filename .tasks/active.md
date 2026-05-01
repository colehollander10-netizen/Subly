# Active

Cap: 3 tasks. If you need to start a 4th, something here moves back to backlog or forward to done first.

---

## FINN-005: Manual trial entry — share sheet + OCR
**Status:** active
**PR:** #52 — screenshot OCR fallback (open)

### Remaining
- [ ] Review/merge OCR slice (PR #52)
- [ ] Re-walk the full manual-capture flow on simulator and real device

### Notes
- Paste-from-clipboard shipped in PR #46.
- Share extension shipped in PR #50/#51.
- OCR slice in PR #52: `TrialOCRService` (Vision wrapper) + "Scan screenshot" row on Add Trial, routed through existing `applySharedText` funnel with `source: .screenshot`.
- After #52 merges and walkthrough passes: close FINN-005, move FINN-006 (launch pricing) to active.
