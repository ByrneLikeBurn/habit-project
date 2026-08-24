import Foundation

/// The length of the run ending on `lastDay`.
///
/// Walking backward day by day: a logged day extends the run. An unlogged day
/// covered by a `Pause`, or an unlogged day the habit isn't scheduled for,
/// neither breaks nor extends it — a pause and a schedule can each only ever
/// help (invariant 3). An unlogged day *with* a log is extra credit and
/// extends the run just like an ordinary logged day, whether that day was
/// paused, off-schedule, or neither. Any other unlogged day breaks the run.
///
/// The walk never goes earlier than `habit.createdAt` — no run can predate
/// the habit, and without that bound a habit with an empty `scheduleMask`
/// would have no day left that could ever break the loop.
public func streakLength(
    for habit: Habit,
    endingOn lastDay: Int,
    loggedDays: Set<Int>,
    pauses: [Pause],
    calendar: Calendar = .current
) -> Int {
    let createdDayKey = dayKey(for: habit.createdAt, calendar: calendar)
    var day = lastDay
    var count = 0

    while day >= createdDayKey {
        if loggedDays.contains(day) {
            count += 1
        } else if !pauses.contains(where: { $0.covers(day) }) && isScheduled(day, mask: habit.scheduleMask, calendar: calendar) {
            break
        }
        day = previousDayKey(day, calendar: calendar)
    }

    return count
}
