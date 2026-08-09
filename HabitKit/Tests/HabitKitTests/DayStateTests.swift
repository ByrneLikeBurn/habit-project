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

@Test func fullWhenLoggedTotalMeetsTarget() {
    let habit = Habit(name: "Read", symbolName: "book", kind: .binary, target: 1, scheduleMask: 127)

    let state = dayState(for: habit, on: day, loggedTotal: 1, pauses: [], today: today, calendar: testCalendar)

    #expect(state == .full)
}

@Test func partialWhenLoggedTotalIsBelowTarget() {
    let habit = Habit(name: "Water", symbolName: "drop", kind: .counted, target: 8, scheduleMask: 127)

    let state = dayState(for: habit, on: day, loggedTotal: 3, pauses: [], today: today, calendar: testCalendar)

    #expect(state == .partial)
}

@Test func missedWhenScheduledPastAndUnlogged() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127)

    let state = dayState(for: habit, on: day, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(state == .missed)
}

@Test func pausedWhenUnloggedAndCoveredByAPause() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127)
    let pauses = [Pause(startDay: 20260730, endDay: 20260802, reason: .vacation)]

    let state = dayState(for: habit, on: day, loggedTotal: 0, pauses: pauses, today: today, calendar: testCalendar)

    #expect(state == .paused)
}

@Test func extraCreditWhenLoggedOnAPausedDay() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127)
    let pauses = [Pause(startDay: 20260730, endDay: 20260802, reason: .vacation)]

    let state = dayState(for: habit, on: day, loggedTotal: 1, pauses: pauses, today: today, calendar: testCalendar)

    #expect(state == .extraCredit)
}

@Test func offScheduleWhenNotAScheduledDay() {
    let habit = Habit(name: "Weigh in", symbolName: "scalemass", scheduleMask: 0) // never scheduled

    let state = dayState(for: habit, on: day, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(state == .offSchedule)
}

@Test func todayWhenScheduledAndUnloggedOnTheCurrentDay() {
    let habit = Habit(name: "Run", symbolName: "figure.run", scheduleMask: 127)

    let state = dayState(for: habit, on: today, loggedTotal: 0, pauses: [], today: today, calendar: testCalendar)

    #expect(state == .today)
}
