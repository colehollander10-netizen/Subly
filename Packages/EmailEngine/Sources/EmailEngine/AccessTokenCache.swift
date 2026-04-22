import Foundation

/// Thread-safe in-memory cache of short-lived Gmail access tokens, keyed by
/// account ID. Tokens within 60s of expiry are treated as stale to avoid
/// racing a 401 on the next request.
///
/// `internal` so the test target can inject a deterministic clock.
final class AccessTokenCache: @unchecked Sendable {
    private struct Entry {
        let token: String
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let lock = NSLock()
    private let now: @Sendable () -> Date
    private let stalenessWindow: TimeInterval

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        stalenessWindow: TimeInterval = 60
    ) {
        self.now = now
        self.stalenessWindow = stalenessWindow
    }

    func get(accountID: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[accountID] else { return nil }
        if entry.expiresAt.timeIntervalSince(now()) < stalenessWindow {
            entries[accountID] = nil
            return nil
        }
        return entry.token
    }

    func set(accountID: String, token: String, ttl: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        entries[accountID] = Entry(token: token, expiresAt: now().addingTimeInterval(ttl))
    }

    func invalidate(accountID: String) {
        lock.lock(); defer { lock.unlock() }
        entries[accountID] = nil
    }

    func invalidateAll() {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll()
    }
}
