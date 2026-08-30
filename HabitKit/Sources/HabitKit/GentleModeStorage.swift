import Foundation

/// Legacy `UserDefaults` keys for Gentle Mode's global switch state.
///
/// Before `AppSettings`, these were read and written directly by
/// `@AppStorage` in `GentleModeView`, `HabitDetailView`, and
/// `ContentView`'s `TodayHeader`. Now they're read exactly once — by
/// `AppSettingsAccessor`'s seed step, the first time an `AppSettings` row is
/// created — to carry an existing user's on/off state and safeguard
/// dismissal across the move into SwiftData. Nothing ever writes to these
/// keys again after that point; the values are left in `UserDefaults`
/// afterwards, unread and untouched, rather than deleted.
enum GentleModeStorage {
    static let startedAtDayKeyDefaultsKey = "gentleModeStartedAtDayKey"
    static let safeguardDismissedDefaultsKey = "gentleModeSafeguardDismissedForDayKey"
}
