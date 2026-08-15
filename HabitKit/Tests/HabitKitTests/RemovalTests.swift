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

// MARK: - Cost of deleting

@Test func loggedDayCountCountsOnlyDaysWithAPositiveTotal() {
    let habit = Habit(name: "Read", symbolName: "book")
    habit.events.append(LogEvent(habit: habit, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    habit.events.append(LogEvent(habit: habit, dayKey: 20260802, delta: 1, source: .manual, deviceID: "a"))
    habit.events.append(LogEvent(habit: habit, dayKey: 20260802, delta: -1, source: .manual, deviceID: "a")) // cleared back to 0
    habit.events.append(LogEvent(habit: habit, dayKey: 20260803, delta: 1, source: .manual, deviceID: "a"))

    #expect(loggedDayCount(for: habit) == 2) // 0801 and 0803 only
}

@Test func earliestLoggedDayKeyIgnoresDaysClearedBackToZero() {
    let habit = Habit(name: "Read", symbolName: "book")
    habit.events.append(LogEvent(habit: habit, dayKey: 20260701, delta: 1, source: .manual, deviceID: "a"))
    habit.events.append(LogEvent(habit: habit, dayKey: 20260701, delta: -1, source: .manual, deviceID: "a"))
    habit.events.append(LogEvent(habit: habit, dayKey: 20260810, delta: 1, source: .manual, deviceID: "a"))

    #expect(earliestLoggedDayKey(for: habit) == 20260810)
}

@Test func permanentDeletionCostSummaryMatchesTheSpecsExampleShape() {
    let habit = Habit(name: "Cold shower", symbolName: "drop", createdAt: Date(timeIntervalSince1970: 0))
    // Noon, well clear of the (default 4am) day-start-hour boundary.
    let earliestDate = testCalendar.date(from: DateComponents(year: 2024, month: 3, day: 4, hour: 12))!
    for offset in 0..<412 {
        let day = testCalendar.date(byAdding: .day, value: offset, to: earliestDate)!
        habit.events.append(LogEvent(habit: habit, dayKey: dayKey(for: day, calendar: testCalendar), delta: 1, source: .manual, deviceID: "a"))
    }

    let summary = permanentDeletionCostSummary(for: habit, calendar: testCalendar)

    #expect(summary == "This removes 412 logged days, going back to March 2024. It can't be undone, on this or any of your devices.")
}

@Test func permanentDeletionCostSummaryUsesSingularWordingForOneDay() {
    let habit = Habit(name: "Read", symbolName: "book")
    habit.events.append(LogEvent(habit: habit, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))

    let summary = permanentDeletionCostSummary(for: habit, calendar: testCalendar)

    #expect(summary.contains("1 logged day,"))
    #expect(!summary.contains("1 logged days"))
}

@Test func permanentDeletionCostSummaryHandlesAHabitWithNoHistory() {
    let habit = Habit(name: "Brand new", symbolName: "leaf")
    let summary = permanentDeletionCostSummary(for: habit, calendar: testCalendar)
    #expect(summary == "This habit has no logged days yet. It can't be undone, on this or any of your devices.")
}

// MARK: - Purge window

@Test func hasPurgeWindowElapsedIsFalseBeforeThirtyDays() {
    let deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 29))!
    #expect(hasPurgeWindowElapsed(deletedAt: deletedAt, today: today, calendar: testCalendar) == false)
}

@Test func hasPurgeWindowElapsedIsTrueAtExactlyThirtyDays() {
    let deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
    #expect(hasPurgeWindowElapsed(deletedAt: deletedAt, today: today, calendar: testCalendar) == true)
}

/// The spec's own scenario: a device that's been off for two months still
/// purges correctly the moment it's opened, because this is a plain date
/// comparison rather than something that needed to fire while it was away.
@Test func hasPurgeWindowElapsedIsTrueLongAfterTheWindowOnADeviceThatWasOff() {
    let deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
    #expect(hasPurgeWindowElapsed(deletedAt: deletedAt, today: today, calendar: testCalendar) == true)
}

@Test func daysRemainingBeforePurgeCountsDownToZero() {
    let deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
    #expect(daysRemainingBeforePurge(deletedAt: deletedAt, today: today, calendar: testCalendar) == 28)
}

