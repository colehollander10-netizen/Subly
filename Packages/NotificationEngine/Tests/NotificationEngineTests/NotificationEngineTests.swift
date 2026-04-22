import Foundation
import Testing
import UserNotifications
@testable import NotificationEngine

/// Records every interaction with UNUserNotificationCenter so tests can assert
/// exactly what requests the engine produced, without ever hitting a real
/// notification center or prompting the user.
///
/// State is serialized through a dispatch queue so reads are safe from both
/// sync (e.g. `removeAllPendingNotificationRequests`) and async methods.
private final class SpyCenter: NotificationCenterProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "SpyCenter")
    private var _added: [UNNotificationRequest] = []
    private var _removedAllCalls = 0
    private var _authRequested = false

    var added: [UNNotificationRequest] {
        queue.sync { _added }
    }
    var removedAllCalls: Int {
        queue.sync { _removedAllCalls }
    }
    var authRequested: Bool {
        queue.sync { _authRequested }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        queue.sync { _authRequested = true }
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        queue.sync { _added.append(request) }
    }

    func removeAllPendingNotificationRequests() {
        queue.sync { _removedAllCalls += 1 }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        queue.sync { _added }
    }
}

@Suite("NotificationEngine")
struct NotificationEngineTests {

    @Test("scheduleAll clears pending then adds each future alert")
    func scheduleAllHappyPath() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let now = Date()
        let a = ScheduledAlert(
            id: "a",
            title: "A",
            body: "first",
            triggerDate: now.addingTimeInterval(60)
        )
        let b = ScheduledAlert(
            id: "b",
            title: "B",
            body: "second",
            triggerDate: now.addingTimeInterval(120)
        )

        await engine.scheduleAll([a, b], now: now)

        #expect(spy.removedAllCalls == 1)
        #expect(spy.added.count == 2)
        #expect(spy.added.map(\.identifier).sorted() == ["a", "b"])
        let contents = spy.added.map { ($0.content.title, $0.content.body) }
        #expect(contents.contains(where: { $0.0 == "A" && $0.1 == "first" }))
        #expect(contents.contains(where: { $0.0 == "B" && $0.1 == "second" }))
    }

    @Test("scheduleAll drops alerts whose triggerDate has already passed")
    func dropsPastAlerts() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let now = Date()
        let past = ScheduledAlert(
            id: "past",
            title: "Past",
            body: "x",
            triggerDate: now.addingTimeInterval(-60)
        )
        let future = ScheduledAlert(
            id: "future",
            title: "Future",
            body: "y",
            triggerDate: now.addingTimeInterval(60)
        )

        await engine.scheduleAll([past, future], now: now)

        #expect(spy.added.map(\.identifier) == ["future"])
    }

    @Test("scheduleAll with empty list still clears pending")
    func emptyStillClears() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        await engine.scheduleAll([], now: Date())

        #expect(spy.removedAllCalls == 1)
        #expect(spy.added.isEmpty)
    }

    @Test("every request is a non-repeating calendar trigger at minute granularity")
    func triggerShape() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let when = Calendar.current.date(from: DateComponents(
            year: 2026, month: 5, day: 10, hour: 9, minute: 0
        ))!
        let alert = ScheduledAlert(
            id: "a", title: "T", body: "B", triggerDate: when
        )
        await engine.scheduleAll([alert], now: when.addingTimeInterval(-3600))

        let request = try! #require(spy.added.first)
        let trigger = try! #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        let components = trigger.dateComponents
        #expect(components.year == 2026)
        #expect(components.month == 5)
        #expect(components.day == 10)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test("sound is set to default on every request")
    func soundIsDefault() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let alert = ScheduledAlert(
            id: "a", title: "T", body: "B",
            triggerDate: Date().addingTimeInterval(60)
        )
        await engine.scheduleAll([alert])

        let request = try! #require(spy.added.first)
        #expect(request.content.sound == .default)
    }

    @Test("stable identifiers enable replace semantics across calls")
    func identifiersAreStableAcrossCalls() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let future = Date().addingTimeInterval(60)
        let first = ScheduledAlert(id: "stable-id", title: "v1", body: "v1", triggerDate: future)
        let second = ScheduledAlert(id: "stable-id", title: "v2", body: "v2", triggerDate: future)

        await engine.scheduleAll([first])
        await engine.scheduleAll([second])

        #expect(spy.removedAllCalls == 2)
        // Last pass overrides: spy's add-log now has both (we don't model
        // OS-side replace), but the engine's contract is that stable IDs let
        // the OS do the replace. Proven by both being added under "stable-id".
        #expect(spy.added.count == 2)
        #expect(spy.added.allSatisfy { $0.identifier == "stable-id" })
        #expect(spy.added.last?.content.title == "v2")
    }

    @Test("requestAuthorization returns the center's result")
    func authorizationPath() async {
        let spy = SpyCenter()
        let engine = NotificationEngine(center: spy)

        let granted = await engine.requestAuthorization()

        #expect(granted == true)
        #expect(spy.authRequested)
    }
}
