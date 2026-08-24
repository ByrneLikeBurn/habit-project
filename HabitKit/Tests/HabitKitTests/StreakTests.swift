import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

// `Habit.createdAt` defaults to `Date()` — real wall-clock now, which is
// always after these fixed test days. Every habit below must pass an
// explicit `createdAt` well before its test's date range, or the walk's
// creation-day bound would cut these fixed-date tests short.
private let habitCreatedAt = date(fromDayKey: 20260701, calendar: testCalendar)

// Tuesday (bit 2, value 4) + Saturday (bit 6, value 64).
private let tuesdaySaturdayMask = 68

@Test func twelveDaysAWeekPausedAndThreeMoreDaysReadsAsFifteenDayRun() {
    // Aug 1–12 logged, Aug 13–19 paused with no log, Aug 20–22 logged.
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let loggedDays = Set((1...12).map { 20260800 + $0 } + [20260820, 20260821, 20260822])
    let pauses = [Pause(startDay: 20260813, endDay: 20260819, reason: .vacation)]

    let streak = streakLength(for: habit, endingOn: 20260822, loggedDays: loggedDays, pauses: pauses, calendar: testCalendar)

    #expect(streak == 15)
}

@Test func loggingTwoOfThePausedDaysIsExtraCreditAndExtendsTheRun() {
    // Same as above, but Aug 15 and Aug 17 — inside the paused week — were logged anyway.
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let loggedDays = Set(
        (1...12).map { 20260800 + $0 } + [20260815, 20260817] + [20260820, 20260821, 20260822]
    )
    let pauses = [Pause(startDay: 20260813, endDay: 20260819, reason: .vacation)]

    let streak = streakLength(for: habit, endingOn: 20260822, loggedDays: loggedDays, pauses: pauses, calendar: testCalendar)

    #expect(streak == 17)
}

@Test func anUnpausedMissedDayBreaksTheRun() {
    // Aug 1–12 logged, Aug 13 missed with no pause in effect — the run before it doesn't count.
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127, createdAt: habitCreatedAt)
    let loggedDays = Set((1...12).map { 20260800 + $0 })

    let streak = streakLength(for: habit, endingOn: 20260814, loggedDays: loggedDays, pauses: [], calendar: testCalendar)

    #expect(streak == 0)
}

// MARK: - Schedule awareness

@Test func runCountsSixOverThreeWeeksOfTuesdaysAndSaturdaysWithoutTheWednesdaysBreakingIt() {
    // Tue 4, Sat 8, Tue 11, Sat 15, Tue 18, Sat 22 — all logged. The
    // Wednesdays (and every other unscheduled day) in between aren't asked
    // of the habit, so they neither break nor extend the run.
    let habit = Habit(name: "Gym", symbolName: "figure.strengthtraining.traditional", scheduleMask: tuesdaySaturdayMask, createdAt: habitCreatedAt)
    let loggedDays: Set<Int> = [20260804, 20260808, 20260811, 20260815, 20260818, 20260822]

    let streak = streakLength(for: habit, endingOn: 20260822, loggedDays: loggedDays, pauses: [], calendar: testCalendar)

    #expect(streak == 6)
}

@Test func missingOneScheduledSaturdayBreaksTheRun() {
    // Same Tue/Sat habit, but Aug 15 (a scheduled Saturday) was never logged.
    let habit = Habit(name: "Gym", symbolName: "figure.strengthtraining.traditional", scheduleMask: tuesdaySaturdayMask, createdAt: habitCreatedAt)
    let loggedDays: Set<Int> = [20260804, 20260808, 20260811, 20260818, 20260822]

    let streak = streakLength(for: habit, endingOn: 20260822, loggedDays: loggedDays, pauses: [], calendar: testCalendar)

    #expect(streak == 2)
}

@Test func loggingOnAnOffScheduleDayIsExtraCreditAndExtendsTheRun() {
    // Tue 4 and Sat 8 are scheduled and logged; Wed 5 isn't scheduled but
    // was logged anyway — extra credit, so it extends the run just like an
    // ordinary logged day.
    let habit = Habit(name: "Gym", symbolName: "figure.strengthtraining.traditional", scheduleMask: tuesdaySaturdayMask, createdAt: habitCreatedAt)
    let loggedDays: Set<Int> = [20260804, 20260805, 20260808]

    let streak = streakLength(for: habit, endingOn: 20260808, loggedDays: loggedDays, pauses: [], calendar: testCalendar)

    #expect(streak == 3)
}

@Test func scheduleMaskZeroReturnsWithoutHanging() {
    // With no day ever scheduled, off-schedule days no longer break the
    // walk — the creation-day bound is what stops it from looping forever.
    let habit = Habit(name: "Someday", symbolName: "circle", scheduleMask: 0, createdAt: date(fromDayKey: 20260815, calendar: testCalendar))

    let streak = streakLength(for: habit, endingOn: 20260822, loggedDays: [], pauses: [], calendar: testCalendar)

    #expect(streak == 0)
}
