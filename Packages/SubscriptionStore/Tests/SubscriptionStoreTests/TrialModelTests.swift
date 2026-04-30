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

    @MainActor
    func testUpsertAppleSubscriptionTwiceWithSameOriginalIDUpdatesExistingRow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstDate = Date().addingTimeInterval(86400 * 30)
        let secondDate = Date().addingTimeInterval(86400 * 60)

        let firstResult = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-123",
            serviceName: "Netflix",
            chargeDate: firstDate,
            chargeAmount: 9.99,
            billingCycle: .monthly,
            in: context
        )
        XCTAssertTrue(firstResult.inserted)

        let secondResult = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-123",
            serviceName: "Netflix",
            chargeDate: secondDate,
            chargeAmount: 19.99,
            billingCycle: .monthly,
            status: .cancelled,
            in: context
        )
        XCTAssertFalse(secondResult.inserted)

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(trials.count, 1)
        XCTAssertEqual(trials[0].appleOriginalTransactionID, "orig-123")
        XCTAssertEqual(trials[0].chargeDate, secondDate)
        XCTAssertEqual(trials[0].chargeAmount, 19.99)
        XCTAssertEqual(trials[0].status, .cancelled)
    }

    @MainActor
    func testUpsertAppleSubscriptionRefreshesNameAndBillingCycleOnExistingRow() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-789",
            serviceName: "Old Name",
            chargeDate: Date().addingTimeInterval(86400 * 30),
            chargeAmount: 9.99,
            billingCycle: .monthly,
            in: context
        )

        let secondResult = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-789",
            serviceName: "Renamed Service",
            chargeDate: Date().addingTimeInterval(86400 * 365),
            chargeAmount: 99.99,
            billingCycle: .yearly,
            in: context
        )
        XCTAssertFalse(secondResult.inserted)

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(trials.count, 1)
        XCTAssertEqual(trials[0].serviceName, "Renamed Service")
        XCTAssertEqual(trials[0].billingCycle, .yearly)
        XCTAssertEqual(trials[0].chargeAmount, 99.99)
        XCTAssertEqual(trials[0].entryType, .subscription)
    }

    @MainActor
    func testUpsertAppleSubscriptionEmptyServiceNameDoesNotOverwriteExisting() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-empty",
            serviceName: "Curated Name",
            chargeDate: Date().addingTimeInterval(86400 * 30),
            chargeAmount: 4.99,
            billingCycle: .monthly,
            in: context
        )

        _ = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-empty",
            serviceName: "",
            chargeDate: Date().addingTimeInterval(86400 * 60),
            chargeAmount: 4.99,
            billingCycle: .monthly,
            in: context
        )

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(trials.count, 1)
        XCTAssertEqual(trials[0].serviceName, "Curated Name")
    }

    @MainActor
    func testUpsertAppleSubscriptionWithDifferentOriginalIDsInsertsTwoRows() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-123",
            serviceName: "Netflix",
            chargeDate: Date().addingTimeInterval(86400 * 30),
            chargeAmount: 9.99,
            billingCycle: .monthly,
            in: context
        )
        _ = try Trial.upsertAppleSubscription(
            originalTransactionID: "orig-456",
            serviceName: "Spotify",
            chargeDate: Date().addingTimeInterval(86400 * 14),
            chargeAmount: 10.99,
            billingCycle: .monthly,
            in: context
        )

        let trials = try context.fetch(FetchDescriptor<Trial>())
        XCTAssertEqual(trials.count, 2)
        XCTAssertEqual(
            trials.compactMap(\.appleOriginalTransactionID).sorted(),
            ["orig-123", "orig-456"]
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Trial.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
