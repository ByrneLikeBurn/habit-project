import Testing
import Foundation
import SwiftData
@testable import HabitKit

@MainActor
private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Habit.self, LogEvent.self, Pause.self, AppSettings.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

// MARK: - mergedGentleModeState — pure, no ModelContext needed

@Test func mergeOnWinsOverOff() {
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 0),
        AppSettings(gentleModeStartedAtDayKey: 20260810),
    ]
    #expect(mergedGentleModeState(rows).startedAtDayKey == 20260810)
}

@Test func mergeEarliestStartWins() {
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 20260805),
        AppSettings(gentleModeStartedAtDayKey: 20260801),
    ]
    #expect(mergedGentleModeState(rows).startedAtDayKey == 20260801)
}

@Test func mergeAllZeroStaysZero() {
    let rows = [AppSettings(gentleModeStartedAtDayKey: 0), AppSettings(gentleModeStartedAtDayKey: 0)]
    #expect(mergedGentleModeState(rows).startedAtDayKey == 0)
}

@Test func mergeDismissalMatchingMergedStartWins() {
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 20260805, gentleModeSafeguardDismissedForDayKey: 0),
        AppSettings(gentleModeStartedAtDayKey: 20260801, gentleModeSafeguardDismissedForDayKey: 20260801),
    ]
    let merged = mergedGentleModeState(rows)
    #expect(merged.startedAtDayKey == 20260801)
    #expect(merged.safeguardDismissedForDayKey == 20260801)
}

@Test func mergeDismissalNotMatchingMergedStartIsZero() {
    // Dismissed for a *previous* on-period (20260701) that isn't this
    // merged on-period (20260801) — the safeguard must reappear.
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 20260801, gentleModeSafeguardDismissedForDayKey: 20260701),
        AppSettings(gentleModeStartedAtDayKey: 20260805, gentleModeSafeguardDismissedForDayKey: 0),
    ]
    let merged = mergedGentleModeState(rows)
    #expect(merged.startedAtDayKey == 20260801)
    #expect(merged.safeguardDismissedForDayKey == 0)
}

@Test func mergeIsOrderIndependent() {
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 20260805, gentleModeSafeguardDismissedForDayKey: 0),
        AppSettings(gentleModeStartedAtDayKey: 20260801, gentleModeSafeguardDismissedForDayKey: 20260801),
        AppSettings(gentleModeStartedAtDayKey: 0, gentleModeSafeguardDismissedForDayKey: 0),
    ]
    let forward = mergedGentleModeState(rows)
    let reversed = mergedGentleModeState(rows.reversed())
    let shuffled = mergedGentleModeState(rows.shuffled())
    #expect(forward.startedAtDayKey == reversed.startedAtDayKey)
    #expect(forward.safeguardDismissedForDayKey == reversed.safeguardDismissedForDayKey)
    #expect(forward.startedAtDayKey == shuffled.startedAtDayKey)
    #expect(forward.safeguardDismissedForDayKey == shuffled.safeguardDismissedForDayKey)
}

@Test func mergeIsIdempotent() {
    let rows = [
        AppSettings(gentleModeStartedAtDayKey: 20260805, gentleModeSafeguardDismissedForDayKey: 0),
        AppSettings(gentleModeStartedAtDayKey: 20260801, gentleModeSafeguardDismissedForDayKey: 20260801),
    ]
    let once = mergedGentleModeState(rows)

    // Merging the same rows a second time, and merging a single row already
    // holding the merged result, both have to land on the same answer.
    let twice = mergedGentleModeState(rows + rows)
    let ofItsOwnResult = mergedGentleModeState([
        AppSettings(
            gentleModeStartedAtDayKey: once.startedAtDayKey,
            gentleModeSafeguardDismissedForDayKey: once.safeguardDismissedForDayKey
        ),
    ])

    #expect(twice.startedAtDayKey == once.startedAtDayKey)
    #expect(twice.safeguardDismissedForDayKey == once.safeguardDismissedForDayKey)
    #expect(ofItsOwnResult.startedAtDayKey == once.startedAtDayKey)
    #expect(ofItsOwnResult.safeguardDismissedForDayKey == once.safeguardDismissedForDayKey)
}

// MARK: - AppSettingsAccessor.current — ModelContext-backed

@MainActor
@Test func currentCreatesARowWhenNoneExists() throws {
    let context = try makeInMemoryContext()
    let settings = AppSettingsAccessor.current(modelContext: context)

    #expect(try context.fetch(FetchDescriptor<AppSettings>()).count == 1)
    #expect(settings.gentleModeStartedAtDayKey == 0)
    #expect(settings.gentleModeSafeguardDismissedForDayKey == 0)
}

@MainActor
@Test func currentUsesTheExistingRowUnchangedWhenExactlyOne() throws {
    let context = try makeInMemoryContext()
    context.insert(AppSettings(gentleModeStartedAtDayKey: 20260801, gentleModeSafeguardDismissedForDayKey: 20260801))
    try context.save()

    let settings = AppSettingsAccessor.current(modelContext: context)

    #expect(try context.fetch(FetchDescriptor<AppSettings>()).count == 1)
    #expect(settings.gentleModeStartedAtDayKey == 20260801)
    #expect(settings.gentleModeSafeguardDismissedForDayKey == 20260801)
}

