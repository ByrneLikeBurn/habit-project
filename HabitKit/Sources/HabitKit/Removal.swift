import Foundation
import SwiftData

/// Archive, delete and purge (spec §9) — three states, deliberately.
/// Archiving hides a habit from every list but keeps it and its history
/// forever, restorable. Deleting moves it to Recently Deleted for 30 days —
/// still restorable, nothing lost yet. Only "Delete now" inside that list,
/// or the 30-day window elapsing on its own, actually removes anything.

public let purgeWindowDays = 30

public func archiveHabit(_ habit: Habit, modelContext: ModelContext) {
    habit.archivedAt = Date()
    habit.deletedAt = nil
    try? modelContext.save()
}

public func restoreFromArchive(_ habit: Habit, modelContext: ModelContext) {
    habit.archivedAt = nil
    try? modelContext.save()
}

public func moveToRecentlyDeleted(_ habit: Habit, modelContext: ModelContext) {
    habit.deletedAt = Date()
    habit.archivedAt = nil
    try? modelContext.save()
}

public func restoreFromRecentlyDeleted(_ habit: Habit, modelContext: ModelContext) {
    habit.deletedAt = nil
    try? modelContext.save()
}

/// The one irreversible operation in the app (spec §9) — removes the habit
/// and, via its cascade delete rule, every `LogEvent` and `Pause` with it.
public func permanentlyDelete(_ habit: Habit, modelContext: ModelContext) {
    modelContext.delete(habit)
    try? modelContext.save()
}

// MARK: - Cost of deleting

/// Days the habit actually has a logged total for — not every calendar day
/// since it was created.
public func loggedDayCount(for habit: Habit) -> Int {
    dayTotals(for: habit).count
}

public func earliestLoggedDayKey(for habit: Habit) -> Int? {
    dayTotals(for: habit).keys.min()
}

private func dayTotals(for habit: Habit) -> [Int: Int] {
    Dictionary(grouping: habit.events, by: \.dayKey)
        .mapValues { $0.reduce(0) { $0 + $1.delta } }
        .filter { $0.value > 0 }
}

/// The cost sentence for the one destructive confirmation in the app (spec
/// §9) — states what's lost in days rather than asking "are you sure". The
/// word "permanently" belongs in the confirmation's own title, not here, so
/// this sentence stays reusable without repeating it.
public func permanentDeletionCostSummary(for habit: Habit, calendar: Calendar = .current) -> String {
    let count = loggedDayCount(for: habit)
    guard count > 0, let earliestKey = earliestLoggedDayKey(for: habit) else {
        return "This habit has no logged days yet. It can't be undone, on this or any of your devices."
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "MMMM yyyy"
    let monthYear = formatter.string(from: date(fromDayKey: earliestKey, calendar: calendar))
    let dayWord = count == 1 ? "logged day" : "logged days"

    return "This removes \(count) \(dayWord), going back to \(monthYear). It can't be undone, on this or any of your devices."
}

// MARK: - Purge

/// Whole days elapsed since `deletedAt`, floored at zero.
public func daysSinceDeletion(deletedAt: Date, today: Date = Date(), calendar: Calendar = .current) -> Int {
    max(0, calendar.dateComponents([.day], from: deletedAt, to: today).day ?? 0)
}

public func daysRemainingBeforePurge(deletedAt: Date, today: Date = Date(), calendar: Calendar = .current) -> Int {
    max(0, purgeWindowDays - daysSinceDeletion(deletedAt: deletedAt, today: today, calendar: calendar))
}

public func hasPurgeWindowElapsed(deletedAt: Date, today: Date = Date(), calendar: Calendar = .current) -> Bool {
    daysSinceDeletion(deletedAt: deletedAt, today: today, calendar: calendar) >= purgeWindowDays
}

public func habitsPastPurgeWindow(_ habits: [Habit], today: Date = Date(), calendar: Calendar = .current) -> [Habit] {
    habits.filter { habit in
        guard let deletedAt = habit.deletedAt else { return false }
        return hasPurgeWindowElapsed(deletedAt: deletedAt, today: today, calendar: calendar)
    }
}

/// Runs once at launch (spec §9) — never a scheduled task, so a device
/// that's been off for two months still purges correctly the moment it's
/// opened next. Deleting an already-deleted `Habit` is a no-op, which is
/// what keeps two devices waking on day 31 from needing to coordinate: each
/// just asks "is this still here, and still past the window?" and acts only
/// if so.
public func purgeExpiredDeletions(
    habits: [Habit],
    today: Date = Date(),
    calendar: Calendar = .current,
    modelContext: ModelContext
) {
    for habit in habitsPastPurgeWindow(habits, today: today, calendar: calendar) {
        modelContext.delete(habit)
    }
    try? modelContext.save()
}
