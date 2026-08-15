import Foundation

/// The seven colour-free states a day can render as on the heat map (spec §2).
///
/// "Today" is deliberately not a case here — the mockups show today's cell
/// as whatever state applies (full, partial, ...) *plus* an outline, e.g. an
/// outlined-and-hatched cell for a partially-logged today. See `isToday` on
/// `dayState(for:on:loggedTotal:pauses:today:calendar:)`.
public enum DayState: Sendable, Equatable {
    case full         // solid — met or exceeded target
    case partial      // hatched — logged, below target
    case missed       // empty outline — scheduled, past, no log
    case paused       // centred dash — no log, but the day is paused
    case extraCredit  // centred diamond — logged on a paused day
    case offSchedule  // blank — not a scheduled day for this habit
    case future       // dashed empty outline, reduced opacity — hasn't happened yet
}

/// The state a habit's day should render as, from its logged total, its
/// pauses, and its schedule — plus whether that day is today, which the
/// heat map draws as an outline on top of the state rather than a state
/// of its own.
///
/// `loggedTotal` is the sum of that day's `LogEvent.delta`s — callers derive
/// it themselves, since day totals are never stored (spec §3). A log on a
/// paused day is extra credit regardless of amount; it never falls back to
/// full/partial, because the diamond is the point (spec §2).
public func dayState(
    for habit: Habit,
    on dayKey: Int,
    loggedTotal: Int,
    pauses: [Pause],
    today todayKey: Int,
    calendar: Calendar = .current
) -> (state: DayState, isToday: Bool) {
    // A day that hasn't happened yet can't have been missed (invariant 1) —
    // it's future regardless of schedule, pause, or anything else.
    if dayKey > todayKey {
        return (.future, false)
    }

    let isPaused = pauses.contains { $0.covers(dayKey) }

    let state: DayState
    if loggedTotal > 0 {
        if isPaused {
            state = .extraCredit
        } else {
            state = loggedTotal >= habit.target ? .full : .partial
        }
    } else if isPaused {
        state = .paused
    } else if !isScheduled(dayKey, mask: habit.scheduleMask, calendar: calendar) {
        state = .offSchedule
    } else {
        state = .missed
    }

    return (state, dayKey == todayKey)
}

/// `scheduleMask` is a weekday bitmask (127 = daily): bit 0 is Sunday through
/// bit 6 Saturday, matching `Calendar`'s 1-based `weekday` component.
func isScheduled(_ dayKey: Int, mask: Int, calendar: Calendar) -> Bool {
    let weekday = calendar.component(.weekday, from: date(fromDayKey: dayKey, calendar: calendar))
    return mask & (1 << (weekday - 1)) != 0
}
