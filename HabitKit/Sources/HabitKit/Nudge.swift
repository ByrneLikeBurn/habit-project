import Foundation

/// The three tones a nudge can be sent in (spec §10). `.silent` carries no
/// text — it exists purely as a delivery style, not a fourth wording.
public enum NudgeTone: Sendable, Equatable {
    case invitation
    case plain
    case silent
}

/// Every nudge is `.passive` (spec §10) — it can never light up the screen.
/// Kept as our own type rather than importing UserNotifications, since the
/// engine only decides *what* should be sent, not how to hand it to the OS.
public enum NudgeInterruptionLevel: Sendable, Equatable {
    case passive
}

/// Global nudge limits (spec §10's Nudges settings screen). `dailyCap` is
/// clamped to the 1–6 range at construction — 6 is a hard ceiling, not a
/// suggestion, so it can't be configured away.
public struct NudgeSettings: Sendable, Equatable {
    public static let dailyCapCeiling = 6

    public var dailyCap: Int
    public var quietHoursStart: Int // hour, 0-23
    public var quietHoursEnd: Int   // hour, 0-23

    public init(dailyCap: Int = 3, quietHoursStart: Int = 22, quietHoursEnd: Int = 8) {
        self.dailyCap = min(max(dailyCap, 0), Self.dailyCapCeiling)
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }
}

/// A single nudge the engine has decided should go out.
public struct NudgeRequest: Sendable, Equatable {
    public let habitID: UUID
    public let tone: NudgeTone
    public let text: String
    public let interruptionLevel: NudgeInterruptionLevel
}

/// Whether `hour` falls inside a quiet-hours window that may wrap midnight
/// (the default, 22:00–08:00, does).
func isWithinQuietHours(hour: Int, start: Int, end: Int) -> Bool {
    guard start != end else { return false }
    if start < end {
        return hour >= start && hour < end
    }
    return hour >= start || hour < end
}

/// The wording for a tone. Deliberately a pure function of `(habit, tone)`
/// alone — no day count, no streak, no history — so there is no way for a
/// habit's first day and its hundredth to read differently, and no way for
/// a missed day to slip into the copy, opted in or not.
func nudgeText(for habit: Habit, tone: NudgeTone) -> String {
    switch tone {
    case .invitation:
        "A quiet moment for \(habit.name)?"
    case .plain:
        "\(habit.name)."
    case .silent:
        ""
    }
}

/// Decides whether a nudge should fire for `habit` right now, and if so,
/// what it says. Every constraint from spec §10 is enforced here, not left
/// to whatever calls this:
///
/// - A day outside the habit's `scheduleMask` is skipped — nothing nudges
///   for a habit scheduled Tuesdays and Saturdays on a Wednesday.
/// - Paused habits are skipped outright, before anything else is checked.
/// - A habit already at target for `dayKey` is skipped.
/// - The hard daily cap (`settings.dailyCap`, itself clamped to at most 6)
///   blocks any nudge once `nudgesAlreadyScheduledToday` reaches it.
/// - Quiet hours block delivery regardless of the other checks passing.
/// - The returned request is always `.passive`.
public func nudge(
    for habit: Habit,
    on dayKey: Int,
    hour: Int,
    todayLoggedTotal: Int,
    pauses: [Pause],
    nudgesAlreadyScheduledToday: Int,
    tone: NudgeTone = .plain,
    settings: NudgeSettings = NudgeSettings(),
    calendar: Calendar = .current
) -> NudgeRequest? {
    guard isScheduled(dayKey, mask: habit.scheduleMask, calendar: calendar) else { return nil }
    guard !pauses.contains(where: { $0.covers(dayKey) }) else { return nil }
    guard todayLoggedTotal < habit.target else { return nil }
    guard nudgesAlreadyScheduledToday < settings.dailyCap else { return nil }
    guard !isWithinQuietHours(hour: hour, start: settings.quietHoursStart, end: settings.quietHoursEnd) else { return nil }

    return NudgeRequest(
        habitID: habit.id,
        tone: tone,
        text: nudgeText(for: habit, tone: tone),
        interruptionLevel: .passive
    )
}
