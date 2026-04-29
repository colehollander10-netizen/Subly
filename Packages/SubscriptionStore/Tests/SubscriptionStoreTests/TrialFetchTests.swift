import XCTest
import SwiftData
@testable import SubscriptionStore

final class TrialFetchTests: XCTestCase {
    func testCancellingFreeTrialStampsCancelledAtWhenMissing() {
        let trial = Trial(
            serviceName: "Spotify",
            chargeDate: Date().addingTimeInterval(86400 * 7),
            chargeAmount: 9.99,
            entryType: .freeTrial,
            status: .active
        )

        trial.status = .cancelled

        XCTAssertEqual(trial.status, .cancelled)
        XCTAssertNotNil(trial.cancelledAt)
    }

    func testCancellingFreeTrialPreservesExistingCancelledAt() {
        let cancelledAt = Date().addingTimeInterval(-86400)
        let trial = Trial(
            serviceName: "Spotify",
            chargeDate: Date().addingTimeInterval(86400 * 7),
            chargeAmount: 9.99,
            entryType: .freeTrial,
            status: .active,
            cancelledAt: cancelledAt
        )

        trial.status = .cancelled

        XCTAssertEqual(trial.status, .cancelled)
        XCTAssertEqual(trial.cancelledAt, cancelledAt)
    }

    func testEntryTypeFlipMovesTrialBetweenTrialAndSubscriptionFetches() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let trial = Trial(
            serviceName: "Netflix",
            chargeDate: Date().addingTimeInterval(86400 * 14),
            chargeAmount: 15.49,
            entryType: .freeTrial,
            status: .active
        )
        context.insert(trial)
        try context.save()

        trial.entryType = .subscription
        trial.billingCycle = .monthly
        try context.save()

        let subscriptions = try context.fetch(FetchDescriptor<Trial>(
            predicate: #Predicate<Trial> {
                $0.entryTypeRaw == "subscription" && $0.statusRaw == "active"
            }
        ))
        let trials = try context.fetch(FetchDescriptor<Trial>(
            predicate: #Predicate<Trial> {
                $0.entryTypeRaw == "freeTrial" && $0.statusRaw == "active"
            }
        ))

        XCTAssertEqual(subscriptions.map(\.id), [trial.id])
        XCTAssertTrue(trials.isEmpty)
    }

    func testActiveFreeTrialFetchPredicateReturnsOnlyMatchingRows() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let activeTrial = Trial(
            serviceName: "Spotify",
            chargeDate: Date().addingTimeInterval(86400 * 7),
            chargeAmount: 9.99,
            entryType: .freeTrial,
            status: .active
        )
        let activeSubscription = Trial(
            serviceName: "YouTube Premium",
            chargeDate: Date().addingTimeInterval(86400 * 30),
            chargeAmount: 18.99,
            entryType: .subscription,
            status: .active,
            billingCycle: .monthly
        )
        let cancelledTrial = Trial(
            serviceName: "Notion",
            chargeDate: Date().addingTimeInterval(86400 * 5),
            chargeAmount: 7.99,
            entryType: .freeTrial,
            status: .cancelled
        )

        context.insert(activeTrial)
        context.insert(activeSubscription)
        context.insert(cancelledTrial)
        try context.save()

        let matches = try context.fetch(FetchDescriptor<Trial>(
            predicate: #Predicate<Trial> {
                $0.entryTypeRaw == "freeTrial" && $0.statusRaw == "active"
            }
        ))

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, activeTrial.id)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Trial.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
