import Foundation

/// Recurring billing cadence for subscription-type entries. Nil on trial
/// entries. `.custom` is a fallback for anything StoreKit or the user
/// cannot neatly map to the standard cadences; in v1 it is treated as
/// monthly for spend normalization.
public enum BillingCycle: String, Codable, Sendable, CaseIterable {
    case monthly
    case yearly
    case weekly
    case custom

    /// Multiplier used to normalize a single charge into monthly-equivalent
    /// spend. A yearly $120 charge normalizes to $10/mo (÷12); a weekly $5
    /// charge normalizes to $21.65/mo (×4.33). `.custom` defaults to 1.0 in
    /// v1; refined once real custom-cycle UX lands.
    public var monthlyMultiplier: Double {
        switch self {
        case .monthly: return 1.0
        case .yearly: return 1.0 / 12.0
        case .weekly: return 4.33
        case .custom: return 1.0
        }
    }
}
