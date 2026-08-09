import Foundation

/// The seven colour-free states a day can render as on the heat map (spec §2).
public enum DayState: Sendable, Equatable {
    case full         // solid — met or exceeded target
    case partial      // hatched — logged, below target
    case missed       // empty outline — scheduled, past, no log
    case paused       // centred dash — no log, but the day is paused
    case extraCredit  // centred diamond — logged on a paused day
    case offSchedule  // blank — not a scheduled day for this habit
    case today        // outlined — scheduled, today, not yet logged
}

/// The state a habit's day should render as, from its logged total, its
/// pauses, and its schedule.
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
) -> DayState {
    let isPaused = pauses.contains { $0.covers(dayKey) }

    if loggedTotal > 0 {
        if isPaused {
            return .extraCredit
        }
        return loggedTotal >= habit.target ? .full : .partial
    }

    if isPaused {
        return .paused
    }

    if !isScheduled(dayKey, mask: habit.scheduleMask, calendar: calendar) {
        return .offSchedule
    }

    if dayKey == todayKey {
        return .today
    }

    return .missed
}

/// `scheduleMask` is a weekday bitmask (127 = daily): bit 0 is Sunday through
/// bit 6 Saturday, matching `Calendar`'s 1-based `weekday` component.
private func isScheduled(_ dayKey: Int, mask: Int, calendar: Calendar) -> Bool {
    let components = DateComponents(year: dayKey / 10_000, month: (dayKey / 100) % 100, day: dayKey % 100)
    guard let date = calendar.date(from: components) else {
        fatalError("Calendar failed to produce a date for dayKey \(dayKey)")
    }
    let weekday = calendar.component(.weekday, from: date)
    return mask & (1 << (weekday - 1)) != 0
}
