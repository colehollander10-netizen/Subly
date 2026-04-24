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

    func testTrialPlanDoesNotUseSubscriptionAlertShape() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let charge = now.addingTimeInterval(86400 * 10)
        let alerts = TrialEngine.plan(
            trialID: id,
            chargeDate: charge,
            now: now,
            calendar: .init(identifier: .gregorian)
        )

        XCTAssertEqual(alerts.map(\.kind), [.threeDaysBefore, .dayBefore, .dayOf])
        XCTAssertFalse(alerts.map(\.kind).contains(.subscriptionDayBefore))
    }
}
