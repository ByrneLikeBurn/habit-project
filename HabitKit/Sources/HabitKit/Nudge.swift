import Foundation

/// The three tones a nudge can be sent in (spec §10). `.silent` carries no
/// text — it exists purely as a delivery style, not a fourth wording.
public enum NudgeTone: String, Sendable, Equatable, CaseIterable {
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

    public var notificationsEnabled: Bool
    public var dailyCap: Int
    public var quietHoursStart: Int // hour, 0-23
    public var quietHoursEnd: Int   // hour, 0-23
    public var skipWhenAlreadyLogged: Bool
    /// Off by default (spec §10) — an explicit opt-in, not an assumption.
    public var mentionMissedDays: Bool

    public init(
        notificationsEnabled: Bool = true,
        dailyCap: Int = 3,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        skipWhenAlreadyLogged: Bool = true,
        mentionMissedDays: Bool = false
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.dailyCap = min(max(dailyCap, 0), Self.dailyCapCeiling)
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.skipWhenAlreadyLogged = skipWhenAlreadyLogged
        self.mentionMissedDays = mentionMissedDays
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
/// a missed day to slip into the copy. This is the path every nudge takes
/// unless `NudgeSettings.mentionMissedDays` is explicitly on, in which case
/// `missedDayAwareNudgeText` takes over instead — this function's guarantee
/// holds by construction precisely because it never gained a history
/// parameter to make that opt-in work. Public so a settings screen can
/// preview it.
public func nudgeText(for habit: Habit, tone: NudgeTone) -> String {
    switch tone {
    case .invitation:
        "A quiet moment for \(habit.name)?"
    case .plain:
        "\(habit.name)."
    case .silent:
        ""
    }
}

/// The opt-in variant used only when `NudgeSettings.mentionMissedDays` is
/// on. States a fact — "Two days since you last logged Read." — never
/// anything implying the day was let go, broken, or missed. Falls back to
/// the plain `nudgeText` wording when there's nothing to report: the habit
/// has never been logged, or was logged today.
///
/// Takes `lastLoggedDayKey` rather than raw `LogEvent`s or a `Set` of every
/// logged day — the caller already knows the most recent one from the
/// habit's history, and that's all this needs.
public func missedDayAwareNudgeText(
    for habit: Habit,
    tone: NudgeTone,
    lastLoggedDayKey: Int?,
    today: Int,
    calendar: Calendar = .current
) -> String {
    guard tone != .silent else { return "" }
    guard let lastLoggedDayKey else { return nudgeText(for: habit, tone: tone) }

    let daysSince = daysBetween(lastLoggedDayKey, today, calendar: calendar)
    guard daysSince > 0 else { return nudgeText(for: habit, tone: tone) }

    let dayWord = daysSince == 1 ? "day" : "days"
    let fact = "\(daysSince) \(dayWord) since you last logged \(habit.name)"

    switch tone {
    case .invitation:
        return "\(fact) — a good moment for it?"
    case .plain:
        return "\(fact)."
    case .silent:
        return ""
    }
}

func daysBetween(_ start: Int, _ end: Int, calendar: Calendar) -> Int {
    calendar.dateComponents(
        [.day],
        from: date(fromDayKey: start, calendar: calendar),
        to: date(fromDayKey: end, calendar: calendar)
    ).day ?? 0
}

/// A deterministic hour, outside quiet hours, to schedule `habit`'s daily
/// nudge at. There's no per-habit nudge-time setting yet (spec's mockups
/// show one; it isn't built), so this is a placeholder: it derives a stable
/// hour from the habit's own id, spreading habits across the day instead of
/// firing them all at once, and always lands outside quiet hours. The same
/// habit always gets the same hour — it's driven by the UUID's bytes
/// directly rather than `hashValue`, which is randomised per process launch
/// and would make the schedule change every time the app restarts.
public func defaultNudgeHour(for habit: Habit, settings: NudgeSettings) -> Int {
    let hours = (0..<24).filter { !isWithinQuietHours(hour: $0, start: settings.quietHoursStart, end: settings.quietHoursEnd) }
    guard !hours.isEmpty else { return settings.quietHoursEnd }

    let bytes = withUnsafeBytes(of: habit.id.uuid) { Array($0) }
    let sum = bytes.reduce(0) { $0 + Int($1) }
    return hours[sum % hours.count]
}

/// Decides whether a nudge should fire for `habit` right now, and if so,
/// what it says. Every constraint from spec §10 is enforced here, not left
/// to whatever calls this:
///
/// - Notifications being off blocks everything, immediately.
/// - A day outside the habit's `scheduleMask` is skipped — nothing nudges
///   for a habit scheduled Tuesdays and Saturdays on a Wednesday.
/// - Paused habits are skipped outright, before anything else is checked.
/// - A habit already at target for `dayKey` is skipped, unless
///   `settings.skipWhenAlreadyLogged` has been turned off.
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
    lastLoggedDayKey: Int? = nil,
    calendar: Calendar = .current
) -> NudgeRequest? {
    guard settings.notificationsEnabled else { return nil }
    guard isScheduled(dayKey, mask: habit.scheduleMask, calendar: calendar) else { return nil }
    guard !pauses.contains(where: { $0.covers(dayKey) }) else { return nil }
    if settings.skipWhenAlreadyLogged {
        guard todayLoggedTotal < habit.target else { return nil }
    }
    guard nudgesAlreadyScheduledToday < settings.dailyCap else { return nil }
    guard !isWithinQuietHours(hour: hour, start: settings.quietHoursStart, end: settings.quietHoursEnd) else { return nil }

    let text = settings.mentionMissedDays
        ? missedDayAwareNudgeText(for: habit, tone: tone, lastLoggedDayKey: lastLoggedDayKey, today: dayKey, calendar: calendar)
        : nudgeText(for: habit, tone: tone)

    return NudgeRequest(
        habitID: habit.id,
        tone: tone,
        text: text,
        interruptionLevel: .passive
    )
}
