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

    func testTrialPlanSchedulesAlertsAtNineLocalTime() throws {
        let id = UUID()
        let calendar = boiseCalendar()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 10,
            hour: 12
        )))
        let charge = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 20,
            hour: 16,
            minute: 45
        )))

        let alerts = TrialEngine.plan(trialID: id, chargeDate: charge, now: now, calendar: calendar)

        XCTAssertEqual(alerts.map(\.kind), [.threeDaysBefore, .dayBefore, .dayOf])
        XCTAssertTrue(alerts.allSatisfy { isNineAM($0.triggerDate, calendar: calendar) })
    }

    func testSubscriptionPlanSchedulesDayBeforeAtNineLocalTime() throws {
        let id = UUID()
        let calendar = boiseCalendar()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 10,
            hour: 12
        )))
        let charge = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 20,
            hour: 16,
            minute: 45
        )))

        let alerts = TrialEngine.planSubscription(entryID: id, chargeDate: charge, now: now, calendar: calendar)

        XCTAssertEqual(alerts.map(\.kind), [.subscriptionDayBefore])
        XCTAssertTrue(alerts.allSatisfy { isNineAM($0.triggerDate, calendar: calendar) })
    }

    private func boiseCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        return calendar
    }

    private func isNineAM(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return components.hour == 9
            && components.minute == 0
            && components.second == 0
    }
}
