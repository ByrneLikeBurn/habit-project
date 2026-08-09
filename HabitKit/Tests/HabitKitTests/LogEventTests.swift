import Testing
import Foundation
@testable import HabitKit

@Test func summingDeltasForDayKeyGivesTotal() {
    let habit = Habit(name: "Push-ups", symbolName: "figure.strengthtraining.traditional")
    let today = 20260801
    let yesterday = 20260731

    let events = [
        LogEvent(habit: habit, dayKey: today, delta: 1, source: .manual, deviceID: "iphone"),
        LogEvent(habit: habit, dayKey: today, delta: 1, source: .widget, deviceID: "iphone"),
        LogEvent(habit: habit, dayKey: today, delta: -1, source: .manual, deviceID: "watch"),
        LogEvent(habit: habit, dayKey: yesterday, delta: 1, source: .manual, deviceID: "iphone"),
    ]

    let total = events
        .filter { $0.dayKey == today }
        .reduce(0) { $0 + $1.delta }

    #expect(total == 1)
}
