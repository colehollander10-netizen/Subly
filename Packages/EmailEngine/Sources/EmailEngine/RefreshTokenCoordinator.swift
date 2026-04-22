import Foundation

/// Coalesces concurrent refresh-token exchanges per account.
///
/// Two scan paths hitting an expired access token at the same moment
/// should result in exactly one `POST oauth2.googleapis.com/token` —
/// both awaiters receive the same new access token.
///
/// The coordinator is platform-neutral; the actual HTTP call is passed in
/// so tests can stub it.
actor RefreshTokenCoordinator {
    typealias Refresh = @Sendable (_ accountID: String) async throws -> String

    private var inFlight: [String: Task<String, Error>] = [:]

    func freshToken(for accountID: String, refresh: @escaping Refresh) async throws -> String {
        if let existing = inFlight[accountID] {
            return try await existing.value
        }

        let task = Task<String, Error> {
            try await refresh(accountID)
        }
        inFlight[accountID] = task

        defer { inFlight[accountID] = nil }
        return try await task.value
    }
}
