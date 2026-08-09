import Testing
import Foundation
@testable import HabitKit

@Test func habitCreatesWithDefaultValues() {
    let habit = Habit(name: "Read", symbolName: "book")

    #expect(habit.name == "Read")
    #expect(habit.symbolName == "book")
    #expect(habit.kind == .binary)
    #expect(habit.target == 1)
    #expect(habit.unit == nil)
    #expect(habit.scheduleMask == 127)
    #expect(habit.sortIndex == 0)
    #expect(habit.isFocus == false)
    #expect(habit.gentleEnabled == false)
    #expect(habit.vacationByDefault == false)
    #expect(habit.tagNickname == nil)
    #expect(habit.archivedAt == nil)
    #expect(habit.deletedAt == nil)
}
