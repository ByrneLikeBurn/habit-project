import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

@Test func twelveDaysAWeekPausedAndThreeMoreDaysReadsAsFifteenDayRun() {
    // Aug 1–12 logged, Aug 13–19 paused with no log, Aug 20–22 logged.
    let loggedDays = Set((1...12).map { 20260800 + $0 } + [20260820, 20260821, 20260822])
    let pauses = [Pause(startDay: 20260813, endDay: 20260819, reason: .vacation)]

    let streak = streakLength(endingOn: 20260822, loggedDays: loggedDays, pauses: pauses, calendar: testCalendar)

    #expect(streak == 15)
}

@Test func loggingTwoOfThePausedDaysIsExtraCreditAndExtendsTheRun() {
    // Same as above, but Aug 15 and Aug 17 — inside the paused week — were logged anyway.
    let loggedDays = Set(
        (1...12).map { 20260800 + $0 } + [20260815, 20260817] + [20260820, 20260821, 20260822]
    )
    let pauses = [Pause(startDay: 20260813, endDay: 20260819, reason: .vacation)]

    let streak = streakLength(endingOn: 20260822, loggedDays: loggedDays, pauses: pauses, calendar: testCalendar)

    #expect(streak == 17)
}

@Test func anUnpausedMissedDayBreaksTheRun() {
    // Aug 1–12 logged, Aug 13 missed with no pause in effect — the run before it doesn't count.
    let loggedDays = Set((1...12).map { 20260800 + $0 })

    let streak = streakLength(endingOn: 20260814, loggedDays: loggedDays, pauses: [], calendar: testCalendar)

    #expect(streak == 0)
}
