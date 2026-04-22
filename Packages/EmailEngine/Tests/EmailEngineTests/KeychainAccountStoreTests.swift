import Foundation
import Testing
@testable import EmailEngine

/// Uses a unique service namespace per test so CI runs don't collide with
/// each other or with the real app's keychain entry.
private func makeStore() -> KeychainAccountStore {
    let namespace = "com.subly.emailengine.tests.\(UUID().uuidString)"
    return KeychainAccountStore(service: namespace)
}

private func account(_ userID: String, _ email: String, _ refresh: String) -> GoogleAccount {
    GoogleAccount(userID: userID, email: email, refreshToken: refresh)
}

@Suite("KeychainAccountStore")
struct KeychainAccountStoreTests {

    @Test("listAll returns empty on a fresh store")
    func listAllEmpty() {
        let store = makeStore()
        #expect(store.listAll().isEmpty)
    }

    @Test("upsert persists a single account")
    func upsertSingle() throws {
        let store = makeStore()
        defer { store.removeAll() }

        try store.upsert(account("u1", "a@x.com", "refresh-1"))

        let all = store.listAll()
        #expect(all.count == 1)
        #expect(all.first?.userID == "u1")
        #expect(all.first?.refreshToken == "refresh-1")
    }

    @Test("upsert appends distinct accounts in insertion order")
    func upsertMultipleOrder() throws {
        let store = makeStore()
        defer { store.removeAll() }

        try store.upsert(account("u1", "a@x.com", "r1"))
        try store.upsert(account("u2", "b@x.com", "r2"))
        try store.upsert(account("u3", "c@x.com", "r3"))

        let ids = store.listAll().map(\.userID)
        #expect(ids == ["u1", "u2", "u3"])
    }

    @Test("upsert replaces existing account with same userID")
    func upsertReplacesExisting() throws {
        let store = makeStore()
        defer { store.removeAll() }

        try store.upsert(account("u1", "a@x.com", "old-refresh"))
        try store.upsert(account("u1", "a@x.com", "new-refresh"))

        let all = store.listAll()
        #expect(all.count == 1)
        #expect(all.first?.refreshToken == "new-refresh")
    }

    @Test("find returns account by userID, nil when absent")
    func findByUserID() throws {
        let store = makeStore()
        defer { store.removeAll() }

        try store.upsert(account("u1", "a@x.com", "r1"))
        try store.upsert(account("u2", "b@x.com", "r2"))

        #expect(store.find(userID: "u2")?.email == "b@x.com")
        #expect(store.find(userID: "missing") == nil)
    }

    @Test("remove deletes only the target userID")
    func removeSingle() throws {
        let store = makeStore()
        defer { store.removeAll() }

        try store.upsert(account("u1", "a@x.com", "r1"))
        try store.upsert(account("u2", "b@x.com", "r2"))
        store.remove(userID: "u1")

        let ids = store.listAll().map(\.userID)
        #expect(ids == ["u2"])
    }

    @Test("removeAll clears every account")
    func removeAllClears() throws {
        let store = makeStore()

        try store.upsert(account("u1", "a@x.com", "r1"))
        try store.upsert(account("u2", "b@x.com", "r2"))
        store.removeAll()

        #expect(store.listAll().isEmpty)
    }

    @Test("two stores with different services do not share state")
    func serviceNamespaceIsolation() throws {
        let storeA = KeychainAccountStore(service: "com.subly.emailengine.tests.A.\(UUID().uuidString)")
        let storeB = KeychainAccountStore(service: "com.subly.emailengine.tests.B.\(UUID().uuidString)")
        defer {
            storeA.removeAll()
            storeB.removeAll()
        }

        try storeA.upsert(account("u1", "a@x.com", "ra"))

        #expect(storeA.listAll().count == 1)
        #expect(storeB.listAll().isEmpty)
    }

    @Test("data round-trips through JSON encoding in Keychain")
    func dataRoundTrip() throws {
        let store = makeStore()
        defer { store.removeAll() }

        let original = account("u1", "cole@example.com", "1//0g-complex-refresh_token-with.chars+=")
        try store.upsert(original)

        let fetched = store.find(userID: "u1")
        #expect(fetched == original)
    }
}
