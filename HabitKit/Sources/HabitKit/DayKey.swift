import Foundation

/// Computes the `dayKey` (an `Int` like `20260801`) that a `Date` belongs to,
/// in the given calendar, with a settable day-start hour (default 04:00).
///
/// A moment before the day-start hour belongs to the previous calendar day —
/// this is what lets a log at 3am count toward "yesterday" rather than splitting
/// a night's habits across two dates.
public func dayKey(for date: Date, calendar: Calendar = .current, dayStartHour: Int = 4) -> Int {
    let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
    let components = calendar.dateComponents([.year, .month, .day], from: shifted)
    guard let year = components.year, let month = components.month, let day = components.day else {
        fatalError("Calendar failed to produce date components for \(date)")
    }
    return year * 10_000 + month * 100 + day
}
