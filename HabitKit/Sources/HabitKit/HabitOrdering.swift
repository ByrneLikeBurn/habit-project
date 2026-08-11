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
public let habitSortDescriptors: [SortDescriptor<Habit>] = [
    SortDescriptor(\Habit.sortIndex),
    SortDescriptor(\Habit.createdAt),
]
