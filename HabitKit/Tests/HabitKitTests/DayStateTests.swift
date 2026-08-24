import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let day = 20260801     // some day in the past
private let today = 20260808   // "today" for these tests

// `Habit.createdAt` defaults to `Date()` — real wall-clock now, which is
// always after these fixed test days. Every habit below must pass an
// explicit `createdAt` well before `day`, or dayState()'s pre-creation
// check would blank out these tests' fixed dates regardless of intent.
private let habitCreatedAt = date(fromDayKey: 20260601, calendar: testCalendar)

@Test func fullWhenLoggedTotalMeetsTarget() {
    let habit = Habit(name: "Read", symbolName: "book", kind: .binary, target: 1, scheduleMask: 127, createdAt: habitCreatedAt)

    let result = dayState(for: habit, on: day, loggedTotal: 1, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .full)
    #expect(result.isToday == false)
}

@Test func partialWhenLoggedTotalIsBelowTarget() {
    let habit = Habit(name: "Water", symbolName: "drop", kind: .counted, target: 8, scheduleMask: 127, createdAt: habitCreatedAt)

    let result = dayState(for: habit, on: day, loggedTotal: 3, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .partial)
    #expect(result.isToday == false)
}

@Test func missedWhenScheduledPastAndUnlogged() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)

    let result = dayState(for: habit, on: day, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .missed)
    #expect(result.isToday == false)
}

@Test func pausedWhenUnloggedAndCoveredByAPause() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let pauses = [Pause(startDay: 20260730, endDay: 20260802, reason: .vacation)]

    let result = dayState(for: habit, on: day, loggedTotal: 0, pauses: pauses, today: today, calendar: testCalendar)

    #expect(result.state == .paused)
    #expect(result.isToday == false)
}

@Test func extraCreditWhenLoggedOnAPausedDay() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let pauses = [Pause(startDay: 20260730, endDay: 20260802, reason: .vacation)]

    let result = dayState(for: habit, on: day, loggedTotal: 1, pauses: pauses, today: today, calendar: testCalendar)

    #expect(result.state == .extraCredit)
    #expect(result.isToday == false)
}

@Test func offScheduleWhenNotAScheduledDay() {
    let habit = Habit(name: "Weigh in", symbolName: "scalemass", scheduleMask: 0, createdAt: habitCreatedAt) // never scheduled

    let result = dayState(for: habit, on: day, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .offSchedule)
    #expect(result.isToday == false)
}

@Test func todayIsAFlagAlongsideWhateverStateApplies() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)

    let result = dayState(for: habit, on: today, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .missed)
    #expect(result.isToday == true)
}

@Test func futureWhenDayIsAfterToday() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let tomorrow = 20260809

    let result = dayState(for: habit, on: tomorrow, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .future)
    #expect(result.isToday == false)
}

@Test func todayCanBePartialAndOutlinedSimultaneously() {
    // The mockups show today's cell as outlined *and* hatched — the overlay
    // combines with whatever state applies, rather than replacing it.
    let habit = Habit(name: "Water", symbolName: "drop", kind: .counted, target: 8, scheduleMask: 127, createdAt: habitCreatedAt)

    let result = dayState(for: habit, on: today, loggedTotal: 3, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .partial)
    #expect(result.isToday == true)
}

// MARK: - Days before the habit existed (invariant 1)

@Test func offScheduleWhenDayIsBeforeHabitWasCreated() {
    let createdAt = date(fromDayKey: 20260805, calendar: testCalendar)
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: createdAt)

    let result = dayState(for: habit, on: 20260803, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .offSchedule)
    #expect(result.isToday == false)
}

@Test func loggedDayBeforeCreatedAtStillRendersFromTheLog() {
    // Import gives the habit a createdAt of the import date, but its
    // LogEvents keep their original dayKeys — a logged day always renders
    // from the log, regardless of createdAt.
    let createdAt = date(fromDayKey: 20260805, calendar: testCalendar)
    let habit = Habit(name: "Run", symbolName: "figure.run", target: 1, scheduleMask: 127, createdAt: createdAt)

    let result = dayState(for: habit, on: 20260803, loggedTotal: 1, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .full)
    #expect(result.isToday == false)
}

@Test func createdAtDayItselfRendersNormally() {
    let createdAt = date(fromDayKey: 20260805, calendar: testCalendar)
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: createdAt)

    let result = dayState(for: habit, on: 20260805, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .missed)
    #expect(result.isToday == false)
}

@Test func dayAfterCreatedAtIsUnchangedFromCurrentBehaviour() {
    let createdAt = date(fromDayKey: 20260805, calendar: testCalendar)
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: createdAt)

    let result = dayState(for: habit, on: 20260806, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(result.state == .missed)
    #expect(result.isToday == false)
}
