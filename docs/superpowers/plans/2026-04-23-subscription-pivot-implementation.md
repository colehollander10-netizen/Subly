# Subly Subscription Pivot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Subly from trial-only to trial + subscription tracking, with a unified model, 4-tab UI, cancel-assist flow for trials, fox mascot for emotional moments, and StoreKit bulk import.

**Architecture:** Unified `Trial` SwiftData model (class name kept for v1; `entryType` field disambiguates) extended with `entryType`, `status`, `billingCycle`, `notificationOffset`, `cancelledAt`, and `trialEndDate → chargeDate` rename. Migration via `VersionedSchema` to preserve existing trial data. UI grows from 3 tabs to 4 (Home / Trials / Subscriptions / Settings) with Phosphor icons. Fox system is native SwiftUI, `Subly/Fox/` folder.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData (VersionedSchema migration), StoreKit 2, PhosphorSwift (SPM), XCTest, xcodegen.

**Spec:** `docs/superpowers/specs/2026-04-23-subscription-pivot-design.md`

**Branch strategy:** One branch per Phase (Phase 1 = `colehollander10/sub-pivot-p1-model`, etc.). Open PRs as each phase completes, merge into main before starting the next phase. This keeps blast radius small and lets Cursor delegations pick up a clean main.

**Skill discipline:**
- Every phase starts with a route-skill decision re-check (task shape may have shifted during implementation).
- Every Swift file changed in a phase triggers `superpowers:verification-before-completion` before the phase's commit — `xcodebuild` must be green.
- Phases touching user input, authentication, or external APIs (Phase 8 StoreKit) invoke `security-review` before merge.
- Every phase ends with `code-review` (local mode) before push.

---

## File Structure

### New files

```
Subly/Fox/
├── FoxState.swift                      // enum: sleeping/happy/veryHappy/proud/curious/alert
├── FoxView.swift                       // state-driven native SwiftUI view
└── FoxAnimation.swift                  // helpers: pulse, blink, ear-wiggle

Subly/Resources/
└── CancelGuides.json                   // curated cancel instructions, 15 services

Subly/AddEntry/
├── AddSubscriptionSheet.swift          // new sheet
└── Components/
    ├── ServiceNameField.swift          // extracted from Sheets.swift
    ├── AmountField.swift               // extracted from Sheets.swift
    └── DatePickerField.swift           // extracted from Sheets.swift

Subly/CancelAssist/
├── CancelAssistSheet.swift             // full-screen sheet
├── CancelGuide.swift                   // codable model for JSON entries
└── CancelGuideStore.swift              // loads + queries CancelGuides.json

Subly/Import/
├── StoreKitImport.swift                // Transaction.currentEntitlements → ImportableSubscription
├── ImportConfirmationSheet.swift       // checkbox list UI
└── ImportableSubscription.swift        // value type

Subly/
├── SubscriptionsView.swift             // new tab
└── SpendCard.swift                     // "THIS MONTH" hero card

Packages/SubscriptionStore/Sources/SubscriptionStore/Models/
├── EntryType.swift                     // enum
├── EntryStatus.swift                   // enum
├── BillingCycle.swift                  // enum
├── SchemaV1.swift                      // pre-pivot schema (current state)
├── SchemaV2.swift                      // post-pivot schema
└── SublyMigrationPlan.swift            // VersionedSchema migration plan
```

### Modified files

```
Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Trial.swift
  // Rename trialEndDate → chargeDate; add entryType, status, billingCycle,
  // notificationOffset, cancelledAt

Packages/TrialEngine/Sources/TrialEngine/TrialEngine.swift
  // Rename `trialEndDate` param → `chargeDate`; add Kind.subscriptionDayBefore;
  // add `planSubscription(...)` static method

Packages/NotificationEngine/Sources/NotificationEngine/NotificationEngine.swift
  // Add removePending(ids:) for targeted cancellation

Subly/SublyApp.swift
  // Use SchemaV2 + SublyMigrationPlan instead of raw Schema

Subly/ContentView.swift
  // 3 tabs → 4 tabs; Phosphor icons; add SubscriptionsView

Subly/HomeView.swift
  // H1 layout: trials-forward, spend card, Caught $X, sleeping-fox empty state

Subly/TrialsView.swift
  // Add Cancel button on detail; hook into CancelAssistSheet

Subly/Sheets.swift
  // Extract shared field components; split Add Trial sheet out to its own file
  // (Subly/AddEntry/AddTrialSheet.swift) for parity with AddSubscriptionSheet

Subly/SettingsView.swift
  // Add "Import subscriptions" row; add curious-fox in header
```

---

## Phase 1 — Model Migration (Opus inline)

**Route:** Opus inline. SwiftData `VersionedSchema` is subtle; needs mid-task reasoning.
**Branch:** `colehollander10/sub-pivot-p1-model`
**Outcome:** Existing trial data migrates cleanly to new unified schema; model tests pass.

### Task 1.1: Add new enum files

**Files:**
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/EntryType.swift`
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/EntryStatus.swift`
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/BillingCycle.swift`
- Test: `Packages/SubscriptionStore/Tests/SubscriptionStoreTests/EnumTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// EnumTests.swift
import XCTest
@testable import SubscriptionStore

