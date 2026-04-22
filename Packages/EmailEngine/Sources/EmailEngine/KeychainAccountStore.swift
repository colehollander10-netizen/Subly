import Foundation
import Security

/// Stores connected accounts as a single Keychain-backed JSON blob keyed by
/// `accountsList`. Simpler than one item per account and easier to keep in
/// order for the UI.
///
/// `internal` so the test target can exercise it with an isolated service
/// namespace.
///
/// `@unchecked Sendable` is safe because every mutating operation goes
/// through Security framework calls that the OS synchronizes, and no
/// mutable Swift state is held between calls.
final class KeychainAccountStore: @unchecked Sendable {
    private let service: String
    private let accountListKey: String

    init(
        service: String = "com.subly.emailengine",
        accountListKey: String = "connected_accounts_v2"
    ) {
        self.service = service
        self.accountListKey = accountListKey
    }

    func listAll() -> [GoogleAccount] {
        guard let data = read() else { return [] }
        return (try? JSONDecoder().decode([GoogleAccount].self, from: data)) ?? []
    }

    func find(userID: String) -> GoogleAccount? {
        listAll().first(where: { $0.userID == userID })
    }

    func upsert(_ account: GoogleAccount) throws {
        var current = listAll()
        current.removeAll { $0.userID == account.userID }
        current.append(account)
        try write(current)
    }

    func remove(userID: String) {
        var current = listAll()
        current.removeAll { $0.userID == userID }
        try? write(current)
    }

    func removeAll() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountListKey,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func read() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountListKey,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func write(_ accounts: [GoogleAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        removeAll()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountListKey,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw EmailEngineError.keychainError(status)
        }
    }
}
