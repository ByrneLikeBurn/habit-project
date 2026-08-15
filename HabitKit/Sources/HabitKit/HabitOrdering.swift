import Foundation

/// The `sortIndex` a newly created habit should get — one past whatever the
/// highest existing index is, so new habits land at the end of manual order
/// (spec §5) instead of colliding at 0.
public func nextSortIndex(after habits: [Habit]) -> Int {
    (habits.map(\.sortIndex).max() ?? -1) + 1
}

/// The stable display order for habits: manual order first, then creation
/// order for anything tied (new habits, or habits that have never been
/// reordered).
///
/// Sort the fetched array with this rather than passing it to `@Query`'s
/// own `sort:` parameter — a sorted `@Query` stops noticing changes to
/// relationships on the fetched entity (e.g. a `Habit` gaining a new
/// `LogEvent`), because it only re-observes the properties named in the
/// sort/predicate. `habitSortDescriptors` below is for one-shot,
/// non-reactive fetches (e.g. a widget snapshot) where that doesn't matter.
public func sortedForDisplay(_ habits: [Habit]) -> [Habit] {
    habits.sorted { lhs, rhs in
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.createdAt < rhs.createdAt
    }
}

public let habitSortDescriptors: [SortDescriptor<Habit>] = [
    SortDescriptor(\Habit.sortIndex),
    SortDescriptor(\Habit.createdAt),
]

/// The three ordering modes for the "Everything else" part of Today (spec §5).
public enum HabitSortMode: String, Sendable, CaseIterable {
    case manual
    case byTime
    case smart
}

/// Orders `habits` per `mode`.
///
/// `.smart` is a stub: real Smart ordering needs a rolling window of
/// on-device log history — the circular median of the local hour a habit
/// tends to get logged at, recomputed daily — which isn't built yet. Until
/// it is, this uses exactly the fallback the real algorithm itself falls
/// back to for a habit with fewer than ten logs: nudge time, then manual
/// order. So `.smart` and `.byTime` currently produce identical results;
/// that's intentional, not a bug, and should change only once real history
/// is wired in.
public func sortedHabits(_ habits: [Habit], mode: HabitSortMode) -> [Habit] {
    switch mode {
    case .manual:
        return sortedForDisplay(habits)
    case .byTime, .smart:
        return habits.sorted { lhs, rhs in
            if lhs.nudgeHour != rhs.nudgeHour { return lhs.nudgeHour < rhs.nudgeHour }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