final class EnumTests: XCTestCase {
    func testEntryTypeRawValues() {
        XCTAssertEqual(EntryType.freeTrial.rawValue, "freeTrial")
        XCTAssertEqual(EntryType.subscription.rawValue, "subscription")
    }
    func testEntryStatusRawValues() {
        XCTAssertEqual(EntryStatus.active.rawValue, "active")
        XCTAssertEqual(EntryStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(EntryStatus.expired.rawValue, "expired")
    }
    func testBillingCycleRawValues() {
        XCTAssertEqual(BillingCycle.monthly.rawValue, "monthly")
        XCTAssertEqual(BillingCycle.yearly.rawValue, "yearly")
        XCTAssertEqual(BillingCycle.weekly.rawValue, "weekly")
        XCTAssertEqual(BillingCycle.custom.rawValue, "custom")
    }
    func testBillingCycleMonthlyMultiplier() {
        XCTAssertEqual(BillingCycle.monthly.monthlyMultiplier, 1.0, accuracy: 0.0001)
        XCTAssertEqual(BillingCycle.yearly.monthlyMultiplier, 1.0/12.0, accuracy: 0.0001)
        XCTAssertEqual(BillingCycle.weekly.monthlyMultiplier, 4.33, accuracy: 0.001)
        XCTAssertEqual(BillingCycle.custom.monthlyMultiplier, 1.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test --filter EnumTests
```
Expected: FAIL with "Cannot find 'EntryType' in scope"

- [ ] **Step 3: Create `EntryType.swift`**

```swift
// EntryType.swift
import Foundation

public enum EntryType: String, Codable, Sendable, CaseIterable {
    case freeTrial
    case subscription
}
```

- [ ] **Step 4: Create `EntryStatus.swift`**

```swift
// EntryStatus.swift
import Foundation

public enum EntryStatus: String, Codable, Sendable, CaseIterable {
    case active
    case cancelled
    case expired
}
```

- [ ] **Step 5: Create `BillingCycle.swift`**

```swift
// BillingCycle.swift
import Foundation

public enum BillingCycle: String, Codable, Sendable, CaseIterable {
    case monthly
    case yearly
    case weekly
    case custom

    /// Multiplier to normalize chargeAmount into a monthly-equivalent spend.
    /// `.custom` defaults to 1.0 (treat-as-monthly) for v1; refined in v1.1.
    public var monthlyMultiplier: Double {
        switch self {
        case .monthly: return 1.0
        case .yearly: return 1.0 / 12.0
        case .weekly: return 4.33
        case .custom: return 1.0
        }
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test --filter EnumTests
```
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd ~/Developer/Subly && git checkout -b colehollander10/sub-pivot-p1-model
git add Packages/SubscriptionStore/Sources/SubscriptionStore/Models/EntryType.swift \
        Packages/SubscriptionStore/Sources/SubscriptionStore/Models/EntryStatus.swift \
        Packages/SubscriptionStore/Sources/SubscriptionStore/Models/BillingCycle.swift \
        Packages/SubscriptionStore/Tests/SubscriptionStoreTests/EnumTests.swift
git commit -m "feat(model): add EntryType, EntryStatus, BillingCycle enums"
```

### Task 1.2: Create SchemaV1 snapshot (current schema)

**Files:**
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SchemaV1.swift`

- [ ] **Step 1: Create SchemaV1.swift capturing the current `Trial` model**

```swift
// SchemaV1.swift
import Foundation
import SwiftData

/// Snapshot of the pre-pivot schema. DO NOT MODIFY this file after the
/// pivot ships — migrations depend on these types staying stable.
public enum SublySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [TrialV1.self, TrialAlertV1.self] }

    @Model
    public final class TrialV1 {
        @Attribute(.unique) public var id: UUID
        public var serviceName: String
        public var senderDomain: String
        public var trialEndDate: Date
        public var chargeAmount: Decimal?
        public var detectedAt: Date
        public var userDismissed: Bool
        public var trialLengthDays: Int? = nil

        public init(
            id: UUID = UUID(),
            serviceName: String,
            senderDomain: String = "",
            trialEndDate: Date,
            chargeAmount: Decimal?,
            detectedAt: Date = Date(),
            userDismissed: Bool = false,
            trialLengthDays: Int? = nil
        ) {
            self.id = id
            self.serviceName = serviceName
            self.senderDomain = senderDomain
            self.trialEndDate = trialEndDate
            self.chargeAmount = chargeAmount
            self.detectedAt = detectedAt
            self.userDismissed = userDismissed
            self.trialLengthDays = trialLengthDays
        }
    }

    @Model
    public final class TrialAlertV1 {
        public var id: UUID
        public var trialID: UUID
        public var triggerDate: Date
        public var alertKind: String
        public var alertDays: Int?
        public var delivered: Bool

        public init(id: UUID, trialID: UUID, triggerDate: Date, alertKind: String, alertDays: Int?, delivered: Bool) {
            self.id = id
            self.trialID = trialID
            self.triggerDate = triggerDate
            self.alertKind = alertKind
            self.alertDays = alertDays
            self.delivered = delivered
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SchemaV1.swift
git commit -m "feat(model): snapshot pre-pivot schema as SublySchemaV1"
```

### Task 1.3: Modify `Trial` to reflect new fields; create SchemaV2

**Files:**
- Modify: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Trial.swift`
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SchemaV2.swift`
- Test: `Packages/SubscriptionStore/Tests/SubscriptionStoreTests/TrialModelTests.swift`

- [ ] **Step 1: Write failing tests for new field defaults**

```swift
// TrialModelTests.swift
import XCTest
import SwiftData
@testable import SubscriptionStore

final class TrialModelTests: XCTestCase {
    func testDefaultsAreTrialAndActive() {
        let t = Trial(serviceName: "Spotify", chargeDate: Date().addingTimeInterval(86400 * 7), chargeAmount: 9.99)
        XCTAssertEqual(t.entryType, .freeTrial)
        XCTAssertEqual(t.status, .active)
        XCTAssertNil(t.billingCycle)
        XCTAssertNil(t.notificationOffset)
        XCTAssertNil(t.cancelledAt)
    }
    func testSubscriptionInitRequiresBillingCycle() {
        let t = Trial(serviceName: "Netflix", chargeDate: Date().addingTimeInterval(86400 * 30), chargeAmount: 15.49, entryType: .subscription, billingCycle: .monthly)
        XCTAssertEqual(t.entryType, .subscription)
        XCTAssertEqual(t.billingCycle, .monthly)
    }
}
```

- [ ] **Step 2: Replace `Trial.swift` with updated model**

```swift
// Trial.swift
import Foundation
import SwiftData

/// Represents a user-tracked financial event — a free trial or a recurring
/// subscription. Named `Trial` for backwards compatibility with the pre-pivot
/// codebase; `entryType` disambiguates trials from subscriptions. A class
/// rename to `SublyEntry` is deferred to v1.1.
@Model
public final class Trial {
    @Attribute(.unique) public var id: UUID
    public var serviceName: String
    public var senderDomain: String
    /// When money is scheduled to leave the user's account. For trials this is
    /// the trial end date; for subscriptions this is the next billing date.
    /// Renamed from `trialEndDate` in the subscription pivot (schema v2).
    public var chargeDate: Date
    public var chargeAmount: Decimal?
    public var detectedAt: Date
    public var userDismissed: Bool
    public var trialLengthDays: Int? = nil

    // --- Subscription-pivot fields (schema v2) ---
    public var entryTypeRaw: String
    public var statusRaw: String
    public var billingCycleRaw: String?
    public var notificationOffset: Int?
    public var cancelledAt: Date?

    public var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .freeTrial }
        set { entryTypeRaw = newValue.rawValue }
    }
    public var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    public var billingCycle: BillingCycle? {
        get { billingCycleRaw.flatMap(BillingCycle.init(rawValue:)) }
        set { billingCycleRaw = newValue?.rawValue }
    }

    public init(
        id: UUID = UUID(),
        serviceName: String,
        senderDomain: String = "",
        chargeDate: Date,
        chargeAmount: Decimal?,
        detectedAt: Date = Date(),
        userDismissed: Bool = false,
        trialLengthDays: Int? = nil,
        entryType: EntryType = .freeTrial,
        status: EntryStatus = .active,
        billingCycle: BillingCycle? = nil,
        notificationOffset: Int? = nil,
        cancelledAt: Date? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.chargeDate = chargeDate
        self.chargeAmount = chargeAmount
        self.detectedAt = detectedAt
        self.userDismissed = userDismissed
        self.trialLengthDays = trialLengthDays
        self.entryTypeRaw = entryType.rawValue
        self.statusRaw = status.rawValue
        self.billingCycleRaw = billingCycle?.rawValue
        self.notificationOffset = notificationOffset
        self.cancelledAt = cancelledAt
    }
}
```

- [ ] **Step 3: Create `SchemaV2.swift` declaring the current schema**

```swift
// SchemaV2.swift
import Foundation
import SwiftData

public enum SublySchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Trial.self, TrialAlert.self] }
}
```

- [ ] **Step 4: Run package build to verify compilation**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift build
```
Expected: Build succeeds. Model tests still reference `trialEndDate`, so these will FAIL next — fixing in Task 1.5.

- [ ] **Step 5: Update any in-package code that referenced `trialEndDate`**

Within `Packages/SubscriptionStore/`, any reference to `trialEndDate` is in tests only. Fix by replacing with `chargeDate`. Other packages are updated in Phase 2.

- [ ] **Step 6: Run model test to verify it passes**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test --filter TrialModelTests
```
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Trial.swift \
        Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SchemaV2.swift \
        Packages/SubscriptionStore/Tests/SubscriptionStoreTests/TrialModelTests.swift
git commit -m "feat(model): add subscription-pivot fields + SchemaV2"
```

### Task 1.4: Create migration plan

**Files:**
- Create: `Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SublyMigrationPlan.swift`
- Test: `Packages/SubscriptionStore/Tests/SubscriptionStoreTests/MigrationTests.swift`

- [ ] **Step 1: Write failing migration test**

```swift
// MigrationTests.swift
import XCTest
import SwiftData
@testable import SubscriptionStore

final class MigrationTests: XCTestCase {
    func testV1ToV2MigrationPreservesTrialData() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("subly-migration-\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Stage 1: populate V1 schema
        do {
            let v1Schema = Schema(versionedSchema: SublySchemaV1.self)
            let config = ModelConfiguration(schema: v1Schema, url: tempURL)
            let container = try ModelContainer(for: v1Schema, configurations: [config])
            let context = ModelContext(container)
            let t = SublySchemaV1.TrialV1(
                serviceName: "Spotify",
                trialEndDate: Date(timeIntervalSince1970: 1_700_000_000),
                chargeAmount: 9.99
            )
            context.insert(t)
            try context.save()
        }

        // Stage 2: open with V2 schema + migration plan
        let v2Schema = Schema(versionedSchema: SublySchemaV2.self)
        let config = ModelConfiguration(schema: v2Schema, url: tempURL)
        let container = try ModelContainer(
            for: v2Schema,
            migrationPlan: SublyMigrationPlan.self,
            configurations: [config]
        )
        let context = ModelContext(container)
        let fetch = FetchDescriptor<Trial>()
        let trials = try context.fetch(fetch)
        XCTAssertEqual(trials.count, 1)
        let t = trials[0]
        XCTAssertEqual(t.serviceName, "Spotify")
        XCTAssertEqual(t.chargeDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(t.entryType, .freeTrial)
        XCTAssertEqual(t.status, .active)
        XCTAssertNil(t.billingCycle)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test --filter MigrationTests
```
Expected: FAIL with "Cannot find 'SublyMigrationPlan'"

- [ ] **Step 3: Create `SublyMigrationPlan.swift`**

```swift
// SublyMigrationPlan.swift
import Foundation
import SwiftData

public enum SublyMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SublySchemaV1.self, SublySchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SublySchemaV1.self,
        toVersion: SublySchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // Fill defaults for new fields on every migrated row.
            let descriptor = FetchDescriptor<Trial>()
            let migrated = try context.fetch(descriptor)
            for t in migrated {
                if t.entryTypeRaw.isEmpty { t.entryTypeRaw = EntryType.freeTrial.rawValue }
                if t.statusRaw.isEmpty { t.statusRaw = EntryStatus.active.rawValue }
                // chargeDate was renamed from trialEndDate — value carries forward
                // via SwiftData's attribute renaming (see Trial.swift note).
            }
            try context.save()
        }
    )
}
```

**Note on rename:** SwiftData supports attribute renaming via `@Attribute(originalName: "trialEndDate")`. Add this attribute to `chargeDate` in `Trial.swift` to signal the rename:

```swift
@Attribute(originalName: "trialEndDate")
public var chargeDate: Date
```

- [ ] **Step 4: Update `Trial.swift` to add the `originalName` attribute**

Edit `chargeDate` declaration in `Trial.swift`:

```swift
@Attribute(originalName: "trialEndDate")
public var chargeDate: Date
```

- [ ] **Step 5: Run migration test**

```bash
cd ~/Developer/Subly/Packages/SubscriptionStore && swift test --filter MigrationTests
```
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Packages/SubscriptionStore/Sources/SubscriptionStore/Models/SublyMigrationPlan.swift \
        Packages/SubscriptionStore/Sources/SubscriptionStore/Models/Trial.swift \
        Packages/SubscriptionStore/Tests/SubscriptionStoreTests/MigrationTests.swift
git commit -m "feat(model): add V1→V2 migration plan with field rename"
```

### Task 1.5: Wire migration plan into SublyApp

**Files:**
- Modify: `Subly/SublyApp.swift:13-38`

- [ ] **Step 1: Replace `Schema([Trial.self, TrialAlert.self])` with versioned + migration plan**

In `SublyApp.swift`, replace lines 13-21 (the `schema` and initial `try ModelContainer(...)` call):

```swift
private static let modelContainer: ModelContainer = {
    let schema = Schema(versionedSchema: SublySchemaV2.self)
    let configuration = ModelConfiguration(schema: schema)

    do {
        return try ModelContainer(
            for: schema,
            migrationPlan: SublyMigrationPlan.self,
            configurations: [configuration]
        )
    } catch {
        schemaLog.error("ModelContainer load failed: \(String(describing: error), privacy: .public)")
        // ... existing retry/wipe fallback logic unchanged
```

Keep the existing `isUnrecoverableSchemaError` / `wipeAndReload` / retry chain exactly as-is — those remain the last-resort fallback if the migration itself fails.

- [ ] **Step 2: Update remaining retry path call to pass migration plan**

Find every `try ModelContainer(for: schema, configurations: [configuration])` call inside `modelContainer` closure and `wipeAndReload`. Replace each with:

```swift
try ModelContainer(
    for: schema,
    migrationPlan: SublyMigrationPlan.self,
    configurations: [configuration]
)
```

- [ ] **Step 3: Build the app**

```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | tail -30
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run the app on simulator, confirm no schema wipe on launch**

```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build test 2>&1 | tail -20
```

Manually: launch app, verify trials list is not empty (existing seed data preserved). If this is a fresh sim, add a trial, relaunch, verify it persists.

- [ ] **Step 5: Run `superpowers:verification-before-completion`**

- [ ] **Step 6: Run `code-review` local mode**

- [ ] **Step 7: Commit and push**

```bash
git add Subly/SublyApp.swift
git commit -m "feat(app): wire SublyMigrationPlan into ModelContainer load"
git push -u origin colehollander10/sub-pivot-p1-model
gh pr create --title "sub-pivot: Phase 1 — unified model + V1→V2 migration" --body "$(cat <<'EOF'
## Summary
- Adds EntryType, EntryStatus, BillingCycle enums
- Extends Trial with entryType, status, billingCycle, notificationOffset, cancelledAt
- Renames trialEndDate → chargeDate via SwiftData originalName attribute
- Adds SublySchemaV1/V2 and SublyMigrationPlan for lossless migration

## Test plan
- [x] Package tests pass (EnumTests, TrialModelTests, MigrationTests)
- [x] xcodebuild green on iPhone 16 Pro simulator
- [x] Launch app with existing seed data; no wipe, trials carry forward
EOF
)"
```

- [ ] **Step 8: Merge**

```bash
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Phase 2 — Engine Updates (Opus inline)

**Route:** Opus inline. Engines are the spine; bugs here cascade into notifications and UI.
**Branch:** `colehollander10/sub-pivot-p2-engines`
**Outcome:** TrialEngine generalized; NotificationEngine supports per-entry removal and type-aware copy.

### Task 2.1: Generalize TrialEngine for subscriptions

**Files:**
- Modify: `Packages/TrialEngine/Sources/TrialEngine/TrialEngine.swift`
- Test: `Packages/TrialEngine/Tests/TrialEngineTests/SubscriptionPlanTests.swift` (create if needed; check if test file exists)

- [ ] **Step 1: Check existing test file**

```bash
ls ~/Developer/Subly/Packages/TrialEngine/Tests/
```

- [ ] **Step 2: Write failing subscription-plan test**

```swift
// SubscriptionPlanTests.swift
import XCTest
@testable import TrialEngine

final class SubscriptionPlanTests: XCTestCase {
    func testSubscriptionPlanProducesOneDayBeforeOnly() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let charge = now.addingTimeInterval(86400 * 10)
        let alerts = TrialEngine.planSubscription(entryID: id, chargeDate: charge, now: now, calendar: .init(identifier: .gregorian))
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts[0].kind, .subscriptionDayBefore)
    }

    func testSubscriptionPlanDropsPastDates() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let charge = now.addingTimeInterval(-86400)
        let alerts = TrialEngine.planSubscription(entryID: id, chargeDate: charge, now: now, calendar: .init(identifier: .gregorian))
        XCTAssertTrue(alerts.isEmpty)
    }

    func testTrialPlanSignatureAcceptsChargeDateParamName() {
        // Backwards compatibility: existing signature still works.
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let end = now.addingTimeInterval(86400 * 5)
        let alerts = TrialEngine.plan(trialID: id, chargeDate: end, now: now, calendar: .init(identifier: .gregorian))
        XCTAssertFalse(alerts.isEmpty)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd ~/Developer/Subly/Packages/TrialEngine && swift test --filter SubscriptionPlanTests
```
Expected: FAIL

- [ ] **Step 4: Update `PlannedTrialAlert.Kind` to include subscription case**

In `TrialEngine.swift`, change the Kind enum:

```swift
public enum Kind: String, Sendable {
    case threeDaysBefore
    case dayBefore
    case dayOf
    case subscriptionDayBefore
}
```

- [ ] **Step 5: Rename `trialEndDate` param to `chargeDate` in `plan(...)` with backwards-compatible overload**

Replace the existing `plan` method with:

```swift
public static func plan(
    trialID: UUID,
    chargeDate: Date,
    now: Date = Date(),
    calendar: Calendar = .current
) -> [PlannedTrialAlert] {
    let morningOfEnd = alertTime(on: chargeDate, calendar: calendar)
    guard let threeDaysBefore = calendar.date(byAdding: .day, value: -3, to: morningOfEnd),
          let dayBefore = calendar.date(byAdding: .day, value: -1, to: morningOfEnd) else {
        return []
    }

    let candidates: [PlannedTrialAlert] = [
        .init(trialID: trialID, kind: .threeDaysBefore, triggerDate: threeDaysBefore),
        .init(trialID: trialID, kind: .dayBefore, triggerDate: dayBefore),
        .init(trialID: trialID, kind: .dayOf, triggerDate: morningOfEnd),
    ]

    return candidates.filter { $0.triggerDate > now }
}
```

- [ ] **Step 6: Add `planSubscription(...)` static method**

Add below `plan(...)` in `TrialEngine.swift`:

```swift
/// Plans the default 1-day-before alert for a subscription renewal.
/// Subscriptions are expected charges, so we use a single heads-up alert
/// by default (customizable via per-entry notificationOffset).
public static func planSubscription(
    entryID: UUID,
    chargeDate: Date,
    now: Date = Date(),
    calendar: Calendar = .current
) -> [PlannedTrialAlert] {
    let morningOfCharge = alertTime(on: chargeDate, calendar: calendar)
    guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: morningOfCharge) else {
        return []
    }
    let candidate = PlannedTrialAlert(
        trialID: entryID,
        kind: .subscriptionDayBefore,
        triggerDate: dayBefore
    )
    return candidate.triggerDate > now ? [candidate] : []
}
```

- [ ] **Step 7: Run tests**

```bash
cd ~/Developer/Subly/Packages/TrialEngine && swift test
```
Expected: PASS (including existing trial tests)

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/Subly && git checkout -b colehollander10/sub-pivot-p2-engines
git add Packages/TrialEngine/Sources/TrialEngine/TrialEngine.swift \
        Packages/TrialEngine/Tests/TrialEngineTests/SubscriptionPlanTests.swift
git commit -m "feat(engine): generalize TrialEngine, add planSubscription"
```

### Task 2.2: Add targeted notification removal to NotificationEngine

**Files:**
- Modify: `Packages/NotificationEngine/Sources/NotificationEngine/NotificationEngine.swift`
- Test: `Packages/NotificationEngine/Tests/NotificationEngineTests/NotificationEngineTests.swift`

- [ ] **Step 1: Write failing test for `removePending(ids:)`**

Add to existing `NotificationEngineTests.swift`:

```swift
func testRemovePendingByIDs() async {
    let mock = MockNotificationCenter()
    mock.pending = [
        UNNotificationRequest(identifier: "a", content: .init(), trigger: nil),
        UNNotificationRequest(identifier: "b", content: .init(), trigger: nil),
    ]
    let engine = NotificationEngine(center: mock)
    await engine.removePending(ids: ["a"])
    XCTAssertEqual(mock.removedIdentifiers, ["a"])
}
```

If `MockNotificationCenter` already exists in tests, reuse it — inspect the file first. Otherwise add the removal-tracking properties to the existing mock.

- [ ] **Step 2: Add protocol method to `NotificationCenterProtocol`**

In `NotificationEngine.swift`:

```swift
public protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}
```

`UNUserNotificationCenter` already implements `removePendingNotificationRequests(withIdentifiers:)` natively, so the extension conformance still holds.

- [ ] **Step 3: Add `removePending(ids:)` method to NotificationEngine actor**

```swift
/// Targeted removal of pending notifications by their request identifiers.
/// Use when an entry is cancelled or deleted and its pending alerts should
/// be cleared without touching the rest of the schedule.
public func removePending(ids: [String]) async {
    center.removePendingNotificationRequests(withIdentifiers: ids)
}
```

- [ ] **Step 4: Run tests**

```bash
cd ~/Developer/Subly/Packages/NotificationEngine && swift test
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Packages/NotificationEngine/Sources/NotificationEngine/NotificationEngine.swift \
        Packages/NotificationEngine/Tests/NotificationEngineTests/NotificationEngineTests.swift
git commit -m "feat(notifications): add targeted removePending(ids:) method"
```

### Task 2.3: Type-aware notification copy templates

**Files:**
- Create: `Packages/NotificationEngine/Sources/NotificationEngine/NotificationCopy.swift`
- Test: `Packages/NotificationEngine/Tests/NotificationEngineTests/NotificationCopyTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NotificationCopyTests.swift
import XCTest
@testable import NotificationEngine

final class NotificationCopyTests: XCTestCase {
    func testTrialThreeDaysBeforeCopy() {
        let copy = NotificationCopy.trial(
            kind: .threeDaysBefore,
            serviceName: "Spotify",
            chargeAmount: 9.99,
            chargeDate: makeDate("2026-05-01")
        )
        XCTAssertEqual(copy.title, "Your Spotify trial ends in 3 days")
        XCTAssertTrue(copy.body.contains("$9.99"))
        XCTAssertTrue(copy.body.contains("May 1"))
    }

    func testTrialDayOfCopy() {
        let copy = NotificationCopy.trial(
            kind: .dayOf,
            serviceName: "Netflix",
            chargeAmount: 15.49,
            chargeDate: Date()
        )
        XCTAssertEqual(copy.title, "Your Netflix trial charges today")
    }

    func testSubscriptionCopy() {
        let copy = NotificationCopy.subscription(
            serviceName: "iCloud+",
            chargeAmount: 2.99
        )
        XCTAssertEqual(copy.title, "iCloud+ renews tomorrow")
        XCTAssertTrue(copy.body.contains("$2.99"))
    }

    private func makeDate(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? Date()
    }
}
```

- [ ] **Step 2: Run to verify fails**

```bash
cd ~/Developer/Subly/Packages/NotificationEngine && swift test --filter NotificationCopyTests
```
Expected: FAIL "Cannot find 'NotificationCopy'"

- [ ] **Step 3: Create `NotificationCopy.swift`**

```swift
// NotificationCopy.swift
import Foundation

public struct RenderedCopy: Sendable, Equatable {
    public let title: String
    public let body: String
}

public enum NotificationCopy {
    public enum TrialKind: Sendable {
        case threeDaysBefore
        case dayBefore
        case dayOf
    }

    public static func trial(
        kind: TrialKind,
        serviceName: String,
        chargeAmount: Decimal?,
        chargeDate: Date
    ) -> RenderedCopy {
        let amount = formatAmount(chargeAmount)
        let dateStr = shortDate(chargeDate)
        switch kind {
        case .threeDaysBefore:
            return RenderedCopy(
                title: "Your \(serviceName) trial ends in 3 days",
                body: "\(amount) charges on \(dateStr)"
            )
        case .dayBefore:
            return RenderedCopy(
                title: "Your \(serviceName) trial ends tomorrow",
                body: "\(amount) charges on \(dateStr)"
            )
        case .dayOf:
            return RenderedCopy(
                title: "Your \(serviceName) trial charges today",
                body: amount
            )
        }
    }

    public static func subscription(
        serviceName: String,
        chargeAmount: Decimal?
    ) -> RenderedCopy {
        let amount = formatAmount(chargeAmount)
        return RenderedCopy(
            title: "\(serviceName) renews tomorrow",
            body: amount
        )
    }

    private static func formatAmount(_ amount: Decimal?) -> String {
        guard let amount else { return "" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: amount as NSDecimalNumber) ?? ""
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd ~/Developer/Subly/Packages/NotificationEngine && swift test --filter NotificationCopyTests
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Packages/NotificationEngine/Sources/NotificationEngine/NotificationCopy.swift \
        Packages/NotificationEngine/Tests/NotificationEngineTests/NotificationCopyTests.swift
git commit -m "feat(notifications): add type-aware copy templates"
```

### Task 2.4: Fix app-layer compilation (trialEndDate → chargeDate callsites)

**Files:** any file in `Subly/` that references `trialEndDate`.

- [ ] **Step 1: Find all callsites**

```bash
cd ~/Developer/Subly && grep -rn "trialEndDate" Subly/ Packages/
```

- [ ] **Step 2: Replace `trialEndDate` → `chargeDate` across app-layer code**

Common expected callsites (adjust based on grep results):
- `HomeView.swift` — urgency calc, "Ends in X days" text
- `TrialsView.swift` — list rendering, groupings
- `Sheets.swift` — Add Trial sheet field binding
- `TrialAlertCoordinator.swift` — planning alerts
- `OnboardingView.swift` — any seed data

Replace each one: simple identifier rename. Keep function/view names that happen to contain "trialEnd..." — the field rename is pure; parameter name `trialEndDate` in `TrialEngine.plan(...)` is now `chargeDate` (per Task 2.1), update callsites accordingly.

- [ ] **Step 3: Build**

```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -30
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run `superpowers:verification-before-completion`** (build + tests)

- [ ] **Step 5: Commit, push, open PR, merge**

```bash
git add -A
git commit -m "refactor: update callsites for trialEndDate → chargeDate rename"
git push -u origin colehollander10/sub-pivot-p2-engines
gh pr create --title "sub-pivot: Phase 2 — engine updates" --body "$(cat <<'EOF'
## Summary
- TrialEngine.plan renamed param trialEndDate → chargeDate
- Added TrialEngine.planSubscription for subscription renewals
- Added Kind.subscriptionDayBefore
- NotificationEngine: new removePending(ids:) for targeted cancellation
- Added NotificationCopy with type-aware title/body templates
- Updated app-layer callsites for chargeDate rename

## Test plan
- [x] TrialEngine tests green (plan + planSubscription)
- [x] NotificationEngine tests green (removePending + copy templates)
- [x] Full xcodebuild green
EOF
)"
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Phase 3 — Shared Add-Entry Field Components (Opus inline)

**Route:** Opus inline. The extraction is a careful refactor of `Sheets.swift` (578 lines); risks regressions in the existing Add Trial flow if not done deliberately.
**Branch:** `colehollander10/sub-pivot-p3-addentry-components`
**Outcome:** `ServiceNameField`, `AmountField`, `DatePickerField` extracted; Add Trial sheet refactored to use them; no behavior change.

### Task 3.1: Extract ServiceNameField

**Files:**
- Read: `Subly/Sheets.swift` (full file to identify the extraction surface)
- Create: `Subly/AddEntry/Components/ServiceNameField.swift`
- Modify: `Subly/Sheets.swift`

- [ ] **Step 1: Read existing Sheets.swift to locate the service-name UI block**

```bash
cat ~/Developer/Subly/Subly/Sheets.swift | head -200
```

- [ ] **Step 2: Write a `ServiceNameField` view matching the existing styling**

Create `Subly/AddEntry/Components/ServiceNameField.swift`. The exact SwiftUI structure should mirror whatever is in `Sheets.swift` for the service-name row — copy it exactly, replacing local `@State` / bindings with a `@Binding var text: String` parameter. Example skeleton:

```swift
import SwiftUI

struct ServiceNameField: View {
    @Binding var text: String
    var placeholder: String = "Service name"

    var body: some View {
        // Paste the existing service-name TextField block from Sheets.swift,
        // replacing the state binding with `text`.
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(SublyTheme.primaryText)
            // ... match existing container styling
    }
}
```

- [ ] **Step 3: Replace the inline service-name field in `Sheets.swift` with `ServiceNameField(text: $serviceName)`**

- [ ] **Step 4: Build + smoke-test Add Trial sheet visually**

```bash
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Launch app, tap +, open Add Trial, confirm the field looks identical.

- [ ] **Step 5: Commit**

```bash
git checkout -b colehollander10/sub-pivot-p3-addentry-components
git add Subly/AddEntry/Components/ServiceNameField.swift Subly/Sheets.swift
git commit -m "refactor(addentry): extract ServiceNameField component"
```

### Task 3.2: Extract AmountField

Repeat Task 3.1 pattern for the charge amount field. Copy existing styling (including `$` prefix, already-shipped in COL-135), replace inline usage in `Sheets.swift` with `AmountField(amount: $chargeAmount)`. Commit with message: `refactor(addentry): extract AmountField component`.

### Task 3.3: Extract DatePickerField

Repeat Task 3.1 pattern for the trial end-date / date picker. Component interface:

```swift
struct DatePickerField: View {
    @Binding var date: Date
    var label: String
    // ... quick-pick chips are Add-Trial-specific; keep those in AddTrialSheet.
}
```

Commit with message: `refactor(addentry): extract DatePickerField component`.

### Task 3.4: Push and merge

```bash
cd ~/Developer/Subly && xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -10
git push -u origin colehollander10/sub-pivot-p3-addentry-components
gh pr create --title "sub-pivot: Phase 3 — extract shared add-entry field components" --body "Preparation for Add Subscription sheet. No behavior change."
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Phase 4 — Add Subscription Sheet (Cursor delegation)

**Route:** Cursor, model `composer-2-fast`. Well-specified new view, parallel-safe with Phase 5.
**Branch:** Cursor opens its own worktree on `colehollander10/sub-pivot-p4-add-subscription`.
**Outcome:** AddSubscriptionSheet ships, wired into a temporary FAB for manual testing.

### Task 4.1: Delegate to Cursor

- [ ] **Step 1: Run Cursor task**

```bash
/cursor:task Create AddSubscriptionSheet in Subly/AddEntry/AddSubscriptionSheet.swift.

The sheet is a new SwiftUI view for adding a .subscription entry to the store. It mirrors the existing Add Trial sheet (Subly/Sheets.swift) in styling and structure, but with different fields.

Fields (in order):
1. SERVICE — use ServiceNameField(text: $serviceName) from Subly/AddEntry/Components/ServiceNameField.swift
2. NEXT BILLING DATE — use DatePickerField(date: $chargeDate, label: "Next billing date"), default to 30 days from today
3. BILLING CYCLE — segmented Picker with cases Monthly, Yearly, Weekly, Custom (from BillingCycle enum in SubscriptionStore package)
4. CHARGE AMOUNT — use AmountField(amount: $chargeAmount)

Save button at bottom: creates a Trial with entryType = .subscription, status = .active, billingCycle set, chargeDate set, chargeAmount set, serviceName set. Inserts into the ModelContext, dismisses sheet, triggers light haptic via Haptics.swift patterns.

Match exactly: GlassComponents.swift card styling, SublyTheme colors, font weights from DESIGN.md (SF Pro Rounded for titles, SF Pro Text for body, .medium or heavier, never .regular). Sheet uses the same backgroundElevated color as the Add Trial sheet. Section labels use tertiaryText, UPPERCASE, tracking 1.8, SF Pro Text 10pt semibold.

DO NOT:
- modify Sheets.swift or AddTrialSheet.swift
- modify Trial.swift or any file in Packages/
- add any field beyond the 4 listed above
- use hardcoded colors — only SublyTheme tokens
- use SF Symbols — this project uses Phosphor (but no icons are needed in this sheet specifically)

Acceptance:
- File compiles as part of the Subly target
- Preview renders correctly in Xcode
- Tapping Save from a preview with filled fields prints the created Trial to console (temporary diagnostic OK — will be replaced when wired into FAB)

Imports required: SwiftUI, SwiftData, SubscriptionStore.
```

- [ ] **Step 2: Review Cursor's diff, merge to branch, commit**

While Cursor runs, I proceed to Phase 5 in parallel.

---

## Phase 5 — Cancel-Assist Sheet + CancelGuides.json (Cursor delegation)

**Route:** Cursor, model `composer-2-fast`. Well-specified, no conversation context needed.
**Branch:** `colehollander10/sub-pivot-p5-cancel-assist` (Cursor worktree)
**Outcome:** Cancel-assist sheet + JSON content + Trial detail Cancel button.

### Task 5.1: Delegate to Cursor

- [ ] **Step 1: Run Cursor task**

```bash
/cursor:task Create a cancel-assist flow in Subly for trials.

Files to create:

1. Subly/Resources/CancelGuides.json — curated cancel instructions for 15 services. Each entry keyed by a normalized service name (lowercased, alphanumeric only). Shape per entry:
   { "steps": ["step 1 text", "step 2 text", ...], "directURL": "https://...", "notes": null }

   The 15 services: Spotify, Netflix, Hulu, Disney+, iCloud+, Apple Music, Amazon Prime, HBO Max, YouTube Premium, ChatGPT, Notion, Adobe Creative Cloud, Canva, Duolingo, Audible.

   Keys must be normalized: "spotify", "netflix", "hulu", "disney", "icloud", "applemusic", "amazonprime", "hbomax", "youtubepremium", "chatgpt", "notion", "adobecreativecloud", "canva", "duolingo", "audible".

   Steps should be 3-5 actionable lines per service. Use publicly-known cancel paths. Include real directURLs (e.g. https://www.spotify.com/account/subscription/).

2. Subly/CancelAssist/CancelGuide.swift — Codable struct:
   struct CancelGuide: Codable, Equatable { let steps: [String]; let directURL: String?; let notes: String? }

3. Subly/CancelAssist/CancelGuideStore.swift — loads CancelGuides.json once from the app bundle and exposes `func guide(for serviceName: String) -> CancelGuide?` that normalizes the input (lowercase, alphanumeric-only) and looks up the guide. Use a private lazy static cache. Normalization helper: `private static func normalize(_ s: String) -> String`.

4. Subly/CancelAssist/CancelAssistSheet.swift — full-screen sheet. Takes a Trial as input. Layout:
   - Top: close button (✕) top-trailing
   - Title: "How to cancel \(trial.serviceName)" — SF Pro Rounded 28pt bold
   - If CancelGuideStore.guide(for:) returns a guide: render a SurfaceCard containing numbered steps
   - If guide has directURL: a primary pill button "Open {serviceName}.com →" that opens the URL via `openURL` environment
   - Always: a secondary pill button "Search how to cancel {serviceName} →" that opens https://duckduckgo.com/?q=how+to+cancel+{urlEncoded serviceName}
   - Bottom two buttons stacked (not side-by-side): primary lavender "I canceled it" + ghost/secondary "I'll do it later"
   
   "I canceled it" action: set trial.status = .cancelled, trial.cancelledAt = Date(), call notificationEngine.removePending(ids:) for the trial's pending alerts (fetch TrialAlerts for this trialID, pass their id.uuidStrings), save ModelContext, trigger .success haptic via Haptics.swift, dismiss.
   
   "I'll do it later" action: just dismiss.

   Sheet must use GlassComponents styling, SublyTheme colors, no SF Symbols (use Phosphor's X icon for close — `Ph.x.regular` or similar). No urgency color ramp in this sheet.

5. Modify Subly/TrialsView.swift — add a "Cancel" button to the trial detail sheet that presents CancelAssistSheet for that trial. Find the existing trial detail sheet (or the row tap action) and wire the Cancel button there. Do not change the rest of TrialsView.

DO NOT:
- modify HomeView.swift (separate phase)
- modify any file in Packages/
- add analytics, tracking, or any network calls beyond openURL
- use any Google/third-party URLs — only the vendor's directURL from JSON and the DuckDuckGo fallback

Acceptance:
- xcodebuild green
- Tapping a trial in TrialsView surfaces a Cancel button; tapping it opens CancelAssistSheet
- Selecting "I canceled it" flips the trial to .cancelled status and dismisses
- Unknown service (serviceName = "UnknownFooBar"): sheet hides the curated card, shows only the DuckDuckGo search button

Imports needed: SwiftUI, SwiftData, SubscriptionStore, NotificationEngine, PhosphorSwift.
```

- [ ] **Step 2: While Cursor runs, continue to other work.**

---

## Phase 6 — Fox System (Opus inline)

**Route:** Opus inline. Animation tuning benefits from iteration, not a one-shot prompt.
**Branch:** `colehollander10/sub-pivot-p6-fox`
**Outcome:** FoxState + FoxView + 4 placements (empty-Home, Settings, onboarding, cancel-celebration).

### Task 6.1: Create `FoxState.swift`

**Files:**
- Create: `Subly/Fox/FoxState.swift`

- [ ] **Step 1: Create file**

```swift
// FoxState.swift
import Foundation

enum FoxState: String, CaseIterable {
    case sleeping
    case curious
    case happy
    case veryHappy
    case proud
    case alert   // reserved for v1.1 milestones; unused in v1
}
```

- [ ] **Step 2: Commit**

```bash
git checkout -b colehollander10/sub-pivot-p6-fox
git add Subly/Fox/FoxState.swift
git commit -m "feat(fox): add FoxState enum"
```

### Task 6.2: Create minimal `FoxView.swift`

**Files:**
- Create: `Subly/Fox/FoxView.swift`
- Create: `Subly/Fox/FoxAnimation.swift`

**v1 implementation approach:** Composite SwiftUI view built from simple shapes (rounded triangles for ears, circles for eyes, an ellipse body) or a single SF-Symbol-styled drawing. The exact illustration is iterable; ship something minimal that is clearly a fox, then refine visually by launching the app and adjusting.

- [ ] **Step 1: Create `FoxView.swift` with a minimal composite fox**

```swift
// FoxView.swift
import SwiftUI

struct FoxView: View {
    let state: FoxState
    var size: CGFloat = 120

    @State private var blinking: Bool = false
    @State private var wiggleEar: Bool = false

    var body: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(SublyTheme.accent.opacity(0.25))
                .frame(width: size * 0.9, height: size * 0.7)
                .offset(y: size * 0.15)

            // Head
            Circle()
                .fill(SublyTheme.accent)
                .frame(width: size * 0.55, height: size * 0.55)

            // Ears
            Triangle()
                .fill(SublyTheme.accent)
                .frame(width: size * 0.18, height: size * 0.22)
                .offset(x: -size * 0.2, y: -size * 0.28)
                .rotationEffect(.degrees(wiggleEar ? -8 : 0))
            Triangle()
                .fill(SublyTheme.accent)
                .frame(width: size * 0.18, height: size * 0.22)
                .offset(x: size * 0.2, y: -size * 0.28)
                .rotationEffect(.degrees(wiggleEar ? 8 : 0))

            // Eyes (blink when sleeping)
            HStack(spacing: size * 0.12) {
                eye
                eye
            }
            .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size)
        .onAppear { startIdleAnimations() }
        .onChange(of: state) { _, _ in restartIdle() }
    }

    private var eye: some View {
        Group {
            if state == .sleeping || blinking {
                Capsule()
                    .fill(SublyTheme.primaryText)
                    .frame(width: size * 0.08, height: size * 0.02)
            } else {
                Circle()
                    .fill(SublyTheme.primaryText)
                    .frame(width: size * 0.06, height: size * 0.06)
            }
        }
    }

    private func startIdleAnimations() {
        switch state {
        case .sleeping:
            break  // eyes stay closed
        case .curious:
            blinkLoop()
        case .happy, .veryHappy:
            earWiggleLoop()
            blinkLoop()
        case .proud:
            // brief ear wiggle; caller controls appearance duration
            withAnimation(.easeInOut(duration: 0.3)) { wiggleEar = true }
        case .alert:
            blinkLoop()
        }
    }

    private func restartIdle() {
        blinking = false
        wiggleEar = false
        startIdleAnimations()
    }

    private func blinkLoop() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...7)))
                withAnimation(.easeInOut(duration: 0.15)) { blinking = true }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeInOut(duration: 0.15)) { blinking = false }
            }
        }
    }

    private func earWiggleLoop() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3...5)))
                withAnimation(.easeInOut(duration: 0.25)) { wiggleEar = true }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeInOut(duration: 0.25)) { wiggleEar = false }
            }
        }
    }
}

// Simple triangle for ears
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    VStack {
        FoxView(state: .sleeping)
        FoxView(state: .happy)
        FoxView(state: .proud)
    }
    .background(SublyTheme.background)
}
```

- [ ] **Step 2: Verify previews render in Xcode**

Open `FoxView.swift` in Xcode, expand canvas, confirm the fox is recognizable. The design is intentionally minimal — visual refinement is iterative. A stretch goal is replacing with a hand-drawn SVG, but not a v1 blocker.

- [ ] **Step 3: Commit**

```bash
git add Subly/Fox/FoxView.swift
git commit -m "feat(fox): add minimal composite FoxView"
```

### Task 6.3: Wire fox into HomeView empty state

Deferred to Phase 7 (HomeView rebuild). Placeholder here.

### Task 6.4: Wire fox into SettingsView header

**Files:**
- Modify: `Subly/SettingsView.swift`

- [ ] **Step 1: Add `FoxView(state: .curious, size: 40)` to Settings header**

Find the existing header in `SettingsView.swift` (title "Settings" area). Insert a small HStack with `FoxView(state: .curious, size: 40)` trailing the title. Verify it doesn't break existing layout.

- [ ] **Step 2: Build + visual check**

```bash
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Launch app, tap Settings tab, confirm the small fox appears and blinks periodically.

- [ ] **Step 3: Commit**

```bash
git add Subly/SettingsView.swift
git commit -m "feat(fox): add curious fox to Settings header"
```

### Task 6.5: Wire fox into cancel-celebration sheet

**Files:**
- Create: `Subly/CancelAssist/CancelCelebrationSheet.swift`
- Modify: `Subly/CancelAssist/CancelAssistSheet.swift` (to present the celebration on "I canceled it")

- [ ] **Step 1: Create celebration sheet**

```swift
// CancelCelebrationSheet.swift
import SwiftUI

struct CancelCelebrationSheet: View {
    let amount: Decimal?
    let serviceName: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            FoxView(state: .proud, size: 160)
            Text("Caught \(formatted(amount))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(SublyTheme.primaryText)
            Text(serviceName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SublyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SublyTheme.background.ignoresSafeArea())
        .onAppear {
            Haptics.success()
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                isPresented = false
            }
        }
    }

