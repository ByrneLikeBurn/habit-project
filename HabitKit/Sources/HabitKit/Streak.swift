import Foundation

/// The length of the run ending on `lastDay`.
///
/// Walking backward day by day: a logged day extends the run. An unlogged day
/// covered by a `Pause` neither breaks nor extends it — pausing can only ever
/// help. An unlogged day *with* a log is extra credit and extends the run just
/// like an ordinary logged day. Any other unlogged day breaks the run.
public func streakLength(
    endingOn lastDay: Int,
    loggedDays: Set<Int>,
    pauses: [Pause],
    calendar: Calendar = .current
) -> Int {
    var day = lastDay
    var count = 0

    while true {
        if loggedDays.contains(day) {
            count += 1
        } else if !pauses.contains(where: { $0.covers(day) }) {
            break
        }
        day = previousDayKey(day, calendar: calendar)
    }

    return count
}
