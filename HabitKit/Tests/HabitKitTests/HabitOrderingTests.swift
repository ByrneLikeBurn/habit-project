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

    let sorted = habits.sorted { lhs, rhs in
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.createdAt < rhs.createdAt
    }

    #expect(sorted.map(\.name) == names)
}
