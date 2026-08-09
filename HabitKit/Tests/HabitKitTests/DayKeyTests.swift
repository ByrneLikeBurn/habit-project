import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Test func threeAMLandsOnPreviousDay() {
    let threeAM = date(2026, 8, 1, 3)
    #expect(dayKey(for: threeAM, calendar: testCalendar) == 20260731)
}

@Test func fiveAMLandsOnCurrentDay() {
    let fiveAM = date(2026, 8, 1, 5)
    #expect(dayKey(for: fiveAM, calendar: testCalendar) == 20260801)
}

@Test func midnightExactlyLandsOnPreviousDay() {
    let midnight = date(2026, 8, 1, 0)
    #expect(dayKey(for: midnight, calendar: testCalendar) == 20260731)
}
