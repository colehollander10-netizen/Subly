import Foundation
import Testing
@testable import EmailEngine

/// Mutable clock the cache can read from. Lets tests advance time without
/// sleeping and without racing a real wall clock.
private final class FakeClock: @unchecked Sendable {
    private var current: Date
    private let lock = NSLock()

    init(_ start: Date = Date(timeIntervalSince1970: 1_000_000_000)) {
        self.current = start
    }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}

private func makeCache(stalenessWindow: TimeInterval = 60) -> (AccessTokenCache, FakeClock) {
    let clock = FakeClock()
    let cache = AccessTokenCache(now: { clock.now }, stalenessWindow: stalenessWindow)
    return (cache, clock)
}

@Suite("AccessTokenCache")
struct AccessTokenCacheTests {

    @Test("get returns nil for unknown accountID")
    func getUnknown() {
        let (cache, _) = makeCache()
        #expect(cache.get(accountID: "nope") == nil)
    }

    @Test("set then get returns the token while fresh")
    func setAndGet() {
        let (cache, _) = makeCache()
        cache.set(accountID: "u1", token: "tok-1", ttl: 3600)
        #expect(cache.get(accountID: "u1") == "tok-1")
    }

    @Test("token within staleness window is treated stale and evicted")
    func tokenNearExpiryIsStale() {
        let (cache, clock) = makeCache(stalenessWindow: 60)
        cache.set(accountID: "u1", token: "tok-1", ttl: 100)
        // 41s elapsed → expires in 59s → inside the 60s staleness window.
        clock.advance(41)

        #expect(cache.get(accountID: "u1") == nil)
        // Second call confirms eviction — no stale entry lingers.
        #expect(cache.get(accountID: "u1") == nil)
    }

    @Test("token outside staleness window is returned")
    func tokenOutsideStalenessFresh() {
        let (cache, clock) = makeCache(stalenessWindow: 60)
        cache.set(accountID: "u1", token: "tok-1", ttl: 3600)
        clock.advance(3000) // 600s remaining > 60s window

        #expect(cache.get(accountID: "u1") == "tok-1")
    }

    @Test("set overwrites an existing token + expiry for the same accountID")
    func setOverwrites() {
        let (cache, clock) = makeCache()
        cache.set(accountID: "u1", token: "old", ttl: 100)
        clock.advance(50)
        cache.set(accountID: "u1", token: "new", ttl: 3600)

        #expect(cache.get(accountID: "u1") == "new")
    }

    @Test("invalidate drops one account but leaves others")
    func invalidateOne() {
        let (cache, _) = makeCache()
        cache.set(accountID: "u1", token: "t1", ttl: 3600)
        cache.set(accountID: "u2", token: "t2", ttl: 3600)

        cache.invalidate(accountID: "u1")

        #expect(cache.get(accountID: "u1") == nil)
        #expect(cache.get(accountID: "u2") == "t2")
    }

    @Test("invalidateAll clears every entry")
    func invalidateAllClears() {
        let (cache, _) = makeCache()
        cache.set(accountID: "u1", token: "t1", ttl: 3600)
        cache.set(accountID: "u2", token: "t2", ttl: 3600)

        cache.invalidateAll()

        #expect(cache.get(accountID: "u1") == nil)
        #expect(cache.get(accountID: "u2") == nil)
    }

    @Test("concurrent access does not crash or corrupt entries")
    func concurrentAccessIsSafe() async {
        let (cache, _) = makeCache()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let id = "u\(i % 10)"
                    cache.set(accountID: id, token: "tok-\(i)", ttl: 3600)
                    _ = cache.get(accountID: id)
                    if i % 7 == 0 { cache.invalidate(accountID: id) }
                }
            }
        }

        // All 10 IDs either hold a value or are nil — no crash, no partial state.
        for i in 0..<10 {
            let value = cache.get(accountID: "u\(i)")
            if let value {
                #expect(value.hasPrefix("tok-"))
            }
        }
    }
}
