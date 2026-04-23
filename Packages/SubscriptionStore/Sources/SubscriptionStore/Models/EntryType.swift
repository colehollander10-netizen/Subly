import Foundation

/// Distinguishes a one-time free trial from a recurring subscription.
/// A trial that converts flips this field in place — the same entry row
/// persists its history across the type change.
public enum EntryType: String, Codable, Sendable, CaseIterable {
    case freeTrial
    case subscription
}
