import Foundation
import SubscriptionStore

struct ImportableSubscription: Identifiable, Equatable {
    let id: String
    let displayName: String
    let amount: Decimal
    let billingCycle: BillingCycle
    let nextBillingDate: Date?
    let appleOriginalTransactionID: String?
}

/// Reasons a StoreKit transaction was not turned into an importable
/// subscription. Tracked so the UI can show "Skipped N" and OSLog can show
/// concrete causes — previously every skip was silent, which made auto-import
/// look broken whenever a single product lookup hiccuped.
enum ImportSkipReason: Equatable {
    case revoked
    case nonAutoRenewable
    case productLookupFailed(String)
    case missingSubscriptionPeriod

    var userFacingMessage: String {
        switch self {
        case .revoked:
            return "Subscription was revoked"
        case .nonAutoRenewable:
            return "Not an auto-renewable subscription"
        case .productLookupFailed(let detail):
            return "Apple lookup failed: \(detail)"
        case .missingSubscriptionPeriod:
            return "Apple did not return a billing period"
        }
    }
}

/// Per-transaction outcome. Keeps the skipped count addressable in UI and
/// gives `AutoImportService` something more useful than `nil` to work with.
struct ImportOutcome: Equatable {
    let productID: String
    let originalTransactionID: String
    let result: Result

    enum Result: Equatable {
        case importable(ImportableSubscription)
        case skipped(ImportSkipReason)
    }
}

/// Aggregated result of one full sync pass. Surfaced into Settings so the
/// "Sync now" row can show concrete numbers + the most recent failure mode
/// instead of a silent timestamp that bumps even on partial failure.
struct ImportSummary: Equatable {
    var inserted: Int
    var updated: Int
    var skipped: [SkippedItem]
    var saveError: String?
    var fetchError: String?
    var completedAt: Date

    init(
        inserted: Int = 0,
        updated: Int = 0,
        skipped: [SkippedItem] = [],
        saveError: String? = nil,
        fetchError: String? = nil,
        completedAt: Date = Date()
    ) {
        self.inserted = inserted
        self.updated = updated
        self.skipped = skipped
        self.saveError = saveError
        self.fetchError = fetchError
        self.completedAt = completedAt
    }

    struct SkippedItem: Equatable {
        let productID: String
        let reason: String
    }

    var didSucceed: Bool {
        saveError == nil && fetchError == nil
    }

    var totalProcessed: Int { inserted + updated }
}
