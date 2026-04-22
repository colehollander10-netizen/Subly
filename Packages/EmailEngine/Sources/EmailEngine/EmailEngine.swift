import Foundation

#if canImport(UIKit)
import EmailParsingCore
import GoogleSignIn
import Security
import UIKit

// MARK: - Public API

/// Gmail-backed email engine with true multi-account support.
///
/// Sign-in still uses `GIDSignIn` (presents the Google web sheet, handles
/// consent), but we capture each account's long-lived `refreshToken` at
/// sign-in and store it in the Keychain. Every subsequent Gmail fetch mints
/// its own access token directly from `oauth2.googleapis.com/token`, so the
/// SDK's single `currentUser` slot never gets in the way of scanning
/// multiple accounts in the same session.
public final class EmailEngine: @unchecked Sendable {
    public static let shared = EmailEngine()

    private let keychain = KeychainAccountStore()
    private let tokenCache = AccessTokenCache()
    private let refreshCoordinator = RefreshTokenCoordinator()
    private var clientID: String = ""

    private init() {}

    /// Configure GIDSignIn. Call from SublyApp before any sign-in attempt.
    public func configure(clientID: String) {
        self.clientID = clientID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    /// Handle the OAuth redirect URL. Call from SublyApp's onOpenURL modifier.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// No-op for multi-account — we restore per-account from Keychain on demand.
    /// Kept for call-site compatibility.
    public func restorePreviousSignIn() async throws {
        _ = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    /// Present the Google sign-in flow. Returns the newly-connected account.
    /// Safe to call multiple times — each call appends a new account.
    public func signInAndAdd(presenting viewController: UIViewController) async throws -> GoogleAccount {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: [GmailScope.readonly]
        )
        let user = result.user
        guard
            let userID = user.userID,
            let email = user.profile?.email
        else {
            throw EmailEngineError.tokenMissing
        }
        // Google's iOS SDK exposes the refresh token as a non-optional
        // `GIDToken` whose `tokenString` may still be empty if the IdP
        // declined to issue one (e.g. a Workspace policy blocking the
        // requested scope). Treat empty as a hard failure so we surface it
        // instead of silently storing a useless entry.
        let refreshToken = user.refreshToken.tokenString
        guard !refreshToken.isEmpty else {
            throw EmailEngineError.refreshTokenUnavailable
        }
        let account = GoogleAccount(userID: userID, email: email, refreshToken: refreshToken)
        try keychain.upsert(account)
        return account
    }

    /// Disconnect a single account. Other connected accounts remain signed in.
    public func disconnect(accountID: String) {
        keychain.remove(userID: accountID)
        tokenCache.invalidate(accountID: accountID)
        // If the currently-active Google user matches, also sign out of GIDSignIn.
        if GIDSignIn.sharedInstance.currentUser?.userID == accountID {
            GIDSignIn.sharedInstance.signOut()
        }
    }

    /// Disconnect all accounts.
    public func signOutAll() {
        GIDSignIn.sharedInstance.signOut()
        keychain.removeAll()
        tokenCache.invalidateAll()
    }

    /// Every account the user has connected, in insertion order.
    public var connectedAccounts: [GoogleAccount] {
        keychain.listAll()
    }

    public var isSignedIn: Bool {
        !keychain.listAll().isEmpty
    }

    /// Fetch a page of Gmail message IDs for the given account.
    public func fetchMessageList(
        accountID: String,
        query: String = GmailQuery.trialsRecent,
        pageToken: String? = nil
    ) async throws -> MessageListResponse {
        let token = try await freshAccessToken(accountID: accountID)
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "50"),
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(MessageListResponse.self, from: data)
    }

    /// Fetch the full body of a single message from the given account.
    public func fetchMessage(accountID: String, id: String) async throws -> GmailMessage {
        try await fetchMessage(accountID: accountID, id: id, format: "full")
    }

    /// Fetch headers + snippet only (cheap; used for first-pass filtering).
    public func fetchMessageMetadata(accountID: String, id: String) async throws -> GmailMessage {
        try await fetchMessage(accountID: accountID, id: id, format: "metadata")
    }

    private func fetchMessage(accountID: String, id: String, format: String) async throws -> GmailMessage {
        let token = try await freshAccessToken(accountID: accountID)
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=\(format)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }
}

// MARK: - Token refresh (direct Google token endpoint)

private extension EmailEngine {
    /// Return a non-expired access token for `accountID`. Serves from cache
    /// when still valid; otherwise POSTs the stored refresh token to
    /// `oauth2.googleapis.com/token`. Concurrent callers for the same account
    /// coalesce through `refreshCoordinator` so only one network refresh fires.
    func freshAccessToken(accountID: String) async throws -> String {
        if let cached = tokenCache.get(accountID: accountID) {
            return cached
        }

        let keychain = keychain
        let tokenCache = tokenCache
        let clientID = clientID

        return try await refreshCoordinator.freshToken(for: accountID) { accountID in
            // Re-check the cache inside the coordinator: a concurrent refresh
            // may have already populated it by the time we got the slot.
            if let cached = tokenCache.get(accountID: accountID) {
                return cached
            }
            guard let account = keychain.find(userID: accountID) else {
                throw EmailEngineError.notSignedIn
            }
            guard !clientID.isEmpty else {
                throw EmailEngineError.notConfigured
            }

            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var form = URLComponents()
            form.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "refresh_token", value: account.refreshToken),
                URLQueryItem(name: "grant_type", value: "refresh_token"),
            ]
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw EmailEngineError.unauthorized
            }
            if http.statusCode == 400 || http.statusCode == 401 {
                // Refresh token rejected. Don't delete the Keychain entry —
                // the app layer decides what to show the user and can trigger
                // a reconnect, which replaces the stored refresh token.
                tokenCache.invalidate(accountID: accountID)
                throw EmailEngineError.refreshTokenRevoked
            }
            if !(200..<300).contains(http.statusCode) {
                throw EmailEngineError.httpError(http.statusCode)
            }
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            let ttl = TimeInterval(decoded.expires_in ?? 3600)
            tokenCache.set(accountID: accountID, token: decoded.access_token, ttl: ttl)
            return decoded.access_token
        }
    }

    func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw EmailEngineError.unauthorized }
        if !(200..<300).contains(http.statusCode) {
            throw EmailEngineError.httpError(http.statusCode)
        }
    }
}

private struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int?
    let token_type: String?
    let scope: String?
}

// MARK: - Constants

private enum GmailScope {
    static let readonly = "https://www.googleapis.com/auth/gmail.readonly"
}

#endif
