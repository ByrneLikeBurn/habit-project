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

// MARK: - wakeHabit

@MainActor
@Test func wakingAGentlePausedHabitClosesItAndTurnsOffGentleEnabled() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    context.insert(habit)
    reconcileGentleMode(isOn: true, habits: [habit], today: 20260815, modelContext: context)
    #expect(habit.pauses.contains { $0.endDay == nil })

    wakeHabit(habit, today: 20260815, modelContext: context)

    #expect(habit.gentleEnabled == false)
    #expect(!habit.pauses.contains { $0.covers(20260815) })
}

@MainActor
@Test func wakingAVacationPausedHabitEndsItEarlyWithoutTouchingGentleEnabled() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Run", symbolName: "figure.run")
    context.insert(habit)
    startVacation(for: [habit], startDay: 20260810, endDay: 20260820, modelContext: context)
    #expect(habit.pauses.contains { $0.covers(20260815) })

    wakeHabit(habit, today: 20260815, modelContext: context)

    #expect(!habit.pauses.contains { $0.covers(20260815) })
    #expect(habit.gentleEnabled == false) // untouched — was never true
}

@MainActor
@Test func wakingAHabitWithNoActivePauseIsANoOp() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Meditate", symbolName: "figure.mind.and.body")
    context.insert(habit)

    wakeHabit(habit, today: 20260815, modelContext: context)

    #expect(habit.pauses.isEmpty)
}

/// A habit can in principle be covered by more than one pause at once (a
/// Gentle pause and an overlapping Vacation pause) — waking it must close
/// every covering pause, not just whichever one is found first.
@MainActor
@Test func wakingAHabitWithOverlappingPausesClosesBoth() throws {
    let context = try makeInMemoryContext()
    let habit = Habit(name: "Stretch", symbolName: "figure.flexibility", gentleEnabled: true)
    context.insert(habit)
    reconcileGentleMode(isOn: true, habits: [habit], today: 20260815, modelContext: context)
    startVacation(for: [habit], startDay: 20260810, endDay: 20260820, modelContext: context)
    #expect(habit.pauses.count == 2)
    #expect(habit.pauses.allSatisfy { $0.covers(20260815) })

    wakeHabit(habit, today: 20260815, modelContext: context)

    #expect(!habit.pauses.contains { $0.covers(20260815) })
    #expect(habit.gentleEnabled == false)
}

// MARK: - todayRestingSummary

@Test func todayRestingSummaryIsNilWhenNothingIsResting() {
    let habit = Habit(name: "Read", symbolName: "book")
    #expect(todayRestingSummary([habit], today: 20260815, calendar: testCalendar) == nil)
}

@Test func todayRestingSummaryNamesGentleModeWhenThatsTheOnlyCause() {
    let habitA = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    habitA.pauses.append(Pause(habit: habitA, startDay: 20260810, endDay: nil, reason: .gentle))
    let habitB = Habit(name: "Walk", symbolName: "figure.walk", gentleEnabled: true)
    habitB.pauses.append(Pause(habit: habitB, startDay: 20260810, endDay: nil, reason: .gentle))

    let summary = todayRestingSummary([habitA, habitB], today: 20260815, calendar: testCalendar)

    #expect(summary == "Gentle Mode is on \u{2014} 2 habits resting")
}

@Test func todayRestingSummaryUsesSingularWordingForOneHabit() {
    let habit = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    habit.pauses.append(Pause(habit: habit, startDay: 20260810, endDay: nil, reason: .gentle))

    let summary = todayRestingSummary([habit], today: 20260815, calendar: testCalendar)

    #expect(summary == "Gentle Mode is on \u{2014} 1 habit resting")
}

@Test func todayRestingSummaryNamesVacationModeAndKeepsTheEndDate() {
    let habit = Habit(name: "Run", symbolName: "figure.run")
    habit.pauses.append(Pause(habit: habit, startDay: 20260810, endDay: 20260820, reason: .vacation))

    let summary = todayRestingSummary([habit], today: 20260815, calendar: testCalendar)

    #expect(summary == "Vacation Mode is on \u{2014} 1 habit resting until 20 August")
}

@Test func todayRestingSummaryNamesBothCausesWhenMixed() {
    let habitA = Habit(name: "Read", symbolName: "book", gentleEnabled: true)
    habitA.pauses.append(Pause(habit: habitA, startDay: 20260810, endDay: nil, reason: .gentle))
    let habitB = Habit(name: "Run", symbolName: "figure.run")
    habitB.pauses.append(Pause(habit: habitB, startDay: 20260810, endDay: 20260820, reason: .vacation))

    let summary = todayRestingSummary([habitA, habitB], today: 20260815, calendar: testCalendar)

    #expect(summary == "2 habits resting \u{2014} Gentle Mode and Vacation Mode are on")
}

@Test func todayRestingSummaryCountsAHabitOnceEvenWithTwoCoveringPauses() {
    let habit = Habit(name: "Stretch", symbolName: "figure.flexibility", gentleEnabled: true)
    habit.pauses.append(Pause(habit: habit, startDay: 20260810, endDay: nil, reason: .gentle))
    habit.pauses.append(Pause(habit: habit, startDay: 20260810, endDay: 20260820, reason: .vacation))

    let summary = todayRestingSummary([habit], today: 20260815, calendar: testCalendar)

    #expect(summary == "1 habit resting \u{2014} Gentle Mode and Vacation Mode are on")
}
