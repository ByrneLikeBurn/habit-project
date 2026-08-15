import Foundation
import SwiftData

/// Restoring from an export (spec §9) — the other half of the escape hatch.
/// Two modes: merge (add anything not already present, matched by id) and
/// replace (wipe the store and restore the file wholesale). The decision
/// logic (`planMerge`, `replaceImpact`) is pure and directly testable; the
/// apply functions do the actual `ModelContext` writes.

public enum ImportMode: CaseIterable, Sendable {
    case merge
    case replace
}

public enum ImportError: Error, Equatable, Sendable {
    /// The file's `version` is newer than this build understands. Schema is
    /// additive-only, so an older build can't safely guess what a future
    /// field means — refuse rather than silently drop it.
    case unsupportedVersion(found: Int, supported: ClosedRange<Int>)
}

public func validateExportVersion(_ export: HabitExport) throws {
    let supported = 1...HabitExport.currentVersion
    guard supported.contains(export.version) else {
        throw ImportError.unsupportedVersion(found: export.version, supported: supported)
    }
}

/// What merging `incoming` into `existingHabits` would do: a habit whose id
/// isn't already present is inserted wholesale; for a habit that already
/// exists, only the events and pauses whose id isn't already present are
/// added. Nothing already on device is ever modified or removed by a merge.
public struct ImportPlan: Equatable, Sendable {
    public var newHabits: [HabitDTO]
    public var additions: [HabitAdditions]

    public var isEmpty: Bool { newHabits.isEmpty && additions.isEmpty }
}

public struct HabitAdditions: Equatable, Sendable {
    public var habitID: UUID
    public var newEvents: [LogEventDTO]
    public var newPauses: [PauseDTO]
}

public func planMerge(existingHabits: [Habit], incoming: [HabitDTO]) -> ImportPlan {
    let existingByID = Dictionary(uniqueKeysWithValues: existingHabits.map { ($0.id, HabitDTO(habit: $0)) })

    var newHabits: [HabitDTO] = []
    var additions: [HabitAdditions] = []

    for habit in incoming {
        guard let existing = existingByID[habit.id] else {
            newHabits.append(habit)
            continue
        }

        let existingEventIDs = Set(existing.events.map(\.id))
        let existingPauseIDs = Set(existing.pauses.map(\.id))
        let newEvents = habit.events.filter { !existingEventIDs.contains($0.id) }
        let newPauses = habit.pauses.filter { !existingPauseIDs.contains($0.id) }

        if !newEvents.isEmpty || !newPauses.isEmpty {
            additions.append(HabitAdditions(habitID: habit.id, newEvents: newEvents, newPauses: newPauses))
        }
    }

    return ImportPlan(newHabits: newHabits, additions: additions)
}

/// Writes a merge plan to the store. Existing habits, events and pauses are
/// never touched — only the plan's additions are inserted.
public func applyMergePlan(_ plan: ImportPlan, existingHabits: [Habit], modelContext: ModelContext) {
    for habitDTO in plan.newHabits {
        insertHabit(from: habitDTO, modelContext: modelContext)
    }

    let existingByID = Dictionary(uniqueKeysWithValues: existingHabits.map { ($0.id, $0) })
    for addition in plan.additions {
        guard let habit = existingByID[addition.habitID] else { continue }
        for eventDTO in addition.newEvents {
            modelContext.insert(LogEvent(dto: eventDTO, habit: habit))
        }
        for pauseDTO in addition.newPauses {
            modelContext.insert(Pause(dto: pauseDTO, habit: habit))
        }
    }

    try? modelContext.save()
}

/// What replacing would cost — surfaced in the confirmation prompt so "wipe
/// and restore wholesale" is never a surprise.
public struct ReplaceImpact: Equatable, Sendable {
    public var habitsToDelete: Int
    public var eventsToDelete: Int
    public var pausesToDelete: Int
    public var habitsToRestore: Int
}

public func replaceImpact(existingHabits: [Habit], incoming: HabitExport) -> ReplaceImpact {
    ReplaceImpact(
        habitsToDelete: existingHabits.count,
        eventsToDelete: existingHabits.reduce(0) { $0 + $1.events.count },
        pausesToDelete: existingHabits.reduce(0) { $0 + $1.pauses.count },
        habitsToRestore: incoming.habits.count
    )
}

/// Wipes every existing habit — cascading to its events and pauses — and
/// restores `export`'s habits wholesale, preserving their original ids.
public func applyReplace(_ export: HabitExport, existingHabits: [Habit], modelContext: ModelContext) {
    for habit in existingHabits {
        modelContext.delete(habit)
    }
    for habitDTO in export.habits {
        insertHabit(from: habitDTO, modelContext: modelContext)
    }
    try? modelContext.save()
}

/// The single entry point the app calls: decode, validate the version, then
/// apply whichever mode the user chose.
public func importExport(
    _ data: Data,
    mode: ImportMode,
    existingHabits: [Habit],
    modelContext: ModelContext
) throws {
    let export = try decodeExport(data)
    try validateExportVersion(export)

    switch mode {
    case .merge:
        let plan = planMerge(existingHabits: existingHabits, incoming: export.habits)
        applyMergePlan(plan, existingHabits: existingHabits, modelContext: modelContext)
    case .replace:
        applyReplace(export, existingHabits: existingHabits, modelContext: modelContext)
    }
}

private func insertHabit(from dto: HabitDTO, modelContext: ModelContext) {
    let habit = Habit(dto: dto)
    modelContext.insert(habit)
    for eventDTO in dto.events {
        modelContext.insert(LogEvent(dto: eventDTO, habit: habit))
    }
    for pauseDTO in dto.pauses {
        modelContext.insert(Pause(dto: pauseDTO, habit: habit))
    }
}

extension Habit {
    convenience init(dto: HabitDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            symbolName: dto.symbolName,
            kind: dto.kind,
            target: dto.target,
            unit: dto.unit,
            scheduleMask: dto.scheduleMask,
            sortIndex: dto.sortIndex,
            isFocus: dto.isFocus,
            gentleEnabled: dto.gentleEnabled,
            vacationByDefault: dto.vacationByDefault,
            tagNickname: dto.tagNickname,
            nudgeHour: dto.nudgeHour,
            createdAt: dto.createdAt,
            archivedAt: dto.archivedAt,
            deletedAt: dto.deletedAt
        )
    }
}

extension LogEvent {
    convenience init(dto: LogEventDTO, habit: Habit?) {
        self.init(
            id: dto.id,
            habit: habit,
            dayKey: dto.dayKey,
            delta: dto.delta,
            source: dto.source,
            timestamp: dto.timestamp,
            deviceID: dto.deviceID
        )
    }
}

extension Pause {
    convenience init(dto: PauseDTO, habit: Habit?) {
        self.init(id: dto.id, habit: habit, startDay: dto.startDay, endDay: dto.endDay, reason: dto.reason)
    }
}
