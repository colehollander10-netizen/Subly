import Foundation
import Testing
@testable import EmailEngine

/// Tracks how many times `refresh` is invoked and lets tests gate the
/// resolution so we can land multiple awaiters on the same in-flight call.
private struct Boom: Error {}

private final class RefreshSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private var _callsPerAccount: [String: Int] = [:]

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    func calls(for accountID: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return _callsPerAccount[accountID] ?? 0
    }

    func record(_ accountID: String) {
        lock.lock(); defer { lock.unlock() }
        _callCount += 1
        _callsPerAccount[accountID, default: 0] += 1
    }
}

@Suite("RefreshTokenCoordinator")
struct RefreshTokenCoordinatorTests {

    @Test("single caller triggers exactly one refresh")
    func singleCaller() async throws {
        let coordinator = RefreshTokenCoordinator()
        let spy = RefreshSpy()

        let token = try await coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "tok-\(id)"
        }

        #expect(token == "tok-u1")
        #expect(spy.callCount == 1)
    }

    @Test("concurrent callers for the same account share a single refresh")
    func concurrentSameAccountCoalesces() async throws {
        let coordinator = RefreshTokenCoordinator()
        let spy = RefreshSpy()

        // Latch the refresh so many awaiters pile up before it resolves.
        let latch = AsyncLatch()

        async let a = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            await latch.wait()
            return "tok-\(id)"
        }
        async let b = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "SHOULD-NOT-RUN-\(id)"
        }
        async let c = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "SHOULD-NOT-RUN-\(id)"
        }

        // Give the sibling tasks a chance to enqueue on the in-flight Task.
        try await Task.sleep(for: .milliseconds(50))
        await latch.release()

        let (ra, rb, rc) = try await (a, b, c)

        #expect(ra == "tok-u1")
        #expect(rb == "tok-u1")
        #expect(rc == "tok-u1")
        #expect(spy.calls(for: "u1") == 1)
    }

    @Test("different accounts refresh independently in parallel")
    func differentAccountsIndependent() async throws {
        let coordinator = RefreshTokenCoordinator()
        let spy = RefreshSpy()

        async let a = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "tok-\(id)"
        }
        async let b = coordinator.freshToken(for: "u2") { id in
            spy.record(id)
            return "tok-\(id)"
        }

        let (ra, rb) = try await (a, b)

        #expect(ra == "tok-u1")
        #expect(rb == "tok-u2")
        #expect(spy.calls(for: "u1") == 1)
        #expect(spy.calls(for: "u2") == 1)
    }

    @Test("after a refresh completes, a later call triggers a new refresh")
    func sequentialCallsEachRefresh() async throws {
        let coordinator = RefreshTokenCoordinator()
        let spy = RefreshSpy()

        _ = try await coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "tok-1"
        }
        _ = try await coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "tok-2"
        }

        // Both callers saw a completed task clear the slot, so both ran.
        #expect(spy.calls(for: "u1") == 2)
    }

    @Test("thrown error propagates to all waiters and the slot clears")
    func errorPropagatesAndSlotClears() async throws {
        let coordinator = RefreshTokenCoordinator()
        let spy = RefreshSpy()

        let latch = AsyncLatch()

        async let a: String = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            await latch.wait()
            throw Boom()
        }
        async let b: String = coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "never"
        }

        try await Task.sleep(for: .milliseconds(50))
        await latch.release()

        var aError: Error?
        var bError: Error?
        var aValue: String?
        var bValue: String?
        do { aValue = try await a } catch { aError = error }
        do { bValue = try await b } catch { bError = error }

        #expect(aError is Boom, "a got value=\(aValue ?? "nil") error=\(String(describing: aError))")
        #expect(bError is Boom, "b got value=\(bValue ?? "nil") error=\(String(describing: bError))")
        #expect(spy.calls(for: "u1") == 1)

        // Slot should be empty now — a later call triggers a fresh refresh.
        let token = try await coordinator.freshToken(for: "u1") { id in
            spy.record(id)
            return "tok-after-error"
        }
        #expect(token == "tok-after-error")
        #expect(spy.calls(for: "u1") == 2)
    }
}

/// Minimal async latch — a single-shot gate. `wait()` suspends until `release()`
/// is called; subsequent waiters pass through immediately.
private actor AsyncLatch {
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        released = true
        for w in waiters { w.resume() }
        waiters.removeAll()
    }
}
