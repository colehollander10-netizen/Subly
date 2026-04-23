import XCTest
import SwiftData
@testable import SubscriptionStore

final class TrialModelTests: XCTestCase {
    func testDefaultsAreTrialAndActive() {
        let t = Trial(
            serviceName: "Spotify",
            chargeDate: Date().addingTimeInterval(86400 * 7),
            chargeAmount: 9.99
        )
        XCTAssertEqual(t.entryType, .freeTrial)
        XCTAssertEqual(t.status, .active)
        XCTAssertNil(t.billingCycle)
        XCTAssertNil(t.notificationOffset)
        XCTAssertNil(t.cancelledAt)
    }

    func testSubscriptionInitRequiresBillingCycle() {
        let t = Trial(
            serviceName: "Netflix",
            chargeDate: Date().addingTimeInterval(86400 * 30),
            chargeAmount: 15.49,
            entryType: .subscription,
            billingCycle: .monthly
        )
        XCTAssertEqual(t.entryType, .subscription)
        XCTAssertEqual(t.billingCycle, .monthly)
    }

    func testStatusTransitionsViaComputedProperty() {
        let t = Trial(
            serviceName: "Test",
            chargeDate: Date().addingTimeInterval(86400),
            chargeAmount: 5.00
        )
        t.status = .cancelled
        XCTAssertEqual(t.statusRaw, "cancelled")
        XCTAssertEqual(t.status, .cancelled)
    }
}
