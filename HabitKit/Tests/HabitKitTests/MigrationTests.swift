import Testing
import Foundation
import SwiftData
@testable import HabitKit

@Test func habitSchemaV1ListsAllThreeModels() {
    let modelNames = Set(HabitSchemaV1.models.map { String(describing: $0) })
    #expect(modelNames == ["Habit", "LogEvent", "Pause"])
}

@Test func habitMigrationPlanStartsFromV1WithNoStagesYet() {
    #expect(HabitMigrationPlan.schemas.map { "\($0)" } == ["\(HabitSchemaV1.self)"])
    #expect(HabitMigrationPlan.stages.isEmpty)
}

/// The regression test for the actual bug. SwiftData only needs a visible
/// default for a property being added to an entity that's *already
/// persisted* — the rest of `Habit`'s non-optional properties have existed
/// since the schema's first commit and were never missing from any real
/// store, so they carry no inline default and that's correctly fine (a
/// blanket sweep over every property was tried here first and produced
/// false positives against every original field; that approach doesn't
/// work, because SwiftData can't distinguish "always been here" from "just
/// added" — only git history can, which is why step 4 of the documented
/// process is a dedicated migration test per change, not a static scan).
/// `nudgeHour` is the one property in this schema that *was* added later,
/// and this pins exactly the fix: a default visible to SwiftData, not just
/// to `init`.
@Test func nudgeHourHasASwiftDataVisibleDefault() throws {
    let schema = Schema(versionedSchema: HabitSchemaV1.self)
    let habitEntity = try #require(schema.entities.first { $0.name == "Habit" })
    let nudgeHourAttribute = try #require(
        habitEntity.storedProperties.first { $0.name == "nudgeHour" } as? Schema.Attribute
    )

    #expect(nudgeHourAttribute.isOptional == false)
    #expect(nudgeHourAttribute.defaultValue != nil)
}

@MainActor
private func makeOnDiskContainer(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: HabitSchemaV1.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, migrationPlan: HabitMigrationPlan.self, configurations: [configuration])
}

/// A closer-to-reality check than an in-memory store: write a real habit to
/// a real file, then open a *second, independent* container at that same
/// URL — simulating an app relaunch — through the exact same
/// `HabitMigrationPlan` the app uses, and confirm it opens without throwing
/// and the data (including the once-problematic `nudgeHour`, at its
/// default) survived.
@MainActor
@Test func aStoreWrittenByOneContainerReopensCleanlyInAnother() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HabitMigrationTest-\(UUID().uuidString)", isDirectory: false)
        .appendingPathExtension("store")
    defer { try? FileManager.default.removeItem(at: url) }

    do {
        let firstContainer = try makeOnDiskContainer(at: url)
        let context = ModelContext(firstContainer)
        context.insert(Habit(name: "Read", symbolName: "book"))
        try context.save()
    }

    let secondContainer = try makeOnDiskContainer(at: url)
    let reopenedContext = ModelContext(secondContainer)
    let habits = try reopenedContext.fetch(FetchDescriptor<Habit>())

    #expect(habits.count == 1)
    #expect(habits.first?.name == "Read")
    #expect(habits.first?.nudgeHour == 9)
}
