import Testing
import Foundation
@testable import HabitKit

@Test func datedPauseCoversDaysInsideItsRange() {
    let habit = Habit(name: "Run", symbolName: "figure.run")
    let pause = Pause(habit: habit, startDay: 20260801, endDay: 20260808, reason: .vacation)

    #expect(pause.covers(20260801) == true)
    #expect(pause.covers(20260804) == true)
    #expect(pause.covers(20260808) == true)
}

@Test func datedPauseDoesNotCoverDaysOutsideItsRange() {
    let habit = Habit(name: "Run", symbolName: "figure.run")
    let pause = Pause(habit: habit, startDay: 20260801, endDay: 20260808, reason: .vacation)

    #expect(pause.covers(20260731) == false)
    #expect(pause.covers(20260809) == false)
}

@Test func openEndedPauseCoversEverythingFromStartDayOnward() {
    let habit = Habit(name: "Run", symbolName: "figure.run")
    let pause = Pause(habit: habit, startDay: 20260801, endDay: nil, reason: .gentle)

    #expect(pause.covers(20260731) == false)
    #expect(pause.covers(20260801) == true)
    #expect(pause.covers(20270101) == true)
}
