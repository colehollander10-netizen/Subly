<div align="center">

<!-- Replace with your banner image once you have one -->
<!-- <img src="assets/banner.png" alt="Subly" width="100%"> -->

# Subly

**know before your trial charges you — without linking your bank or your inbox.**

iOS app that tracks paid free trials and warns you before they auto-charge. no bank link, no inbox access, no account.

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-black?style=flat&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat&logo=swift&logoColor=white)
![Status](https://img.shields.io/badge/status-active%20development-orange?style=flat)

<!-- Replace with a real screenshot or GIF once available -->
<!-- <img src="assets/demo.gif" alt="Subly demo" width="300"> -->

</div>

---

## why

every competitor makes you link something. Rocket Money and Truebill want your bank. Subby and Bobby want your inbox. Subly wants neither.

you capture trials yourself and everything lives on-device. no account, no cloud, no server. free trials are designed to be forgotten; Subly makes sure you don't.

---

## features

- add a trial with a manual form — merchant name, end date, charge amount
- paste email or receipt text from the clipboard and it regex-extracts service, date, and amount to prefill the form
- stored on-device with SwiftData
- local notifications 3 days before and the day a trial ends
- no bank login, no inbox access, no account, no server backend

roadmap: more capture methods (share sheet, screenshot ocr) and on-device parsing are on the way for v1.

---

## stack

| layer | tool |
|---|---|
| UI | SwiftUI (iOS 18, `@Observable`) |
| storage | SwiftData (local-first) |
| capture | manual form, paste-to-prefill |
| notifications | UserNotifications (local only) |

---

## status

actively building toward App Store v1. manual entry, on-device storage, and local notifications are working. additional capture methods (share sheet, paste, screenshot ocr) and on-device parsing are next.

not yet on the App Store. follow along or star to stay updated.

---

## requirements

- iOS 18+

---

## development environment

### linux cloud agents (Cursor)

- install Swift 6.0 via `swiftly` plus runtime deps (`libncurses6`, `libncursesw6`) to work on Swift package code
- validate setup with `swift --version` after environment bootstrap
- iOS app build/run is **not supported** on Linux cloud agents because `xcodebuild`, `xcrun`, Simulator, and Apple iOS SDKs are macOS-only

### macOS local development

- required for full app build/run and simulator testing
- use Xcode (with iOS SDK + Simulator) to build and launch `Subly`

---

## license

MIT
