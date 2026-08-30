import Testing
import Foundation
import SwiftData
@testable import HabitKit

@Test func habitSchemaV1ListsAllThreeModels() {
    let modelNames = Set(HabitSchemaV1.models.map { String(describing: $0) })
    #expect(modelNames == ["Habit", "LogEvent", "Pause"])
}

@Test func habitSchemaV2AddsAppSettingsToTheThreeOriginalModels() {
    let modelNames = Set(HabitSchemaV2.models.map { String(describing: $0) })
    #expect(modelNames == ["Habit", "LogEvent", "Pause", "AppSettings"])
}

@Test func habitMigrationPlanSpansV1ToV2WithOneLightweightStage() {
    #expect(HabitMigrationPlan.schemas.map { "\($0)" } == ["\(HabitSchemaV1.self)", "\(HabitSchemaV2.self)"])
    #expect(HabitMigrationPlan.stages.count == 1)
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
    // Tracks the schema version the real app currently builds
    // (`HabitApp.swift`'s `sharedModelContainer`) — bumped to V2 alongside
    // it, so this stays "the exact same plan the app uses" rather than
    // silently pinning to whatever version existed when the test was first
    // written.
    let schema = Schema(versionedSchema: HabitSchemaV2.self)
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

/// The migration plan the app shipped with before this run — V1 only, no
/// stages — used below to write a store that has genuinely never heard of
/// `AppSettings`, rather than one that merely happens to fetch through a
/// V1-shaped `Schema` while still built by the current, V2-aware
/// `HabitMigrationPlan`.
private enum LegacyV1OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [HabitSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
private func makeLegacyV1OnlyContainer(at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: HabitSchemaV1.self)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, migrationPlan: LegacyV1OnlyMigrationPlan.self, configurations: [configuration])
}

/// The V1 → V2 migration itself: a store written entirely under the old,
/// pre-`AppSettings` plan opens cleanly under today's `HabitMigrationPlan`,
/// with the habit that predates `AppSettings` fully intact. Separately
/// confirms the migration only adds the `AppSettings` *entity* to the
/// schema — it doesn't fabricate a row. Creating and seeding the first row
/// is `AppSettingsAccessor`'s job, exercised in `AppSettingsTests.swift`,
/// not the migration's.
@MainActor
@Test func aV1StoreMigratesCleanlyToV2WithHabitIntact() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HabitMigrationV1ToV2Test-\(UUID().uuidString)", isDirectory: false)
        .appendingPathExtension("store")
    defer { try? FileManager.default.removeItem(at: url) }

    do {
        let legacyContainer = try makeLegacyV1OnlyContainer(at: url)
        let context = ModelContext(legacyContainer)
        context.insert(Habit(name: "Read", symbolName: "book"))
        try context.save()
    }

    let migratedContainer = try makeOnDiskContainer(at: url)
    let context = ModelContext(migratedContainer)

    let habits = try context.fetch(FetchDescriptor<Habit>())
    #expect(habits.count == 1)
    #expect(habits.first?.name == "Read")
    #expect(habits.first?.nudgeHour == 9)

    let settings = try context.fetch(FetchDescriptor<AppSettings>())
    #expect(settings.isEmpty)
}
