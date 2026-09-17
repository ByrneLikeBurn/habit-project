import Testing
import Foundation
@testable import HabitKit

@Test func exportRoundTripPreservesEveryHabitField() throws {
    let habit = Habit(
        id: UUID(),
        name: "Read",
        symbolName: "book",
        kind: .counted,
        target: 20,
        unit: "pages",
        scheduleMask: 62,
        sortIndex: 3,
        isFocus: true,
        gentleEnabled: true,
        vacationByDefault: true,
        tagNickname: "Desk tag",
        nudgeHour: 21,
        createdAt: Date(timeIntervalSince1970: 1_723_000_000.125),
        archivedAt: Date(timeIntervalSince1970: 1_723_100_000.5),
        deletedAt: Date(timeIntervalSince1970: 1_723_200_000.75)
    )

    let event = LogEvent(
        id: UUID(),
        habit: habit,
        dayKey: 20260810,
        delta: -1,
        source: .widget,
        timestamp: Date(timeIntervalSince1970: 1_723_050_000.25),
        deviceID: "device-abc"
    )
    habit.events.append(event)

    let pause = Pause(id: UUID(), habit: habit, startDay: 20260801, endDay: 20260808, reason: .vacation)
    habit.pauses.append(pause)

    let exportedAt = Date(timeIntervalSince1970: 1_723_300_000.375)
    let data = try exportData(habits: [habit], exportedAt: exportedAt)
    let decoded = try decodeExport(data)

    let expected = HabitExport(exportedAt: exportedAt, habits: [HabitDTO(habit: habit)])
    #expect(decoded == expected)
    #expect(decoded.version == HabitExport.currentVersion)
}

@Test func exportRoundTripPreservesOptionalNilFields() throws {
    let habit = Habit(name: "Stretch", symbolName: "figure.flexibility", createdAt: Date(timeIntervalSince1970: 1_723_000_000))
    let event = LogEvent(
        habit: habit,
        dayKey: 20260810,
        delta: 1,
        source: .manual,
        timestamp: Date(timeIntervalSince1970: 1_723_050_000),
        deviceID: "device-xyz"
    )
    habit.events.append(event)
    let pause = Pause(habit: habit, startDay: 20260801, endDay: nil, reason: .gentle)
    habit.pauses.append(pause)

    let exportedAt = Date(timeIntervalSince1970: 1_723_300_000)
    let data = try exportData(habits: [habit], exportedAt: exportedAt)
    let decoded = try decodeExport(data)

    #expect(decoded.habits.first?.unit == nil)
    #expect(decoded.habits.first?.tagNickname == nil)
    #expect(decoded.habits.first?.archivedAt == nil)
    #expect(decoded.habits.first?.deletedAt == nil)
    #expect(decoded.habits.first?.pauses.first?.endDay == nil)
    #expect(decoded == HabitExport(exportedAt: exportedAt, habits: [HabitDTO(habit: habit)]))
}

/// An export file written before `keepWordingOnToneChange` existed has no
/// such key in its JSON at all — not `null`, absent entirely. `HabitDTO`'s
/// custom decode must tolerate that rather than fail the whole import, and
/// fall back to `true`, the same default the stored property carries.
@Test func exportWrittenBeforeKeepWordingOnToneChangeExistedStillImports() throws {
    let habit = Habit(name: "Read", symbolName: "book", createdAt: Date(timeIntervalSince1970: 1_723_000_000))
    let exportedAt = Date(timeIntervalSince1970: 1_723_300_000)
    let data = try exportData(habits: [habit], exportedAt: exportedAt)

    var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    var habitsJSON = try #require(json["habits"] as? [[String: Any]])
    habitsJSON[0].removeValue(forKey: "keepWordingOnToneChange")
    json["habits"] = habitsJSON
    let dataWithoutTheKey = try JSONSerialization.data(withJSONObject: json)

    let decoded = try decodeExport(dataWithoutTheKey)
    #expect(decoded.habits.first?.keepWordingOnToneChange == true)
}

@Test func exportRoundTripPreservesMultipleHabitsAndEmptyCollections() throws {
    let habitWithHistory = Habit(name: "Run", symbolName: "figure.run", createdAt: Date(timeIntervalSince1970: 1_723_000_000))
    habitWithHistory.events.append(LogEvent(
        habit: habitWithHistory,
        dayKey: 20260810,
        delta: 1,
        source: .siri,
        timestamp: Date(timeIntervalSince1970: 1_723_050_000),
        deviceID: "a"
    ))

    let freshHabit = Habit(name: "Meditate", symbolName: "figure.mind.and.body", createdAt: Date(timeIntervalSince1970: 1_723_000_000))

    let exportedAt = Date(timeIntervalSince1970: 1_723_300_000)
    let data = try exportData(habits: [habitWithHistory, freshHabit], exportedAt: exportedAt)
    let decoded = try decodeExport(data)

    #expect(decoded.habits.count == 2)
    #expect(decoded.habits[1].events.isEmpty)
    #expect(decoded.habits[1].pauses.isEmpty)
}
