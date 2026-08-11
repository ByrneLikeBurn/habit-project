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
