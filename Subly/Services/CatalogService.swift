import Foundation
import SubscriptionStore

struct CatalogService: Codable, Equatable, Identifiable {
    let slug: String
    let name: String
    let category: String
    let billingCycle: String
    let suggestedPrice: Double
    let domain: String

    var id: String { slug }

    var billingCycleEnum: BillingCycle {
        BillingCycle(rawValue: billingCycle) ?? .monthly
    }

    var suggestedPriceDecimal: Decimal {
        Decimal(suggestedPrice)
    }
}

enum ServicesCatalog {
    private static let all: [CatalogService] = loadCatalog()

    static var services: [CatalogService] { all }

    static func search(_ query: String) -> [CatalogService] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let normalized = normalize(trimmed)
        return all.filter { service in
            normalize(service.name).contains(normalized) || service.slug.contains(normalized)
        }
    }

    static func service(forSlug slug: String) -> CatalogService? {
        all.first { $0.slug == slug }
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func loadCatalog() -> [CatalogService] {
        guard let url = Bundle.main.url(forResource: "ServicesCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        struct Wrapper: Codable {
            let version: Int
            let services: [CatalogService]
        }
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            return []
        }
        return wrapper.services.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
