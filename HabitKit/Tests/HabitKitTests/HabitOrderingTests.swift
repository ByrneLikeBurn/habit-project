import Testing
import Foundation
@testable import HabitKit

@Test func habitsCreatedInSequenceKeepTheirOrder() {
    let names = ["Read", "Walk", "Water", "Stretch"]

    var habits: [Habit] = []
    for name in names {
        let habit = Habit(name: name, symbolName: "star", sortIndex: nextSortIndex(after: habits))
        habits.append(habit)
    }

    let sorted = sortedForDisplay(habits)

    #expect(sorted.map(\.name) == names)
}

@Test func manualSortModeMatchesSortedForDisplay() {
    let a = Habit(name: "A", symbolName: "star", sortIndex: 1)
    let b = Habit(name: "B", symbolName: "star", sortIndex: 0)
    let habits = [a, b]

    #expect(sortedHabits(habits, mode: .manual).map(\.name) == sortedForDisplay(habits).map(\.name))
    #expect(sortedHabits(habits, mode: .manual).map(\.name) == ["B", "A"])
}

@Test func byTimeSortModeOrdersByNudgeHour() {
    let evening = Habit(name: "Evening", symbolName: "star", sortIndex: 0, nudgeHour: 20)
    let morning = Habit(name: "Morning", symbolName: "star", sortIndex: 1, nudgeHour: 7)
    let habits = [evening, morning]

    #expect(sortedHabits(habits, mode: .byTime).map(\.name) == ["Morning", "Evening"])
}

@Test func byTimeSortModeBreaksTiesBySortIndex() {
    let first = Habit(name: "First", symbolName: "star", sortIndex: 0, nudgeHour: 9)
    let second = Habit(name: "Second", symbolName: "star", sortIndex: 1, nudgeHour: 9)
    let habits = [second, first]

    #expect(sortedHabits(habits, mode: .byTime).map(\.name) == ["First", "Second"])
}

@Test func smartSortModeIsAStubMatchingByTime() {
    let evening = Habit(name: "Evening", symbolName: "star", sortIndex: 0, nudgeHour: 20)
    let morning = Habit(name: "Morning", symbolName: "star", sortIndex: 1, nudgeHour: 7)
    let habits = [evening, morning]

    #expect(sortedHabits(habits, mode: .smart).map(\.name) == sortedHabits(habits, mode: .byTime).map(\.name))
}
