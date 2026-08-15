import Foundation

/// The JSON escape hatch (spec §9) for every persistence risk this app
/// takes on — SwiftData's lightweight-migration-only ceiling, CloudKit
/// outages, a device lost before sync catches up. `Habit`/`LogEvent`/`Pause`
/// are SwiftData `@Model` reference types tied to a `ModelContext`; these
/// DTOs are the plain, portable shape that actually survives being written
/// to a file and read back years later by code that no longer looks like this.
public struct HabitExport: Codable, Equatable, Sendable {
    /// Bump whenever a field is added or a DTO's shape changes, so a future
    /// reader (including this app, after schema changes) can tell what it's
    /// looking at. Schema is additive-only (per CLAUDE.md), so old exports
    /// must always remain decodable — never remove or repurpose a version.
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var habits: [HabitDTO]

    public init(version: Int = HabitExport.currentVersion, exportedAt: Date, habits: [HabitDTO]) {
        self.version = version
        self.exportedAt = exportedAt
        self.habits = habits
    }
}

public struct HabitDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var kind: HabitKind
    public var target: Int
    public var unit: String?
    public var scheduleMask: Int
    public var sortIndex: Int
    public var isFocus: Bool
    public var gentleEnabled: Bool
    public var vacationByDefault: Bool
    public var tagNickname: String?
    public var nudgeHour: Int
    public var createdAt: Date
    public var archivedAt: Date?
    public var deletedAt: Date?
    public var events: [LogEventDTO]
    public var pauses: [PauseDTO]

    public init(habit: Habit) {
        id = habit.id
        name = habit.name
        symbolName = habit.symbolName
        kind = habit.kind
        target = habit.target
        unit = habit.unit
        scheduleMask = habit.scheduleMask
        sortIndex = habit.sortIndex
        isFocus = habit.isFocus
        gentleEnabled = habit.gentleEnabled
        vacationByDefault = habit.vacationByDefault
        tagNickname = habit.tagNickname
        nudgeHour = habit.nudgeHour
        createdAt = habit.createdAt
        archivedAt = habit.archivedAt
        deletedAt = habit.deletedAt
        events = habit.events.map(LogEventDTO.init)
        pauses = habit.pauses.map(PauseDTO.init)
    }
}

public struct LogEventDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var dayKey: Int
    public var delta: Int
    public var source: LogSource
    public var timestamp: Date
    public var deviceID: String

    public init(event: LogEvent) {
        id = event.id
        dayKey = event.dayKey
        delta = event.delta
        source = event.source
        timestamp = event.timestamp
        deviceID = event.deviceID
    }
}

public struct PauseDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var startDay: Int
    public var endDay: Int?
    public var reason: PauseReason

    public init(pause: Pause) {
        id = pause.id
        startDay = pause.startDay
        endDay = pause.endDay
        reason = pause.reason
    }
}

/// ISO 8601 with fractional seconds, so a `LogEvent.timestamp` round-trips
/// exactly rather than losing sub-second precision — the whole point of an
/// export is that nothing gets quietly dropped. `ISO8601DateFormatter` isn't
/// `Sendable`; this box is safe because each encode/decode call gets its own
/// instance and never shares it across threads.
private struct ExportDateFormatterBox: @unchecked Sendable {
    let formatter: ISO8601DateFormatter

    init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
}

private func makeExportEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let box = ExportDateFormatterBox()
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(box.formatter.string(from: date))
    }
    return encoder
}

private func makeExportDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let box = ExportDateFormatterBox()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = box.formatter.date(from: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date, got \"\(string)\""
            )
        }
        return date
    }
    return decoder
}

/// Every habit, log event and pause, as JSON. Available any time from
/// Settings (spec §9) — not only on the way out the door via delete.
public func exportData(habits: [Habit], exportedAt: Date) throws -> Data {
    let export = HabitExport(exportedAt: exportedAt, habits: habits.map(HabitDTO.init))
    return try makeExportEncoder().encode(export)
}

public func decodeExport(_ data: Data) throws -> HabitExport {
    try makeExportDecoder().decode(HabitExport.self, from: data)
}
