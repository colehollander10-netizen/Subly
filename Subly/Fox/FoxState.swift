import Foundation

enum FoxState: String, CaseIterable, Equatable {
    case sleeping
    case curious
    case happy
    case veryHappy
    case proud
    case alert

    var assetName: String {
        switch self {
        case .sleeping: return "fox-sleeping"
        case .curious, .happy, .veryHappy, .proud, .alert: return "fox-sitting"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sleeping: return "Sleeping fox"
        case .curious: return "Curious fox"
        case .happy: return "Happy fox"
        case .veryHappy: return "Very happy fox"
        case .proud: return "Proud fox"
        case .alert: return "Alert fox"
        }
    }
}
