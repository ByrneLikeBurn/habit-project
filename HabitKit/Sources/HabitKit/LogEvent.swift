import Foundation
import SwiftData

public enum LogSource: Int, Codable, Sendable {
    case manual
    case watch
    case widget
    case shortcut
    case siri
    case control
}

/// Append-only. Stores `delta` (+1/−1), never an absolute value — concurrent
/// increments across devices must be commutative. Day totals are derived by
/// summing deltas for a `dayKey`, never stored.
@Model
public final class LogEvent {
    public var id: UUID
    public var habit: Habit?
    public var dayKey: Int          // 20260801, in the user's calendar
    public var delta: Int           // +1 / -1
    public var source: LogSource
    public var timestamp: Date
    public var deviceID: String

    public init(
        id: UUID = UUID(),
        habit: Habit? = nil,
        dayKey: Int,
        delta: Int,
        source: LogSource,
        timestamp: Date = Date(),
        deviceID: String
    ) {
        self.id = id
        self.habit = habit
        self.dayKey = dayKey
        self.delta = delta
        self.source = source
        self.timestamp = timestamp
        self.deviceID = deviceID
    }
}
