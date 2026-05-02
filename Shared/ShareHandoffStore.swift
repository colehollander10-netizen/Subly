import Foundation

enum ShareEntryKind: String, Codable, Sendable {
    case freeTrial
    case subscription
}

struct PendingShareEntry: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: ShareEntryKind
    let recognizedText: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ShareEntryKind,
        recognizedText: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.recognizedText = recognizedText
        self.createdAt = createdAt
    }
}

enum ShareHandoffStore {
    static let appGroupID = "group.com.colehollander.subly"
    private static let pendingEntriesKey = "pendingShareEntries"

    static func append(_ entry: PendingShareEntry) throws {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw ShareHandoffError.unavailableAppGroup
        }

        var entries = loadEntries(from: defaults)
        entries.append(entry)
        try save(entries, to: defaults)
    }

    static func pendingEntries() throws -> [PendingShareEntry] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw ShareHandoffError.unavailableAppGroup
        }

        return loadEntries(from: defaults)
    }

    static func removePendingEntries(ids: Set<UUID>) throws {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            throw ShareHandoffError.unavailableAppGroup
        }

        let remaining = loadEntries(from: defaults).filter { !ids.contains($0.id) }
        try save(remaining, to: defaults)
    }

    private static func loadEntries(from defaults: UserDefaults) -> [PendingShareEntry] {
        guard let data = defaults.data(forKey: pendingEntriesKey),
              let entries = try? JSONDecoder().decode([PendingShareEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private static func save(_ entries: [PendingShareEntry], to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(entries)
        defaults.set(data, forKey: pendingEntriesKey)
    }
}

enum ShareHandoffError: Error {
    case unavailableAppGroup
}
