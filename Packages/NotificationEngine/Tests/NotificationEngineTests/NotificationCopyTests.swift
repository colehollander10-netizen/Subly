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