    private func formatted(_ amount: Decimal?) -> String {
        guard let amount else { return "$0" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}
```

- [ ] **Step 2: In `CancelAssistSheet.swift`, present the celebration after "I canceled it"**

(Assumes CancelAssistSheet was built by Cursor in Phase 5; adjust integration to fit its actual shape.)

In the "I canceled it" action handler, after setting status/cancelledAt/saving/removing notifications, set a `@State var showCelebration: Bool = true` and add a `.fullScreenCover(isPresented: $showCelebration) { CancelCelebrationSheet(amount: trial.chargeAmount, serviceName: trial.serviceName, isPresented: $showCelebration) }`. When `isPresented` flips back to false (after 2.2s), dismiss the whole CancelAssistSheet.

- [ ] **Step 3: Build + smoke test**

Run app, create a trial, open TrialsView → trial detail → Cancel → "I canceled it". Confirm proud fox appears for ~2 seconds with haptic, then dismisses back to TrialsView.

- [ ] **Step 4: Commit**

```bash
git add Subly/CancelAssist/CancelCelebrationSheet.swift Subly/CancelAssist/CancelAssistSheet.swift
git commit -m "feat(fox): add proud-fox celebration on cancel confirm"
```

### Task 6.6: Onboarding fox (deferred to Phase 8 bulk-import wiring)

Onboarding fox happiness-meter during StoreKit import is wired in Phase 8. Stub here.

### Task 6.7: Push + merge Phase 6

```bash
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -10
git push -u origin colehollander10/sub-pivot-p6-fox
gh pr create --title "sub-pivot: Phase 6 — fox mascot system v1" --body "Minimal composite FoxView with 6 states (5 used in v1). Wired into Settings header and cancel-celebration sheet. Empty-Home + onboarding wiring in Phases 7 and 8."
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Phase 7 — HomeView Rebuild (Opus inline)

**Route:** Opus inline. Touches DESIGN.md compliance heavily; mid-task visual judgment required.
**Branch:** `colehollander10/sub-pivot-p7-homeview`
**Outcome:** H1 layout with TRIALS ENDING SOON (conditional) + THIS MONTH spend card + sleeping-fox empty state.

### Task 7.1: Create SpendCard component

**Files:**
- Create: `Subly/SpendCard.swift`

- [ ] **Step 1: Write the view**

```swift
// SpendCard.swift
import SwiftData
import SwiftUI
import SubscriptionStore

struct SpendCard: View {
    @Query(filter: #Predicate<Trial> { $0.statusRaw == "active" })
    private var activeEntries: [Trial]

    @Query(filter: #Predicate<Trial> { $0.statusRaw == "cancelled" })
    private var cancelledEntries: [Trial]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("$\(monthlySpendString)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .foregroundColor(SublyTheme.primaryText)

            Text(countsLine)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(SublyTheme.tertiaryText)
                .textCase(.uppercase)
                .tracking(1.8)

            if caughtThisMonth > 0 {
                Rectangle()
                    .fill(SublyTheme.divider)
                    .frame(height: 1)
                Text("Caught $\(caughtString) this month")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SublyTheme.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(SublyTheme.glassBorder, lineWidth: 1)
                )
        )
    }

    private var monthlySpend: Double {
        activeEntries
            .filter { $0.entryType == .subscription }
            .reduce(0.0) { acc, t in
                let amount = (t.chargeAmount as NSDecimalNumber?)?.doubleValue ?? 0.0
                let mult = t.billingCycle?.monthlyMultiplier ?? 1.0
                return acc + (amount * mult)
            }
    }

    private var monthlySpendString: String {
        String(format: "%.2f", monthlySpend)
    }

    private var countsLine: String {
        let subs = activeEntries.filter { $0.entryType == .subscription }.count
        let trials = activeEntries.filter { $0.entryType == .freeTrial }.count
        return "\(subs) subscription\(subs == 1 ? "" : "s") · \(trials) trial\(trials == 1 ? "" : "s") tracked"
    }

    private var caughtThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return cancelledEntries
            .filter { t in
                guard let cancelledAt = t.cancelledAt else { return false }
                return cal.isDate(cancelledAt, equalTo: now, toGranularity: .month)
            }
            .reduce(0.0) { acc, t in
                acc + ((t.chargeAmount as NSDecimalNumber?)?.doubleValue ?? 0.0)
            }
    }

    private var caughtString: String {
        String(format: "%.2f", caughtThisMonth)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git checkout -b colehollander10/sub-pivot-p7-homeview
git add Subly/SpendCard.swift
git commit -m "feat(home): add SpendCard showing monthly spend + caught-$X"
```

### Task 7.2: Rebuild HomeView with H1 layout

**Files:**
- Modify: `Subly/HomeView.swift`

- [ ] **Step 1: Read current HomeView**

```bash
cat ~/Developer/Subly/Subly/HomeView.swift
```

- [ ] **Step 2: Rewrite HomeView to implement H1**

Replace the body of HomeView with a ScrollView containing (in order):
1. Header (wordmark + date + gear button) — keep existing
2. Conditional block: if any active trial has `chargeDate` within 7 days, render TRIALS ENDING SOON section with FlagshipCard for the closest + SurfaceCard of additional compact rows for the rest. Use existing FlagshipCard and CompactRow components from GlassComponents.swift.
3. Else: render a SurfaceCard containing `FoxView(state: .sleeping, size: 100)` + text "You're clear for the next 7 days" in secondaryText.
4. THIS MONTH section: SectionLabel + `SpendCard()`
5. Keep FAB positioning as-is.

Critical: use `@Query` filter for "active trials ending in next 7 days" — predicate on `statusRaw == "active"` AND `entryTypeRaw == "freeTrial"` AND `chargeDate <= sevenDaysFromNow`.

- [ ] **Step 3: Build + visual check**

```bash
xcodebuild -project Subly.xcodeproj -scheme Subly -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Launch. Verify two states:
- With an ending trial present: TRIALS ENDING SOON section renders with FlagshipCard.
- Delete all trials: sleeping-fox card renders, SpendCard shows $0.00 / 0 subs · 0 trials.

- [ ] **Step 4: Commit, push, PR, merge**

```bash
git add Subly/HomeView.swift
git commit -m "feat(home): rebuild with H1 layout + spend card + sleeping fox empty state"
git push -u origin colehollander10/sub-pivot-p7-homeview
gh pr create --title "sub-pivot: Phase 7 — HomeView H1 layout" --body "Trials-forward + spend card + caught-\$X + sleeping-fox empty state."
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Phase 8 — StoreKit Bulk Import (Cursor delegation)

**Route:** Cursor, model `composer-2-fast`. Well-specified, StoreKit 2 is clean API.
**Branch:** Cursor worktree `colehollander10/sub-pivot-p8-storekit`
**Outcome:** "Import from Apple" flow in Settings + Onboarding.

### Task 8.1: Delegate to Cursor

- [ ] **Step 1: Run Cursor task**

```bash
/cursor:task Implement StoreKit bulk-import for Subly.

Files to create:

1. Subly/Import/ImportableSubscription.swift — a value type:
   struct ImportableSubscription: Identifiable, Equatable {
     let id: String  // product ID
     let displayName: String
     let amount: Decimal
     let billingCycle: BillingCycle  // from SubscriptionStore
     let nextBillingDate: Date?
   }

2. Subly/Import/StoreKitImport.swift — an actor with one public async method:
   `func fetchCurrentEntitlements() async throws -> [ImportableSubscription]`
   
   Implementation: iterate Transaction.currentEntitlements. For each verified transaction where productType == .autoRenewable, fetch the Product via Product.products(for: [transaction.productID]).first. Read product.displayName, product.price. Map product.subscription?.subscriptionPeriod.unit to BillingCycle (.day→treat as .weekly for now, .week→.weekly, .month→.monthly, .year→.yearly). Get next billing date from renewalInfo (may be nil).
   
   Skip unverified transactions silently. Skip any product whose subscriptionPeriod is nil.

3. Subly/Import/ImportConfirmationSheet.swift — SwiftUI sheet:
   - Title: "Import from Apple"
   - List of ImportableSubscription rows with a checkbox (default ON), each showing displayName / amount / billingCycle
   - Footer disclosure: "This imports subscriptions billed through Apple. For others, add manually or use Scan Screenshot (coming soon)."
   - Bottom: "Import X" primary button, grays out when no rows checked
   - On import: for each checked ImportableSubscription, create a Trial with entryType=.subscription, status=.active, serviceName=displayName, chargeAmount=amount, billingCycle=billingCycle, chargeDate=nextBillingDate ?? Date().addingTimeInterval(86400*30). Insert into ModelContext. Save.
   - Fox integration: during the import animation, show FoxView in header cycling state per row added: .happy each row, transitioning to .veryHappy on row counts 5/10/15.
   - On completion: "Imported X subscriptions" success row + fox held at .veryHappy for 2 seconds, then dismiss.
   - Empty list (no App Store subs): show centered message "No App Store subscriptions found" + a button "Add manually" that dismisses.

4. Modify Subly/SettingsView.swift — add a row "Import subscriptions" beneath existing settings rows that presents ImportConfirmationSheet when tapped. Trigger StoreKitImport.fetchCurrentEntitlements() before presenting; show a loading spinner for up to 3 seconds.

DO NOT:
- modify HomeView or TrialsView
- modify any file in Packages/
- add any backend call
- hardcode any prices

Acceptance:
- xcodebuild green on iPhone 16 Pro simulator
- Tapping "Import subscriptions" in Settings either presents the list or shows "No App Store subscriptions found" gracefully (simulator usually has none — that's expected)
- Unit test (Subly/Tests if exists, otherwise skip) for the BillingCycle mapping from Product.SubscriptionPeriod.Unit

Imports needed: SwiftUI, SwiftData, StoreKit, SubscriptionStore.

Min iOS: 15. Use StoreKit 2 API exclusively.
```

---

## Phase 9 — Tab Bar + SubscriptionsView + Phosphor icons (Cursor delegation)

**Route:** Cursor, model `composer-2-fast`. Well-specified structural change.
**Branch:** Cursor worktree `colehollander10/sub-pivot-p9-tabs`
**Outcome:** 4 tabs, Phosphor icons, SubscriptionsView list.

### Task 9.1: Delegate to Cursor

- [ ] **Step 1: Run Cursor task**

```bash
/cursor:task Expand Subly's tab bar from 3 to 4 tabs and add a SubscriptionsView.

Files to modify/create:

1. Subly/ContentView.swift — change the TabView from 3 tabs (Home/Trials/Settings) to 4 tabs in this order: Home / Trials / Subscriptions / Settings. Replace all tab-bar SF Symbols with Phosphor:
   - Home: Ph.houseSimple.regular (unselected) / Ph.houseSimple.fill (selected)
   - Trials: Ph.clock.regular / Ph.clock.fill
   - Subscriptions: Ph.repeat.regular / Ph.repeat.fill
   - Settings: Ph.gearSix.regular / Ph.gearSix.fill
   Icon size: 22pt. Use SublyTheme.accent for selected label/icon tint, SublyTheme.tertiaryText for unselected. Follow existing TabView structure; do not change the tab-bar background material.

2. Subly/SubscriptionsView.swift (NEW) — structure mirrors TrialsView.swift:
   - Header: "Subscriptions" title (SF Pro Rounded 28pt bold) + monthly total count subtitle
   - Query: @Query filter for entryTypeRaw == "subscription" AND statusRaw == "active", sorted by chargeDate ascending
   - Groupings: "CHARGING THIS WEEK" (chargeDate within 7 days), "THIS MONTH" (within 30), "LATER"
   - Row: CompactRow-style (match TrialsView.swift's row rendering) — logo, serviceName, "Renews {date}" line, amount
   - Tap row → detail sheet (simple view of the entry with editable fields + delete button). Detail sheet is minimal for v1 — no cancel-assist, no urgency ramp.
   - FAB: primary add button presenting AddSubscriptionSheet (from Phase 4). If Phase 4 hasn't merged when this runs, stub it as an empty sheet for now.
   - Rows: urgencyCalm color ramp by default; if chargeDate is within 2 days, use SublyTheme.accent as the highlight color (NOT the urgency ramp).

3. Subly/AddEntry/AddEntryRouterSheet.swift (NEW) — small mini-sheet for the Home FAB. Layout:
   - Two large pill buttons stacked: "Add Trial" / "Add Subscription"
   - Tapping a button dismisses this sheet and presents the corresponding Add sheet

4. Modify Subly/HomeView.swift — change the FAB to present AddEntryRouterSheet (instead of directly presenting AddTrialSheet). Keep existing FAB placement and styling.

DO NOT:
- modify any file in Packages/
- change any existing views outside the tab-bar wiring
- add SF Symbols anywhere (Phosphor only except for OS-expected chevron disclosures, which can stay SF)

Acceptance:
- xcodebuild green
- 4 tabs show up with Phosphor icons; selected tab tints lavender
- Subscriptions tab renders (empty list OK when no subscriptions exist)
- Home FAB opens a picker; Trials/Subscriptions tab FABs open their respective sheet directly

Imports needed: SwiftUI, SwiftData, SubscriptionStore, PhosphorSwift.
```

---

## Phase 10 — Integration, Codex Adversarial Review, Final QA (Opus inline)

**Route:** Opus inline for integration + fixes; Codex for adversarial review.
**Branch:** `colehollander10/sub-pivot-p10-integration`
**Outcome:** All phases merged into main, regressions fixed, PR ready for ship.

### Task 10.1: Run `code-review` across all changes

```bash
/code-review
```

Address CRITICAL and HIGH findings inline. Log MEDIUM for a follow-up ticket if extensive.

### Task 10.2: Run Codex adversarial review

```bash
/codex:adversarial-review subscription pivot: unified Trial model, migration safety, notification lifecycle correctness, fox placement consistency, cancel-assist flow happy-path and unknown-service fallback, StoreKit mapping from subscriptionPeriod.unit to BillingCycle
```

Review Codex findings manually. Do NOT auto-apply fixes. Decide per-finding; for those that apply, create small fix commits.

### Task 10.3: Run `superpowers:verification-before-completion`

Required before asserting Phase 10 done. Verifies:
- `xcodebuild` green (Debug + Release configurations)
- All package tests pass
- Manual smoke test: create trial → cancel-assist → "I canceled it" → proud fox → verify status flips
- Manual smoke test: create subscription → appears in SubscriptionsView, spend card updates
- Manual smoke test: "Import from Apple" in Settings either imports or shows empty state gracefully
- Regression check: existing trial flows (add, detect urgency, schedule notifications) still work

### Task 10.4: Final merge to main

Once all phase PRs are merged (Phases 1-9) and integration issues fixed, the main branch is ready. Tag the release.

```bash
git checkout main && git pull
git tag -a v1.1.0-subscription-pivot -m "Subscription pivot v1"
git push origin v1.1.0-subscription-pivot
```

### Task 10.5: Update Linear

Move all related Linear tickets (COL-### epic + sub-tickets) to Done. Attach the spec and plan paths in the epic description.

### Task 10.6: Update memory

Record any lessons learned (new feedback memories): what broke during migration, what Cursor got wrong (if anything), what the fox looked like after real visual work. These inform future sessions.

---

## Self-Review

### Spec coverage scan

| Spec section | Plan task(s) |
|---|---|
| Unified model + fields | Phase 1 Tasks 1.1–1.3 |
| SwiftData V1→V2 migration | Phase 1 Tasks 1.2–1.5 |
| Iconography rule (Phosphor everywhere) | Phase 9 Task 9.1 |
| 4-tab structure | Phase 9 Task 9.1 |
| HomeView H1 layout | Phase 7 Tasks 7.1–7.2 |
| Spend calculation | Phase 7 Task 7.1 |
| "Caught $X this month" | Phase 7 Task 7.1 |
| TrialsView adaptations | Phase 5 (cancel button wiring) |
| SubscriptionsView (new) | Phase 9 Task 9.1 |
| Cancel-assist flow + CancelGuides.json | Phase 5 Task 5.1 |
| Curated 15-service list | Phase 5 Task 5.1 |
| Proud fox celebration | Phase 6 Task 6.5 |
| NotificationEngine per-entry + type-aware + cleanup | Phase 2 Tasks 2.2–2.3 |
| TrialEngine generalization | Phase 2 Task 2.1 |
| FoxState + FoxView | Phase 6 Tasks 6.1–6.2 |
| Sleeping fox empty state | Phase 7 Task 7.2 |
| Settings curious fox | Phase 6 Task 6.4 |
| Onboarding happiness meter | Phase 8 Task 8.1 (integrated into ImportConfirmationSheet) |
| StoreKit "Import from Apple" | Phase 8 Task 8.1 |
| Add Trial sheet (cleaned) | Phase 3 Tasks 3.1–3.4 |
| Add Subscription sheet | Phase 4 Task 4.1 |
| Per-entry notification offset | Task 2.2 (engine) + detail sheets (deferred polish in Phase 10) |
| Trial → subscription entryType flip | Implicit via the mutable `entryType` field; no explicit UI affordance in v1 (spec defers the guided conversion flow) |

**Gaps noted during self-review:**

1. **"Remind me X days before" picker UI in entry detail sheets** — spec calls for a per-entry `notificationOffset` picker. Not explicitly scheduled as a task. Add as **Phase 2.5** polish after engine support lands, OR punt to v1.1 if time-boxed. Punting is acceptable because `notificationOffset: nil` falls back to sensible defaults.
2. **Fox naming (commit to "Finn" before App Store submission)** — not a plan task per se; it's a marketing/branding step. Track in Linear, not in code.

### Placeholder scan

No "TBD", "TODO", or "handle edge cases" without concrete code. All Cursor prompts are self-contained and specify exact files, fields, and acceptance criteria.

### Type consistency

- `Trial.entryType` is an `EntryType` enum (computed property over `entryTypeRaw: String`). ✅ used consistently.
- `Trial.status` is `EntryStatus` (computed over `statusRaw`). ✅
- `Trial.billingCycle` is `BillingCycle?` (computed over `billingCycleRaw: String?`). ✅
- `TrialEngine.plan` param is `chargeDate` in Phase 2 Task 2.1; HomeView and TrialsView update to use `t.chargeDate` in Phase 2 Task 2.4. ✅
- `PlannedTrialAlert.Kind.subscriptionDayBefore` added in Phase 2 Task 2.1; used by caller (app layer scheduling path, Phase 2 Task 2.4 or Phase 10 integration). ✅
- `NotificationEngine.removePending(ids:)` called by CancelAssistSheet in Phase 5; signature matches Phase 2 Task 2.2. ✅

No type drift across tasks.

### Scope check

10 phases, each producing a working mergeable PR. Phases 4, 5, 8, 9 are Cursor-delegated and can run in parallel with Opus-inline phases. Build order dependencies:
- Phase 1 blocks everything (model is foundational)
- Phase 2 blocks Phase 5 (cancel-assist needs NotificationEngine.removePending)
- Phase 3 blocks Phase 4 (AddSubscriptionSheet reuses extracted components)
- Phases 4 & 5 are parallel
- Phase 6 blocks Phase 7 (empty-state needs FoxView) and Phase 8 (onboarding fox)
- Phases 8 & 9 are parallel after Phases 1–7

This plan is big but not too big for one spec — the pieces are tightly interlinked. Keep it as one plan with phased PRs.
