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
        XCTAssertEqual(BillingCycle.yearly.monthlyMultiplier, 1.0 / 12.0, accuracy: 0.0001)
        XCTAssertEqual(BillingCycle.weekly.monthlyMultiplier, 4.33, accuracy: 0.001)
        XCTAssertEqual(BillingCycle.custom.monthlyMultiplier, 1.0, accuracy: 0.0001)
    }
}
