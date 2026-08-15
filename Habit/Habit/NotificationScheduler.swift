//
//  NotificationScheduler.swift
//  Habit
//

import Foundation
import UserNotifications
import HabitKit

/// Hands `HabitKit`'s pure nudge engine to `UserNotifications`. The engine
/// only decides *what* should be sent; this is the one place that actually
/// asks the OS for permission and schedules anything.
@MainActor
enum NotificationScheduler {
    /// Requests permission only if it's never been asked (`.notDetermined`).
    /// Once the OS has an answer, asking again is a no-op that returns the
    /// existing answer without prompting — so it's safe to call this from
    /// every reschedule, and it still only ever prompts once, the first
    /// time notifications get turned on.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Rebuilds every pending nudge notification from scratch — the
    /// simplest correct way to keep "one pending request per habit per day"
    /// in sync with whatever just changed. Call after logging, when the app
    /// comes to the foreground, and whenever a nudge setting changes.
    static func reschedule(habits: [Habit], calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let settings = currentNudgeSettings()
        guard settings.notificationsEnabled else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let tone = currentTone()
        let today = dayKey(for: Date(), calendar: calendar)
        var scheduledCount = 0

        // Only Focus habits nudge (spec §5) — everything else is loggable
        // but quiet.
        for habit in habits.filter(\.isFocus).sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let hour = habit.nudgeHour
            let todayTotal = habit.events
                .filter { $0.dayKey == today }
                .reduce(0) { $0 + $1.delta }
            let lastLoggedDayKey = habit.events
                .filter { $0.delta > 0 }
                .map(\.dayKey)
                .max()

            guard let request = nudge(
                for: habit,
                on: today,
                hour: hour,
                todayLoggedTotal: todayTotal,
                pauses: habit.pauses,
                nudgesAlreadyScheduledToday: scheduledCount,
                tone: tone,
                settings: settings,
                lastLoggedDayKey: lastLoggedDayKey,
                calendar: calendar
            ) else { continue }

            guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()),
                  fireDate > Date() else {
                continue // that hour has already passed today — nothing more to do until tomorrow
            }

            scheduledCount += 1

            let content = UNMutableNotificationContent()
            content.body = request.text
            content.interruptionLevel = .passive
            content.sound = nil

            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let notificationRequest = UNNotificationRequest(
                identifier: "nudge-\(habit.id.uuidString)",
                content: content,
                trigger: trigger
            )

            try? await center.add(notificationRequest)
        }
    }

    private static func currentNudgeSettings() -> NudgeSettings {
        let defaults = UserDefaults.standard
        return NudgeSettings(
            notificationsEnabled: defaults.object(forKey: NudgeSettingsStorage.notificationsEnabledKey) as? Bool ?? true,
            dailyCap: defaults.object(forKey: NudgeSettingsStorage.dailyCapKey) as? Int ?? 3,
            quietHoursStart: defaults.object(forKey: NudgeSettingsStorage.quietHoursStartKey) as? Int ?? 22,
            quietHoursEnd: defaults.object(forKey: NudgeSettingsStorage.quietHoursEndKey) as? Int ?? 8,
            skipWhenAlreadyLogged: defaults.object(forKey: NudgeSettingsStorage.skipWhenAlreadyLoggedKey) as? Bool ?? true,
            mentionMissedDays: defaults.object(forKey: NudgeSettingsStorage.mentionMissedDaysKey) as? Bool ?? false
        )
    }

    private static func currentTone() -> NudgeTone {
        let raw = UserDefaults.standard.string(forKey: NudgeSettingsStorage.toneKey) ?? NudgeTone.plain.rawValue
        return NudgeTone(rawValue: raw) ?? .plain
    }
}
