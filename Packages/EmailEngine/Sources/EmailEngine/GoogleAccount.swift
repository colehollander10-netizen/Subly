import Foundation

/// A Gmail account that Subly holds a refresh token for. The access token is
/// derived on demand and never persisted — only the refresh token lives in
/// the Keychain.
public struct GoogleAccount: Sendable, Hashable, Codable {
    public let userID: String
    public let email: String
    public let refreshToken: String

    public init(userID: String, email: String, refreshToken: String) {
        self.userID = userID
        self.email = email
        self.refreshToken = refreshToken
    }
}

public enum EmailEngineError: Error, Sendable {
    case notSignedIn
    case notConfigured
    case accountNotActive
    case tokenMissing
    case refreshTokenUnavailable
    case refreshTokenRevoked
    case unauthorized
    case httpError(Int)
    case keychainError(OSStatus)
}
