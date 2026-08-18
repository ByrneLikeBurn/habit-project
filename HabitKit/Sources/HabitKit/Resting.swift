import Foundation
import SwiftData

/// The direct, per-habit escape hatch a "Resting" list needs: end whichever
/// pause(s) currently cover `today` for this one habit, independent of
/// whatever the broader Gentle Mode switch or Vacation Mode flow thinks its
/// own state is. A habit can in principle have more than one covering pause
/// at once (e.g. a Gentle pause and an overlapping Vacation pause), so every
/// covering pause is closed, not just the first found.
///
/// For a `.gentle` pause this also turns off the habit's own `gentleEnabled`
/// flag — closing the pause alone would leave it true, and the next time
/// anything reconciles Gentle Mode (even for a different habit) this one
/// would immediately re-pause.
public func wakeHabit(_ habit: Habit, today: Int = dayKey(for: Date()), modelContext: ModelContext) {
    let coveringPauses = habit.pauses.filter { $0.covers(today) }
    guard !coveringPauses.isEmpty else { return }

    for pause in coveringPauses {
        if pause.reason == .gentle {
            habit.gentleEnabled = false
        }
        pause.endDay = previousDayKey(today)
    }
    try? modelContext.save()
}

/// The Today header's resting line (spec §6) — names the cause rather than
/// just the count, e.g. "Gentle Mode is on — 3 habits resting" instead of
/// the old "3 resting until 20 August", which said nothing about *why* and
/// made a stuck pause look identical to an intentional one. Counts distinct
/// habits, not pause records, so a habit covered by two pauses at once still
/// counts once.
public func todayRestingSummary(_ habits: [Habit], today: Int = dayKey(for: Date()), calendar: Calendar = .current) -> String? {
    let restingHabits = habits.filter { habit in habit.pauses.contains { $0.covers(today) } }
    guard !restingHabits.isEmpty else { return nil }

    let coveringPauses = restingHabits.flatMap { habit in habit.pauses.filter { $0.covers(today) } }
    let hasGentle = coveringPauses.contains { $0.reason == .gentle }
    let hasVacation = coveringPauses.contains { $0.reason == .vacation }
    let latestVacationEndDay = coveringPauses
        .filter { $0.reason == .vacation }
        .compactMap(\.endDay)
        .max()

    let total = restingHabits.count
    let habitWord = total == 1 ? "habit" : "habits"

    switch (hasGentle, hasVacation) {
    case (true, false):
        return "Gentle Mode is on \u{2014} \(total) \(habitWord) resting"
    case (false, true):
        return "Vacation Mode is on \u{2014} \(total) \(habitWord) resting\(untilSuffix(latestVacationEndDay, calendar: calendar))"
    case (true, true):
        return "\(total) \(habitWord) resting \u{2014} Gentle Mode and Vacation Mode are on"
    case (false, false):
        // Only `.manual`-reason pauses, which nothing in the app creates
        // yet — a generic fallback rather than naming a mode that isn't real.
        return "\(total) \(habitWord) resting"
    }
}

private func untilSuffix(_ endDay: Int?, calendar: Calendar) -> String {
    guard let endDay else { return "" }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    // `.calendar` alone doesn't set the rendering time zone — DateFormatter
    // falls back to the system's local zone for that, which can shift the
    // formatted day backward by one relative to a date built in `calendar`.
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "d MMMM"
    return " until \(formatter.string(from: date(fromDayKey: endDay, calendar: calendar)))"
}
