import Foundation
import SwiftData

/// Starts Vacation Mode for the given habits: one dated `Pause` per habit,
/// covering `startDay` through `endDay` inclusive (spec §6).
///
/// It "resumes itself" with no scheduled job and nothing to undo — once a
/// day is past `endDay`, `Pause.covers(_:)` simply stops returning true for
/// it, and the habit reads as unpaused again on its own.
public func startVacation(
    for habits: [Habit],
    startDay: Int = dayKey(for: Date()),
    endDay: Int,
    modelContext: ModelContext
) {
    for habit in habits {
        let pause = Pause(habit: habit, startDay: startDay, endDay: endDay, reason: .vacation)
        modelContext.insert(pause)
    }
    try? modelContext.save()
}
