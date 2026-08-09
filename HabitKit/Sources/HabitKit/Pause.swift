import Foundation
import SwiftData

public enum PauseReason: Int, Codable, Sendable {
    case vacation
    case gentle
    case manual
}

@Model
public final class Pause {
    public var id: UUID
    public var habit: Habit?
    public var startDay: Int
    public var endDay: Int?         // nil = open-ended (Gentle Mode)
    public var reason: PauseReason

    public init(
        id: UUID = UUID(),
        habit: Habit? = nil,
        startDay: Int,
        endDay: Int? = nil,
        reason: PauseReason
    ) {
        self.id = id
        self.habit = habit
        self.startDay = startDay
        self.endDay = endDay
        self.reason = reason
    }

    /// Whether `dayKey` falls within this pause. An open-ended pause
    /// (`endDay == nil`) covers everything from `startDay` onward.
    public func covers(_ dayKey: Int) -> Bool {
        guard dayKey >= startDay else { return false }
        guard let endDay else { return true }
        return dayKey <= endDay
    }
}
