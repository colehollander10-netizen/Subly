import Foundation

/// Finn's 7 emotional states. See `docs/superpowers/specs/2026-04-24-finn-v1-design.md`
/// § Section 2 for the full mapping of app-state → fox-state.
///
/// `assetName` is the catalog entry MascotKit expects to find. During v1,
/// several states alias to the two placeholder assets that already shipped
/// (`fox-sitting`, `fox-sleeping`) — final vector art for each state lands
/// in sub-plan 15 (app-icon + illustration).
public enum FoxState: String, CaseIterable, Equatable, Sendable {
    /// Curled, eyes closed. Home/Trials empty states.
    case sleeping
    /// Upright, calm. Settings header + onboarding intro (default pose).
    case sitting
    /// Alert, ears perked. Home when trials exist but no urgency.
    case watching
    /// Tense, tapping watch. Home urgency + calendar red-alert headers.
    case nervous
    /// Crouched, tail low, focused. HuntSheet only.
    case hunting
    /// Arms up, happy-arc eyes. Cancel success + post-kill celebration.
    case celebrating
    /// Hero pose. Savings screen when cumulative savings > $100.
    case proud

    /// Asset catalog identifier for the current pose. Placeholder mapping —
    /// final art in sub-plan 15 will provide one asset per state.
    public var assetName: String {
        switch self {
        case .sleeping: return "fox-sleeping"
        case .sitting, .watching, .nervous, .hunting, .celebrating, .proud:
            return "fox-sitting"
        }
    }

    /// VoiceOver label for the current state.
    public var accessibilityLabel: String {
        switch self {
        case .sleeping: return "Finn is sleeping"
        case .sitting: return "Finn is sitting"
        case .watching: return "Finn is watching"
        case .nervous: return "Finn is nervous — a bill is close"
        case .hunting: return "Finn is hunting"
        case .celebrating: return "Finn is celebrating"
        case .proud: return "Finn is proud"
        }
    }

    /// Whether this state has a continuous emotional-beat animation loop.
    /// Reduce Motion always disables loops regardless.
    public var hasEmotionalBeat: Bool {
        switch self {
        case .nervous, .hunting: return true
        case .sleeping, .sitting, .watching, .celebrating, .proud: return false
        }
    }
}
