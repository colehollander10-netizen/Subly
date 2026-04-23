import Foundation

/// Lifecycle state of a tracked entry. Orthogonal to `EntryType` — a
/// subscription can be `.active` or `.cancelled`, a trial can be any of the
/// three. `.expired` means a trial's chargeDate passed without a user cancel;
/// it does NOT count toward "Caught $X" (only `.cancelled` does).
public enum EntryStatus: String, Codable, Sendable, CaseIterable {
    case active
    case cancelled
    case expired
}
