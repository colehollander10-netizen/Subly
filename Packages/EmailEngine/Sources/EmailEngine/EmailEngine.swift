import Foundation
import GoogleSignIn
import Security
import UIKit

// MARK: - Public API

public final class EmailEngine: @unchecked Sendable {
    public static let shared = EmailEngine()

    private let keychain = KeychainTokenStore()

    private init() {}

    /// Configure GIDSignIn. Call from SublyApp before any sign-in attempt.
    public func configure(clientID: String) {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    /// Handle the OAuth redirect URL. Call from SublyApp's onOpenURL modifier.
    @discardableResult
    public func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// Restore a previous sign-in silently on app launch.
    public func restorePreviousSignIn() async throws {
        try await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    /// Present the Google sign-in flow from the given view controller.
    public func signIn(presenting viewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: [GmailScope.readonly]
        )
        try keychain.store(user: result.user)
    }

    /// Sign out and clear stored tokens.
    public func signOut() {
        GIDSignIn.sharedInstance.signOut()
        keychain.clear()
    }

    public var isSignedIn: Bool {
        GIDSignIn.sharedInstance.currentUser != nil
    }

    public var connectedEmail: String? {
        GIDSignIn.sharedInstance.currentUser?.profile?.email
    }

    /// Fetch a page of Gmail message IDs matching the subscription query.
    /// Silently refreshes the access token before the call.
    public func fetchMessageList(pageToken: String? = nil) async throws -> MessageListResponse {
        let token = try await freshAccessToken()
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: GmailQuery.subscriptions),
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

    /// Fetch the full body of a single message.
    public func fetchMessage(id: String) async throws -> GmailMessage {
        let token = try await freshAccessToken()
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }
}

// MARK: - Token refresh

private extension EmailEngine {
    func freshAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw EmailEngineError.notSignedIn
        }
        try await user.refreshTokensIfNeeded()
        guard let token = user.accessToken.tokenString as String? else {
            throw EmailEngineError.tokenMissing
        }
        return token
    }

    func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw EmailEngineError.unauthorized }
        if !(200..<300).contains(http.statusCode) {
            throw EmailEngineError.httpError(http.statusCode)
        }
    }
}

// MARK: - Keychain

private final class KeychainTokenStore: Sendable {
    private let service = "com.subly.emailengine"
    private let accountKey = "google_user_id"

    func store(user: GIDGoogleUser) throws {
        guard let userID = user.userID else { return }
        let data = Data(userID.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountKey,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw EmailEngineError.keychainError(status)
        }
    }

    func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Constants

private enum GmailScope {
    static let readonly = "https://www.googleapis.com/auth/gmail.readonly"
}

private enum GmailQuery {
    static let subscriptions = "subject:(welcome OR confirmation OR \"your subscription\" OR \"free trial\" OR \"trial started\" OR canceled OR paused)"
}

// MARK: - Response models

public struct MessageListResponse: Decodable, Sendable {
    public let messages: [MessageRef]?
    public let nextPageToken: String?
    public let resultSizeEstimate: Int?
}

public struct MessageRef: Decodable, Sendable {
    public let id: String
    public let threadId: String
}

public struct GmailMessage: Decodable, Sendable {
    public let id: String
    public let threadId: String
    public let payload: MessagePayload?
    public let snippet: String?
}

public struct MessagePayload: Decodable, Sendable {
    public let headers: [MessageHeader]?
    public let body: MessageBody?
    public let parts: [MessagePayload]?
}

public struct MessageHeader: Decodable, Sendable {
    public let name: String
    public let value: String
}

public struct MessageBody: Decodable, Sendable {
    public let data: String?  // base64url encoded
    public let size: Int
}

// MARK: - Errors

public enum EmailEngineError: Error, Sendable {
    case notSignedIn
    case tokenMissing
    case unauthorized
    case httpError(Int)
    case keychainError(OSStatus)
}
