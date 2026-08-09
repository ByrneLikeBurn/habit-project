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

/// The `dayKey` immediately before `dayKey`, correctly crossing month and year boundaries.
public func previousDayKey(_ dayKey: Int, calendar: Calendar = .current) -> Int {
    let components = DateComponents(year: dayKey / 10_000, month: (dayKey / 100) % 100, day: dayKey % 100)
    guard let date = calendar.date(from: components),
          let previousDate = calendar.date(byAdding: .day, value: -1, to: date) else {
        fatalError("Calendar failed to compute the day before \(dayKey)")
    }
    let previousComponents = calendar.dateComponents([.year, .month, .day], from: previousDate)
    guard let year = previousComponents.year, let month = previousComponents.month, let day = previousComponents.day else {
        fatalError("Calendar failed to produce date components for \(previousDate)")
    }
    return year * 10_000 + month * 100 + day
}
