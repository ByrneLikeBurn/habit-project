import Foundation
import SwiftData

public enum HabitKind: Int, Codable, Sendable {
    case binary
    case counted
}

@Model
public final class Habit {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var kind: HabitKind
    public var target: Int              // 1 for binary
    public var unit: String?
    public var scheduleMask: Int        // weekday bitmask, 127 = daily
    public var sortIndex: Int
    public var isFocus: Bool            // Focus group — nudges + widget + complication
    public var gentleEnabled: Bool      // armed for the global Gentle Mode switch
    public var vacationByDefault: Bool  // pre-ticked when a trip is created
    public var tagNickname: String?     // cosmetic only — see spec §7
    public var createdAt: Date
    public var archivedAt: Date?        // hidden from Today, history intact, restorable
    public var deletedAt: Date?         // in Recently Deleted; purged 30 days later

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        kind: HabitKind = .binary,
        target: Int = 1,
        unit: String? = nil,
        scheduleMask: Int = 127,
        sortIndex: Int = 0,
        isFocus: Bool = false,
        gentleEnabled: Bool = false,
        vacationByDefault: Bool = false,
        tagNickname: String? = nil,
        createdAt: Date = Date(),
        archivedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.kind = kind
        self.target = target
        self.unit = unit
        self.scheduleMask = scheduleMask
        self.sortIndex = sortIndex
        self.isFocus = isFocus
        self.gentleEnabled = gentleEnabled
        self.vacationByDefault = vacationByDefault
        self.tagNickname = tagNickname
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.deletedAt = deletedAt
    }
}
