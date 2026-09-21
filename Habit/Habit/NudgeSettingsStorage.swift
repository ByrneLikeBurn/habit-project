//
//  NudgeSettingsStorage.swift
//  Habit
//

import Foundation

/// `UserDefaults` keys for the Nudges section of Settings, shared across
/// every view that reads or writes it via `@AppStorage`. Default values
/// here mirror `HabitKit.NudgeSettings`'s own defaults.
enum NudgeSettingsStorage {
    static let notificationsEnabledKey = "nudgeNotificationsEnabled"
    static let dailyCapKey = "nudgeDailyCap"
    static let quietHoursStartKey = "nudgeQuietHoursStart"
    static let quietHoursEndKey = "nudgeQuietHoursEnd"
    static let skipWhenAlreadyLoggedKey = "nudgeSkipWhenAlreadyLogged"
    static let mentionMissedDaysKey = "nudgeMentionMissedDays"
    /// An absent or empty value means no app tone — *each habit's own
    /// voice*, the normal state (spec §284). The pre-seven-tone `"nudgeTone"`
    /// key is never read from here, which is how every device starts at
    /// that state with no migration code.
    static let appToneKey = "nudgeAppTone"
}