@MainActor
@Test func currentMergesMultipleRowsIntoTheLowestIDAndLeavesTheRestInPlace() throws {
    let context = try makeInMemoryContext()
    let lower = AppSettings(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        gentleModeStartedAtDayKey: 0,
        gentleModeSafeguardDismissedForDayKey: 0
    )
    let higher = AppSettings(
        id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
        gentleModeStartedAtDayKey: 20260801,
        gentleModeSafeguardDismissedForDayKey: 20260801
    )
    context.insert(lower)
    context.insert(higher)
    try context.save()

    let canonical = AppSettingsAccessor.current(modelContext: context)

    #expect(canonical.id == lower.id)
    #expect(canonical.gentleModeStartedAtDayKey == 20260801)
    #expect(canonical.gentleModeSafeguardDismissedForDayKey == 20260801)

    // Both rows still exist — the extra row is never deleted.
    let allRows = try context.fetch(FetchDescriptor<AppSettings>())
    #expect(allRows.count == 2)
    // The non-canonical row is left exactly as it was, not overwritten too.
    #expect(higher.gentleModeStartedAtDayKey == 20260801)
    #expect(higher.gentleModeSafeguardDismissedForDayKey == 20260801)
}

/// With two rows present (only reachable once CloudKit lets a second device
/// create one — not reachable today with a single local store), turning
/// Gentle Mode off must actually stick. A write that only touched the
/// canonical row would leave the other row's stale non-zero start in place,
/// and the very next merge — "on wins" — would read it as still on,
/// making the switch impossible to turn off. A row this device can already
/// see is current state it's entitled to overwrite, not stale data to
/// protect against; "on wins" exists to protect against a remote row
/// arriving *later*, not one already sitting in the local store.
@MainActor
@Test func turningGentleModeOffAppliesToEveryRowNotJustTheCanonicalOne() throws {
    let context = try makeInMemoryContext()
    let lower = AppSettings(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        gentleModeStartedAtDayKey: 20260801
    )
    let higher = AppSettings(
        id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
        gentleModeStartedAtDayKey: 20260805
    )
    context.insert(lower)
    context.insert(higher)
    try context.save()

    AppSettingsAccessor.setGentleModeStartedAtDayKey(0, modelContext: context)

    let rows = try context.fetch(FetchDescriptor<AppSettings>())
    #expect(rows.allSatisfy { $0.gentleModeStartedAtDayKey == 0 })
    #expect(mergedGentleModeState(rows).startedAtDayKey == 0)
}

/// The same class of bug, for the other write function: dismissing the
/// safeguard has to stick across every row too, or the next merge could
/// resurrect the "not dismissed" state via a row this write didn't reach.
@MainActor
@Test func dismissingTheSafeguardAppliesToEveryRowNotJustTheCanonicalOne() throws {
    let context = try makeInMemoryContext()
    let lower = AppSettings(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        gentleModeStartedAtDayKey: 20260801,
        gentleModeSafeguardDismissedForDayKey: 0
    )
    let higher = AppSettings(
        id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
        gentleModeStartedAtDayKey: 20260805,
        gentleModeSafeguardDismissedForDayKey: 0
    )
    context.insert(lower)
    context.insert(higher)
    try context.save()

    AppSettingsAccessor.dismissGentleModeSafeguard(modelContext: context)

    let rows = try context.fetch(FetchDescriptor<AppSettings>())
    #expect(rows.allSatisfy { $0.gentleModeSafeguardDismissedForDayKey == 20260801 })
    #expect(mergedGentleModeState(rows).safeguardDismissedForDayKey == 20260801)
}

// MARK: - Seed from legacy UserDefaults

/// Sets a `UserDefaults.standard` key for the duration of `body`, restoring
/// whatever was there before (or clearing it, if nothing was) afterwards —
/// this suite touches the same keys the real app's legacy `@AppStorage`
/// sites used, on the shared `UserDefaults.standard`, so it must not leak
/// state into other tests or the environment.
private func withUserDefaultsValue(_ value: Int, forKey key: String, _ body: () throws -> Void) rethrows {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: key)
    defaults.set(value, forKey: key)
    defer {
        if let previous {
            defaults.set(previous, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
    try body()
}

@MainActor
@Test func currentSeedsTheFirstRowFromExistingUserDefaultsState() throws {
    try withUserDefaultsValue(20260801, forKey: GentleModeStorage.startedAtDayKeyDefaultsKey) {
        try withUserDefaultsValue(20260801, forKey: GentleModeStorage.safeguardDismissedDefaultsKey) {
            let context = try makeInMemoryContext()
            let settings = AppSettingsAccessor.current(modelContext: context)

            #expect(settings.gentleModeStartedAtDayKey == 20260801)
            #expect(settings.gentleModeSafeguardDismissedForDayKey == 20260801)
        }
    }
}

@MainActor
@Test func currentNeverReSeedsOverAnExistingRow() throws {
    try withUserDefaultsValue(20260801, forKey: GentleModeStorage.startedAtDayKeyDefaultsKey) {
        let context = try makeInMemoryContext()

        // First call creates and seeds the row from UserDefaults.
        _ = AppSettingsAccessor.current(modelContext: context)

        // UserDefaults changes afterward — as it would if some other,
        // now-unused code path still wrote to the legacy key — must never
        // be picked up again once a row already exists.
        UserDefaults.standard.set(20260901, forKey: GentleModeStorage.startedAtDayKeyDefaultsKey)

        let settings = AppSettingsAccessor.current(modelContext: context)
        #expect(settings.gentleModeStartedAtDayKey == 20260801)
        #expect(try context.fetch(FetchDescriptor<AppSettings>()).count == 1)
    }
}
