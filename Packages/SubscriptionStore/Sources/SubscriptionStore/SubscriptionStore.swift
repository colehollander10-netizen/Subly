import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class SubscriptionStore {
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

    public func fetchAll<T: PersistentModel>() throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>())
    }

    public func save() throws {
        try modelContext.save()
    }
}
