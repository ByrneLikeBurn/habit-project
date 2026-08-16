//
//  LogHabitIntent.swift
//  Habit
//

import AppIntents
import SwiftData
import HabitKit

/// The one write path (CLAUDE.md's invariant, spec §7/§10): every `LogEvent`
/// — the widget button, Shortcuts/NFC, Control Centre, the Action button,
/// Siri, and in-app taps — is written by this intent calling HabitKit's
/// `logHabit(...)`, and nothing else constructs a `LogEvent` directly.
/// In-app call sites construct this intent and call `perform()` directly
/// rather than duplicating the toggle-and-write logic a second time.
struct LogHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Habit"
    static let description = IntentDescription(
        "Logs today's entry for a habit — completes a binary habit, or adds one toward a counted habit's target."
    )

    /// Runs with no confirmation UI (spec §7's silent NFC tap — Ask Before
    /// Running off means no banner, no notification). `.background` is the
    /// modern, non-deprecated replacement for `openAppWhenRun = false`.
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Habit")
    var habit: HabitEntity

    /// Not a `@Parameter` — Shortcuts and Siri never choose this. Trusted
    /// in-app call sites (the check circle) set it to `.manual` before
    /// calling `perform()` directly; everything else defaults to `.shortcut`.
    var source: LogSource = .shortcut

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$habit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(HabitApp.sharedModelContainer)
        let targetID = habit.id
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate<Habit> { $0.id == targetID })

        guard let realHabit = try context.fetch(descriptor).first else {
            throw LogHabitIntentError.habitNotFound
        }

        let today = dayKey(for: Date())
        let todayTotal = realHabit.events
            .filter { $0.dayKey == today }
            .reduce(0) { $0 + $1.delta }
        let delta = toggleDelta(currentTotal: todayTotal, target: realHabit.target)

        logHabit(realHabit, delta: delta, source: source, modelContext: context)

        return .result()
    }
}

enum LogHabitIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case habitNotFound

    var localizedStringResource: LocalizedStringResource {
        "That habit couldn't be found — it may have been deleted."
    }
}
