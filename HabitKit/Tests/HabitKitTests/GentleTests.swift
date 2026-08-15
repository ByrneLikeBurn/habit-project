import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

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
