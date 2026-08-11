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