@Test func daysRemainingBeforePurgeNeverGoesNegative() {
    let deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
    #expect(daysRemainingBeforePurge(deletedAt: deletedAt, today: today, calendar: testCalendar) == 0)
}

@Test func habitsPastPurgeWindowExcludesHabitsThatArentDeletedAtAll() {
    let activeHabit = Habit(name: "Active", symbolName: "leaf")
    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!

    #expect(habitsPastPurgeWindow([activeHabit], today: today, calendar: testCalendar).isEmpty)
}

// MARK: - purgeExpiredDeletions (real ModelContext)

@MainActor
@Test func purgeExpiredDeletionsRemovesOnlyHabitsPastTheWindow() throws {
    let context = try makeInMemoryContext()

    let deletedLongAgo = Habit(name: "Old", symbolName: "moon")
    deletedLongAgo.deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    context.insert(deletedLongAgo)

    let deletedRecently = Habit(name: "Recent", symbolName: "sun")
    deletedRecently.deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
    context.insert(deletedRecently)

    let neverDeleted = Habit(name: "Active", symbolName: "leaf")
    context.insert(neverDeleted)

    try context.save()

    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
    let allHabits = try context.fetch(FetchDescriptor<Habit>())
    purgeExpiredDeletions(habits: allHabits, today: today, calendar: testCalendar, modelContext: context)

    let remaining = try context.fetch(FetchDescriptor<Habit>())
    #expect(remaining.count == 2)
    #expect(remaining.contains { $0.name == "Recent" })
    #expect(remaining.contains { $0.name == "Active" })
    #expect(!remaining.contains { $0.name == "Old" })
}

/// Two devices waking on day 31 both run this against their own copy of the
/// same (by then already-synced) state — running it twice must not error or
/// double-delete.
@MainActor
@Test func purgeExpiredDeletionsIsIdempotentWhenRunTwice() throws {
    let context = try makeInMemoryContext()

    let deletedLongAgo = Habit(name: "Old", symbolName: "moon")
    deletedLongAgo.deletedAt = testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    context.insert(deletedLongAgo)
    try context.save()

    let today = testCalendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!

    let firstPass = try context.fetch(FetchDescriptor<Habit>())
    purgeExpiredDeletions(habits: firstPass, today: today, calendar: testCalendar, modelContext: context)

    let secondPass = try context.fetch(FetchDescriptor<Habit>())
    purgeExpiredDeletions(habits: secondPass, today: today, calendar: testCalendar, modelContext: context)

    let remaining = try context.fetch(FetchDescriptor<Habit>())
    #expect(remaining.isEmpty)
}

// MARK: - State transitions (real ModelContext, cascade delete)

@MainActor
@Test func archiveThenRestoreReturnsToActiveWithHistoryIntact() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Read", symbolName: "book")
    context.insert(habit)
    context.insert(LogEvent(habit: habit, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    try context.save()

    archiveHabit(habit, modelContext: context)
    #expect(habit.archivedAt != nil)
    #expect(habit.deletedAt == nil)
    #expect(habit.events.count == 1)

    restoreFromArchive(habit, modelContext: context)
    #expect(habit.archivedAt == nil)
    #expect(habit.events.count == 1)
}

@MainActor
@Test func moveToRecentlyDeletedThenRestoreKeepsEverythingUntilPurge() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Read", symbolName: "book")
    context.insert(habit)
    context.insert(LogEvent(habit: habit, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    try context.save()

    moveToRecentlyDeleted(habit, modelContext: context)
    #expect(habit.deletedAt != nil)

    restoreFromRecentlyDeleted(habit, modelContext: context)
    #expect(habit.deletedAt == nil)

    let remaining = try context.fetch(FetchDescriptor<Habit>())
    #expect(remaining.count == 1)
    #expect(remaining.first?.events.count == 1)
}

@MainActor
@Test func permanentlyDeleteCascadesToEventsAndPauses() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Read", symbolName: "book")
    context.insert(habit)
    context.insert(LogEvent(habit: habit, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    context.insert(Pause(habit: habit, startDay: 20260801, endDay: 20260802, reason: .vacation))
    try context.save()

    permanentlyDelete(habit, modelContext: context)

    #expect(try context.fetch(FetchDescriptor<Habit>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<LogEvent>()).isEmpty)
    #expect(try context.fetch(FetchDescriptor<Pause>()).isEmpty)
}
