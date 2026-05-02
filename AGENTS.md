# AGENTS.md

## Cursor Cloud specific instructions

### Environment

- **Swift toolchain**: Swift 6.0.3 installed at `/usr/share/swift/usr/bin/swift`. PATH is set in `~/.bashrc`.
- **Platform**: Ubuntu 24.04 (x86_64). No Xcode, no iOS SDK, no Simulator.

### What you can build and test on Linux

| Package | `swift build` | `swift test` | Notes |
|---|---|---|---|
| `OCRCore` | ✅ | ✅ (1 test) | Pure Foundation — works fully |
| `TrialEngine` | ✅ | ✅ (6 tests) | Pure Foundation — works fully |
| `LogoService` | ✅ | N/A | Builds but has no test target |
| `TrialParsingCore` | ❌ | ❌ | Uses `NSDataDetector` (Apple-only) |
| `NotificationEngine` | ❌ | ❌ | Uses `UserNotifications` (Apple-only) |
| `SubscriptionStore` | ❌ | ❌ | Uses `SwiftData` (Apple-only) |
| `MascotKit` | ❌ | ❌ | Uses `SwiftUI` (Apple-only) |

Run tests with: `cd Packages/<Pkg> && swift test`

### What you cannot do

- **Full iOS app build** (`xcodebuild`) — requires macOS + Xcode + iOS SDK.
- **`xcodegen`** — macOS-only tool; use the checked-in `.xcodeproj` as-is.
- **Simulator testing** — not available on Linux.

### Lint / code checks

No SwiftLint or SwiftFormat is configured in this repo. Code review is manual. The `swift build` output in each package directory serves as the compiler-level check.
