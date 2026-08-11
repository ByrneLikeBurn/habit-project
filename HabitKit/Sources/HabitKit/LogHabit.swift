import Foundation
import SwiftData

/// A stable per-install identifier, used to attribute `LogEvent`s to the
/// device that wrote them (spec §3's `deviceID`).
public enum DeviceIdentity {
    private static let defaultsKey = "HabitKit.deviceID"

    public static var current: String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
    }
}

/// The single path every `LogEvent` in the system is written through (the
/// "one write path" invariant). The widget button, Shortcuts/NFC, Control
/// Centre, the Action button, Siri and in-app taps must all route through
/// this — today directly, and later through `LogHabitIntent` calling this
/// in turn, rather than constructing `LogEvent`s themselves.
public func logHabit(
    _ habit: Habit,
    delta: Int,
    source: LogSource,
    dayKey: Int = dayKey(for: Date()),
    deviceID: String = DeviceIdentity.current,
    modelContext: ModelContext
) {
    let event = LogEvent(habit: habit, dayKey: dayKey, delta: delta, source: source, deviceID: deviceID)
    modelContext.insert(event)
    try? modelContext.save()
}

/// The delta to write so that today's total lands exactly on `target` (to
/// complete a habit) or exactly on `0` (to clear it) — regardless of
/// whatever total logging had already accumulated to. Still append-only:
/// this is just one carefully-sized `LogEvent.delta`, not a rewrite of
/// history. Used for a simple toggle tap.
public func toggleDelta(currentTotal: Int, target: Int) -> Int {
    currentTotal >= target ? -currentTotal : target - currentTotal
}
