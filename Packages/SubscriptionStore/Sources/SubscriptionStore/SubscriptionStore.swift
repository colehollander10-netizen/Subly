import Foundation
import Observation
import SwiftData

/// Thin wrapper around ModelContext. Kept around so Views can inject a single
/// Observable through the SwiftUI environment without pulling ModelContext
/// directly. Name retained (TrialStore) for domain clarity in the rebuild.
@MainActor
@Observable
public final class TrialStore {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func insert(_ model: some PersistentModel) {
        modelContext.insert(model)
    }

    public func delete(_ model: some PersistentModel) {
        modelContext.delete(model)
    }

    public func save() throws {
        try modelContext.save()
    }
}
