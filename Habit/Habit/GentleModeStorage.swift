//
//  GentleModeStorage.swift
//  Habit
//

import Foundation

/// `UserDefaults` keys for Gentle Mode's global switch state, shared across
/// every view that reads or writes it via `@AppStorage`.
enum GentleModeStorage {
    static let startedAtDayKeyDefaultsKey = "gentleModeStartedAtDayKey"
    static let safeguardDismissedDefaultsKey = "gentleModeSafeguardDismissedForDayKey"
}
