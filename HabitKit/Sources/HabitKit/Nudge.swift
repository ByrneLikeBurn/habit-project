import Foundation

/// The seven tones a nudge can be sent in (spec §10, "Nudge wording"). There
/// is no silent tone — Quiet Hours or notifications-off is what produces
/// silence; see spec §10's "Silence is Quiet Hours, or notifications off."
public enum NudgeTone: String, Sendable, Equatable, CaseIterable {
    case invitation
    case plain
    case encouraging
    case playful
    case contextual
    case identity
    case bare
}

/// A habit's stored `nudgePhrase`, parsed. `nudgePhrase == nil` (or empty)
/// means `.followsAppTone` — the habit has no wording of its own and shows
/// whatever the app tone resolves to. Any string that doesn't parse also
/// falls back to `.followsAppTone` rather than trapping, because this value
/// syncs between devices and a future OS or a partial write can hand this
/// code a string it doesn't recognise.
public enum NudgeWordingChoice: Sendable, Equatable {
    case followsAppTone
    case phrase(NudgeTone, Int)
    case vary(NudgeTone?)
    case custom(String)

    /// `"playful.2"` → `.phrase(.playful, 1)` (the stored index is 1-based,
    /// the array below is 0-based). `"vary"` → `.vary(nil)`, rotating within
    /// whatever tone is in force. `"playful.vary"` → `.vary(.playful)`,
    /// rotating within Playful regardless of the app tone. `"custom"` reads
    /// `habit.nudgeText` for the actual words.
    public init(habit: Habit) {
        guard let raw = habit.nudgePhrase, !raw.isEmpty else {
            self = .followsAppTone
            return
        }
        if raw == "custom" {
            self = .custom(habit.nudgeText ?? "")
            return
        }
        if raw == "vary" {
            self = .vary(nil)
            return
        }
        let parts = raw.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let tone = NudgeTone(rawValue: String(parts[0])) else {
            self = .followsAppTone
            return
        }
        if parts[1] == "vary" {
            self = .vary(tone)
            return
        }
        guard let oneBasedIndex = Int(parts[1]), oneBasedIndex >= 1 else {
            self = .followsAppTone
            return
        }
        self = .phrase(tone, oneBasedIndex - 1)
    }
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

/// A single nudge the engine has decided should go out. `tone` is whatever
/// tone actually got resolved for this habit — its own locked choice, the
/// app tone, or the Invitation default — not necessarily the app tone the
/// caller passed in.
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

/// One phrase per tone, taken verbatim or templated from spec §284's own
/// examples — `%@` stands in for the habit's name, matching the pattern
/// Invitation, Plain and Contextual are built from in the spec text itself.
/// A later change writes the full banks; this one keeps the shape (an array
/// that can grow) with a single entry so nothing downstream has to change
/// shape when it does. `.bare` has no bank — its wording is derived, not
/// picked, so its array is empty and never indexed.
private func phraseBank(for tone: NudgeTone) -> [String] {
    switch tone {
    case .invitation:
        return ["A quiet moment for %@?"]
    case .plain:
        return ["%@."]
    case .encouraging:
        return ["Ten quiet minutes is a good gift to yourself."]
    case .playful:
        return ["The cushion is not going to sit on itself."]
    case .contextual:
        return ["Morning, before email. %@."]
    case .identity:
        return ["You're someone who takes ten quiet minutes."]
    case .bare:
        return []
    }
}

/// `.bare` is the name and its descriptor with no sentence around it
/// ("Read · 20 pages"), falling back to the formatted target when the habit
/// has no descriptor, and to the nudge time for a binary habit with neither
/// (spec §284). A binary habit's target is always 1 with no unit, so it has
/// no formatted target worth showing — only a counted habit's target ever
/// reaches the second fallback.
private func bareText(for habit: Habit) -> String {
    if let descriptor = habit.descriptor, !descriptor.isEmpty {
        return "\(habit.name) \u{00B7} \(descriptor)"
    }
    if habit.kind == .counted {
        let target = habit.unit.map { unit in "\(habit.target) \(unit)" } ?? "\(habit.target)"
        return "\(habit.name) \u{00B7} \(target)"
    }
    return "\(habit.name) \u{00B7} \(String(format: "%02d:00", habit.nudgeHour))"
}

/// Selects one phrase from `tone`'s bank. `rotate` picks by `dayKey % bank.count`
/// — the whole of *vary*'s logic, reading the day key and nothing else: no
/// streak, no log count, no history. Otherwise `index` is used if it lands
/// inside the bank, falling back to index 0 if it doesn't (a phrase can be
/// picked while a bank is longer, then the bank shrinks under it).
private func phraseText(tone: NudgeTone, habit: Habit, dayKey: Int, index: Int?, rotate: Bool) -> String {
    if tone == .bare {
        return bareText(for: habit)
    }
    let bank = phraseBank(for: tone)
    guard !bank.isEmpty else { return "" }
    let chosenIndex: Int
    if rotate {
        chosenIndex = dayKey % bank.count
    } else if let index, bank.indices.contains(index) {
        chosenIndex = index
    } else {
        chosenIndex = 0
    }
    return String(format: bank[chosenIndex], habit.name)
}

/// Whether `choice` is wording the habit picked for itself, as opposed to
/// wording it merely falls into by default. `.vary(nil)` doesn't count —
/// with no locked tone it already tracks the app tone like `.followsAppTone`
/// does, so keeping it here would duplicate `resolveWording`'s two branches
/// for a case where they behave identically.
private func isOwnLockedWording(_ choice: NudgeWordingChoice) -> Bool {
    switch choice {
    case .phrase:
        return true
    case .vary(let tone):
        return tone != nil
    case .custom(let text):
        return !text.isEmpty
    case .followsAppTone:
        return false
    }
}

/// Turns a single, already-decided `NudgeWordingChoice` into a tone and
/// text, with no more resolution logic — the app-tone-vs-own-wording
/// decision has already been made by the time this runs.
private func applyChoice(_ choice: NudgeWordingChoice, habit: Habit, appTone: NudgeTone?, dayKey: Int) -> (tone: NudgeTone, text: String) {
    switch choice {
    case .custom(let text) where !text.isEmpty:
        return (appTone ?? .invitation, text)
    case .phrase(let tone, let index):
        return (tone, phraseText(tone: tone, habit: habit, dayKey: dayKey, index: index, rotate: false))
    case .vary(let lockedTone):
        let tone = lockedTone ?? appTone ?? .invitation
        return (tone, phraseText(tone: tone, habit: habit, dayKey: dayKey, index: nil, rotate: true))
    case .custom, .followsAppTone:
        let tone = appTone ?? .invitation
        return (tone, phraseText(tone: tone, habit: habit, dayKey: dayKey, index: nil, rotate: false))
    }
}

/// Resolution order (spec §284's "The app tone is a temporary override."):
/// a habit with `keepWordingOnToneChange` true and wording of its own says
/// that wording whatever the app tone is; a habit with it false resolves as
/// though it had no wording of its own for as long as an app tone is set; a
/// habit with no wording of its own uses the app tone, or Invitation when
/// none is set.
private func resolveWording(for habit: Habit, appTone: NudgeTone?, dayKey: Int) -> (tone: NudgeTone, text: String) {
    let choice = NudgeWordingChoice(habit: habit)
    guard isOwnLockedWording(choice) else {
        return applyChoice(choice, habit: habit, appTone: appTone, dayKey: dayKey)
    }
    guard !habit.keepWordingOnToneChange, appTone != nil else {
        return applyChoice(choice, habit: habit, appTone: appTone, dayKey: dayKey)
    }
    return applyChoice(.followsAppTone, habit: habit, appTone: appTone, dayKey: dayKey)
}

/// The wording for `habit` right now. A pure function of `(habit, appTone,
/// dayKey)` alone — no streak, no log count, no history — so a habit's
/// first day and its hundredth read alike unless it chose *vary it*, which
/// rotates on `dayKey` alone. This is the path every nudge takes unless
/// `NudgeSettings.mentionMissedDays` is explicitly on, in which case
/// `missedDayAwareNudgeText` takes over instead. Public so a settings
/// screen can preview it.
public func nudgeWording(for habit: Habit, appTone: NudgeTone?, dayKey: Int) -> String {
    resolveWording(for: habit, appTone: appTone, dayKey: dayKey).text
}

/// Invitation and Plain keep the wording `missedDayAwareNudgeText` has
/// always used. The five newer tones temporarily reuse Plain's — a later
/// change writes their own.
private func missedDayTemplate(for tone: NudgeTone) -> String {
    switch tone {
    case .invitation:
        return "%@ — a good moment for it?"
    case .plain, .encouraging, .playful, .contextual, .identity, .bare:
        return "%@."
    }
}

/// The opt-in variant used only when `NudgeSettings.mentionMissedDays` is
/// on. States a fact — "Two days since you last logged Read." — never
/// anything implying the day was let go, broken, or missed. Falls back to
/// the plain per-tone wording when there's nothing to report: the habit has
/// never been logged, or was logged today.
///
/// Takes `lastLoggedDayKey` rather than raw `LogEvent`s or a `Set` of every
/// logged day — the caller already knows the most recent one from the
/// habit's history, and that's all this needs. Takes `tone` rather than
/// re-deriving it from the habit, since the caller (`nudge(...)`) has
/// already resolved it once and this shouldn't re-decide it.
public func missedDayAwareNudgeText(
    for habit: Habit,
    tone: NudgeTone,
    lastLoggedDayKey: Int?,
    today: Int,
    calendar: Calendar = .current
) -> String {
    guard let lastLoggedDayKey else {
        return phraseText(tone: tone, habit: habit, dayKey: today, index: nil, rotate: false)
    }

    let daysSince = daysBetween(lastLoggedDayKey, today, calendar: calendar)
    guard daysSince > 0 else {
        return phraseText(tone: tone, habit: habit, dayKey: today, index: nil, rotate: false)
    }

    let dayWord = daysSince == 1 ? "day" : "days"
    let fact = "\(daysSince) \(dayWord) since you last logged \(habit.name)"
    return String(format: missedDayTemplate(for: tone), fact)
}

func daysBetween(_ start: Int, _ end: Int, calendar: Calendar) -> Int {
    calendar.dateComponents(
        [.day],
        from: date(fromDayKey: start, calendar: calendar),
        to: date(fromDayKey: end, calendar: calendar)
    ).day ?? 0
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
    appTone: NudgeTone? = nil,
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

    let resolved = resolveWording(for: habit, appTone: appTone, dayKey: dayKey)
    let text = settings.mentionMissedDays
        ? missedDayAwareNudgeText(for: habit, tone: resolved.tone, lastLoggedDayKey: lastLoggedDayKey, today: dayKey, calendar: calendar)
        : resolved.text

    return NudgeRequest(
        habitID: habit.id,
        tone: resolved.tone,
        text: text,
        interruptionLevel: .passive
    )
}
