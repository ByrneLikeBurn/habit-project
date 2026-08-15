import Foundation
import SwiftData

/// Keeps `Pause` records for Gentle Mode in sync with the global switch and
/// each habit's `gentleEnabled` flag (spec §6). Call after either changes.
///
/// A flagged habit gets (or keeps) an open-ended `.gentle` pause while the
/// switch is on; anything else has its open `.gentle` pause closed as of
/// yesterday — today stops being paused immediately, but already-passed
/// paused days stay paused in history rather than becoming retroactively
/// missed. "Turn a habit's checkbox on or off any time — the switch just
/// obeys it," so this is safe to call from a single-habit toggle too by
/// passing just that one habit.
public func reconcileGentleMode(
    isOn: Bool,
    habits: [Habit],
    today: Int = dayKey(for: Date()),
    modelContext: ModelContext
) {
    for habit in habits {
        let openPause = habit.pauses.first { $0.reason == .gentle && $0.endDay == nil }
        let shouldRest = isOn && habit.gentleEnabled

        if shouldRest, openPause == nil {
            modelContext.insert(Pause(habit: habit, startDay: today, endDay: nil, reason: .gentle))
        } else if !shouldRest, let openPause {
            openPause.endDay = previousDayKey(today)
        }
    }
    try? modelContext.save()
}

/// Whether Gentle Mode has been continuously on for 14 days or more — the
/// trigger for the one quiet, dismissible line under the Today header
/// (spec §6's safeguard against an open-ended pause silently running for
/// months). `startedAtDayKey` of `0` means Gentle Mode isn't on.
public func gentleModeHasBeenOnForTwoWeeks(startedAtDayKey: Int, today: Int, calendar: Calendar = .current) -> Bool {
    guard startedAtDayKey > 0 else { return false }
    let days = calendar.dateComponents(
        [.day],
        from: date(fromDayKey: startedAtDayKey, calendar: calendar),
        to: date(fromDayKey: today, calendar: calendar)
    ).day ?? 0
    return days >= 14
}
