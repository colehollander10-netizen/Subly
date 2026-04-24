import Foundation

enum CancelGuideStore {
    private static let cache: [String: CancelGuide] = loadGuides()

    static func guide(for serviceName: String) -> CancelGuide? {
        cache[normalize(serviceName)]
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func loadGuides() -> [String: CancelGuide] {
        guard let url = Bundle.main.url(forResource: "CancelGuides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: CancelGuide].self, from: data)
        else { return [:] }
        return dict
    }
}
