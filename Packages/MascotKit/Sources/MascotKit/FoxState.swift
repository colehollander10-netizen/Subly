import Foundation

/// Finn's three allowed v1 moods. The brand foundation owns this list.
public enum FoxState: String, CaseIterable, Equatable, Sendable {
    /// Curled, eyes closed. Empty states and all-set surfaces.
    case sleeping
    /// Upright, calm, slight smile. Onboarding, app icon, About footer.
    case neutral
    /// Ears forward, brow slightly raised. Only for charges in 1 day.
    case concerned

    /// Asset catalog identifier for the current pose.
    public var assetName: String {
        switch self {
        case .sleeping: return "fox-sleeping"
        case .neutral, .concerned:
            return "fox-sitting"
        }
    }

    /// VoiceOver label for the current state.
    public var accessibilityLabel: String {
        switch self {
        case .sleeping: return "Finn is sleeping"
        case .neutral: return "Finn is calm"
        case .concerned: return "Finn is concerned about a charge"
        }
    }

    /// V1 fox moods are static. Motion belongs to entry/exit transitions,
    /// not character loops.
    public var hasEmotionalBeat: Bool {
        false
    }
}
