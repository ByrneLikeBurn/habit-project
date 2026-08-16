//
//  HabitEntity.swift
//  Habit
//

import AppIntents
import SwiftData
import HabitKit

/// The Shortcuts/Siri-facing stand-in for a `Habit` — a plain `Sendable`
/// value, not the SwiftData model itself. `LogHabitIntent` looks up the real
/// `Habit` fresh from the shared container whenever it actually needs one.
struct HabitEntity: AppEntity {
    let id: UUID
    let name: String
    let symbolName: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbolName))
    }

    static var defaultQuery = HabitEntityQuery()
}

extension HabitEntity {
    init(habit: Habit) {
        id = habit.id
        name = habit.name
        symbolName = habit.symbolName
    }
}

struct HabitEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        let context = ModelContext(HabitApp.sharedModelContainer)
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { identifiers.contains($0.id) })
        return try context.fetch(descriptor).map(HabitEntity.init)
    }
}

extension HabitEntityQuery: EnumerableEntityQuery {
    /// Every loggable habit — this is what populates Shortcuts' parameter
    /// picker. Archived and Recently Deleted habits are excluded, same as
    /// Today (spec §9): there's nothing to log for a habit hidden everywhere
    /// else in the app.
    @MainActor
    func allEntities() async throws -> [HabitEntity] {
        let context = ModelContext(HabitApp.sharedModelContainer)
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.archivedAt == nil && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return try context.fetch(descriptor).map(HabitEntity.init)
    }
}

extension HabitEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [HabitEntity] {
        let context = ModelContext(HabitApp.sharedModelContainer)
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.archivedAt == nil && $0.deletedAt == nil && $0.name.localizedStandardContains(string) }
        )
        return try context.fetch(descriptor).map(HabitEntity.init)
    }
}
