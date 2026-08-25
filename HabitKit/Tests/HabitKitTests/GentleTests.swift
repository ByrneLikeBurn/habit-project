import Testing
import Foundation
import SwiftData
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

@MainActor
private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Habit.self, LogEvent.self, Pause.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@Test func gentleModeSafeguardTriggersAtFourteenDays() {
    let triggered = gentleModeHasBeenOnForTwoWeeks(startedAtDayKey: 20260801, today: 20260815, calendar: testCalendar)
    #expect(triggered == true)
}

@Test func gentleModeSafeguardDoesNotTriggerBeforeFourteenDays() {
    let triggered = gentleModeHasBeenOnForTwoWeeks(startedAtDayKey: 20260801, today: 20260810, calendar: testCalendar)
    #expect(triggered == false)
}

@Test func gentleModeSafeguardIsOffWhenNeverStarted() {
    let triggered = gentleModeHasBeenOnForTwoWeeks(startedAtDayKey: 0, today: 20260815, calendar: testCalendar)
    #expect(triggered == false)
}

// MARK: - reconcileGentleMode

@MainActor
@Test func reconcileGentleModeOnOpensAPauseOnlyForGentleEnabledHabits() throws {
    let context = try makeInMemoryContext()
    let flagged = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    let unflagged = Habit(name: "Walk", symbolName: "figure.walk", gentleEnabled: false)
    context.insert(flagged)
    context.insert(unflagged)
    try context.save()

    reconcileGentleMode(isOn: true, habits: [flagged, unflagged], today: 20260815, modelContext: context)

    #expect(flagged.pauses.contains { $0.reason == .gentle && $0.endDay == nil })
    #expect(unflagged.pauses.isEmpty)
}

/// The regression test for the actual bug: `GentleModeView` fetched habits
/// with a *sorted* `@Query`, which — per `HabitOrdering.swift`'s own
/// documented warning — stops noticing changes to properties like
/// `gentleEnabled` that aren't part of the sort key. In practice this meant
/// a habit whose `gentleEnabled` flag was toggled mid-session (or a habit
/// otherwise resting) could get left out of a stale `habits` snapshot when
/// the global switch turned off, leaving its `Pause` open forever. This
/// test doesn't exercise SwiftUI's `@Query` (that isn't unit-testable), but
/// it pins the contract the fix depends on: given a *fresh* fetch — which is
/// what the corrected, unsorted `@Query` now always produces — turning
/// Gentle Mode off must leave no habit paused by reason `.gentle`, no matter
/// how habits arrived at their current `gentleEnabled` state.
@MainActor
@Test func turningGentleModeOffLeavesNoHabitPausedByReasonGentle() throws {
    let context = try makeInMemoryContext()

    let alwaysGentle = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    let neverGentle = Habit(name: "Walk", symbolName: "figure.walk", gentleEnabled: false)
    let toggledOnLater = Habit(name: "Stretch", symbolName: "figure.flexibility", gentleEnabled: false)
    context.insert(alwaysGentle)
    context.insert(neverGentle)
    context.insert(toggledOnLater)
    try context.save()

    let today = 20260815

    // Turn Gentle Mode on globally.
    reconcileGentleMode(isOn: true, habits: [alwaysGentle, neverGentle, toggledOnLater], today: today, modelContext: context)

    // Mid-session, enable a habit that wasn't gentle-enabled when the
    // switch first turned on — the per-habit toggle path, called with just
    // that one habit, exactly as HabitDetailView and GentleModeView's own
    // per-habit row do.
    toggledOnLater.gentleEnabled = true
    reconcileGentleMode(isOn: true, habits: [toggledOnLater], today: today, modelContext: context)

    #expect(alwaysGentle.pauses.contains { $0.reason == .gentle && $0.endDay == nil })
    #expect(toggledOnLater.pauses.contains { $0.reason == .gentle && $0.endDay == nil })

    // Turn Gentle Mode off, using a fresh fetch from the store rather than
    // any previously-held array — this is what the fixed (unsorted) `@Query`
    // in GentleModeView now always provides.
    let freshlyFetchedHabits = try context.fetch(FetchDescriptor<Habit>())
    reconcileGentleMode(isOn: false, habits: freshlyFetchedHabits, today: today, modelContext: context)

    let allPauses = try context.fetch(FetchDescriptor<Pause>())
    let stillOpenGentlePauses = allPauses.filter { $0.reason == .gentle && $0.endDay == nil }
    #expect(stillOpenGentlePauses.isEmpty)
}
