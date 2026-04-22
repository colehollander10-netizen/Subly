<div align="center">

<!-- Replace with your banner image once you have one -->
<!-- <img src="assets/banner.png" alt="Subly" width="100%"> -->

# Subly

**know before your trial charges you.**

iOS app that scans your Gmail for free trials and warns you before they auto-charge. no bank link. no card link. just your inbox.

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black?style=flat&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat&logo=swift&logoColor=white)
![Status](https://img.shields.io/badge/status-active%20development-orange?style=flat)

<!-- Replace with a real screenshot or GIF once available -->
<!-- <img src="assets/demo.gif" alt="Subly demo" width="300"> -->

</div>

---

## why

every competitor (Rocket Money, Truebill, Copilot) makes you link your bank account. Subly reads your inbox instead. local-first, privacy-first, no Plaid required.

free trials are designed to be forgotten. Subly makes sure you don't.

---

## features

- scans Gmail for free trials automatically, no manual entry required
- warns you 3 days, 1 day, and the day a trial ends
- supports multiple Gmail accounts simultaneously
- detects charge amount, end date, and service name from email
- manual add for trials the parser misses (Apple, in-store signups, etc.)
- no bank login, no card link, no third-party data sharing

---

## stack

| layer | tool |
|---|---|
| UI | SwiftUI (iOS 18, `@Observable`) |
| storage | SwiftData (local-first) |
| email | Gmail REST API |
| auth | GoogleSignIn + Keychain |
| background | BGAppRefreshTask |

---

## status

actively building toward App Store v1. core Gmail scanning, multi-account support, and notifications are working. parser accuracy and onboarding are the current focus.

not yet on the App Store. follow along or star to stay updated.

---

## requirements

- iOS 18+
- a Gmail account (Google sign-in required)

---

## license

MIT
