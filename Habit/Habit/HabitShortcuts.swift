//
//  HabitShortcuts.swift
//  Habit
//

import AppIntents

/// Registers `LogHabitIntent` with Shortcuts and Siri (spec §7) — this is
/// what makes "Log Drink water" available as a Shortcuts action, and what an
/// NFC automation with Ask Before Running turned off fires silently.
struct HabitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHabitIntent(),
            phrases: [
                "Log \(\.$habit) in \(.applicationName)",
                "Log \(\.$habit) with \(.applicationName)"
            ],
            shortTitle: "Log Habit",
            systemImageName: "checkmark.circle"
        )
    }
}
