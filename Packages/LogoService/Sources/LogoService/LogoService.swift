import Foundation

public struct LogoService {
    public init() {}

    public static func logoURL(
        for domain: String,
        brandfetchClientID: String?,
        logoDevToken: String?,
        size: Int = 128
    ) -> URL? {
        let trimmed = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "www.", with: "")

        guard !trimmed.isEmpty else { return nil }

        if let clientID = sanitizedToken(brandfetchClientID) {
            var components = URLComponents(string: "https://cdn.brandfetch.io/\(trimmed)")
            components?.queryItems = [
                URLQueryItem(name: "c", value: clientID),
            ]
            return components?.url
        }

        if let token = sanitizedToken(logoDevToken) {
            var components = URLComponents(string: "https://img.logo.dev/\(trimmed)")
            components?.queryItems = [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "size", value: "\(size)"),
                URLQueryItem(name: "format", value: "png"),
            ]
            return components?.url
        }

        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "domain", value: trimmed),
            URLQueryItem(name: "sz", value: "\(size)"),
        ]
        return components?.url
    }

    private static func sanitizedToken(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
