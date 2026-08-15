import Testing
import Foundation
import SwiftData
@testable import HabitKit

@MainActor
private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Habit.self, LogEvent.self, Pause.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

// MARK: - planMerge (pure decision logic)

@Test func planMergeInsertsBrandNewHabitsWholesale() {
    let habitB = Habit(name: "Stretch", symbolName: "figure.flexibility")
    habitB.events.append(LogEvent(habit: habitB, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    let incoming = HabitDTO(habit: habitB)

    let plan = planMerge(existingHabits: [], incoming: [incoming])

    #expect(plan.newHabits == [incoming])
    #expect(plan.additions.isEmpty)
}

@Test func planMergeIsEmptyWhenNothingIncomingIsNew() {
    let habitA = Habit(name: "Read", symbolName: "book")
    habitA.events.append(LogEvent(habit: habitA, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))

    let incoming = [HabitDTO(habit: habitA)] // exactly what's already local

    let plan = planMerge(existingHabits: [habitA], incoming: incoming)

    #expect(plan.isEmpty)
}

/// The scenario named explicitly in the ask: a file that's already partly
/// present. Habit A locally has event1 only; the file has habit A with
/// event1 (already there) *and* event2 (new), plus a whole new habit B.
@Test func planMergeOnlyAddsWhatsMissingWhenFilePartlyOverlapsExistingData() {
    let habitA = Habit(name: "Read", symbolName: "book")
    let event1 = LogEvent(habit: habitA, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a")
    habitA.events.append(event1)

    var incomingA = HabitDTO(habit: habitA)
    let event2 = LogEvent(dayKey: 20260802, delta: 1, source: .manual, deviceID: "a")
    incomingA.events.append(LogEventDTO(event: event2))

    let habitB = Habit(name: "Stretch", symbolName: "figure.flexibility")
    let incomingB = HabitDTO(habit: habitB)

    let plan = planMerge(existingHabits: [habitA], incoming: [incomingA, incomingB])

    #expect(plan.newHabits == [incomingB])
    #expect(plan.additions == [HabitAdditions(habitID: habitA.id, newEvents: [LogEventDTO(event: event2)], newPauses: [])])
}

@Test func validateExportVersionAcceptsTheCurrentVersion() throws {
    let export = HabitExport(exportedAt: Date(timeIntervalSince1970: 0), habits: [])
    try validateExportVersion(export)
}

@Test func validateExportVersionRejectsAFutureVersion() {
    let export = HabitExport(version: HabitExport.currentVersion + 1, exportedAt: Date(timeIntervalSince1970: 0), habits: [])
    #expect(throws: ImportError.self) {
        try validateExportVersion(export)
    }
}

@Test func replaceImpactCountsWhatWouldBeLostAndRestored() {
    let habitC = Habit(name: "Old", symbolName: "moon")
    habitC.events.append(LogEvent(habit: habitC, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    habitC.pauses.append(Pause(habit: habitC, startDay: 20260801, endDay: 20260802, reason: .vacation))

    let incomingHabit = Habit(name: "New", symbolName: "leaf")
    let export = HabitExport(exportedAt: Date(timeIntervalSince1970: 0), habits: [HabitDTO(habit: incomingHabit)])

    let impact = replaceImpact(existingHabits: [habitC], incoming: export)

    #expect(impact.habitsToDelete == 1)
    #expect(impact.eventsToDelete == 1)
    #expect(impact.pausesToDelete == 1)
    #expect(impact.habitsToRestore == 1)
}

// MARK: - applyMergePlan / applyReplace (real ModelContext)

@MainActor
@Test func applyMergePlanAddsMissingDataWithoutDuplicatingWhatsAlreadyPresent() throws {
    let context = try makeInMemoryContext()

    let habitA = Habit(name: "Read", symbolName: "book")
    context.insert(habitA)
    context.insert(LogEvent(habit: habitA, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))
    try context.save()

    let existingHabits = try context.fetch(FetchDescriptor<Habit>())
    #expect(existingHabits.count == 1)

    // Incoming file: habit A with its existing event plus one new one, and a
    // whole new habit B — the "partly present" case at the apply layer.
    var incomingA = HabitDTO(habit: existingHabits[0])
    let newEvent = LogEvent(dayKey: 20260802, delta: 1, source: .manual, deviceID: "a")
    incomingA.events.append(LogEventDTO(event: newEvent))

    let habitB = Habit(name: "Stretch", symbolName: "figure.flexibility")
    let incomingB = HabitDTO(habit: habitB)

    let plan = planMerge(existingHabits: existingHabits, incoming: [incomingA, incomingB])
    applyMergePlan(plan, existingHabits: existingHabits, modelContext: context)

    let habitsAfter = try context.fetch(FetchDescriptor<Habit>())
    #expect(habitsAfter.count == 2)

    let restoredA = habitsAfter.first { $0.id == habitA.id }
    #expect(restoredA?.events.count == 2)

    let restoredB = habitsAfter.first { $0.id == habitB.id }
    #expect(restoredB != nil)

    // Importing the exact same file again should add nothing further.
    let secondPlan = planMerge(existingHabits: habitsAfter, incoming: [incomingA, incomingB])
    #expect(secondPlan.isEmpty)
}

@MainActor
@Test func applyReplaceWipesExistingDataAndRestoresExportExactly() throws {
    let context = try makeInMemoryContext()

    let habitC = Habit(name: "Old", symbolName: "moon")
    context.insert(habitC)
    context.insert(LogEvent(habit: habitC, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a"))

    let habitA = Habit(name: "Read", symbolName: "book")
    context.insert(habitA)
    context.insert(LogEvent(habit: habitA, dayKey: 20260801, delta: 1, source: .manual, deviceID: "a")) // stale, not in the file
    try context.save()

    let existingHabits = try context.fetch(FetchDescriptor<Habit>())
    #expect(existingHabits.count == 2)

    let exportedHabitA = Habit(id: habitA.id, name: "Read", symbolName: "book")
    exportedHabitA.events.append(LogEvent(dayKey: 20260810, delta: 1, source: .manual, deviceID: "b"))
    let export = HabitExport(exportedAt: Date(timeIntervalSince1970: 0), habits: [HabitDTO(habit: exportedHabitA)])

    applyReplace(export, existingHabits: existingHabits, modelContext: context)

    let habitsAfter = try context.fetch(FetchDescriptor<Habit>())
    #expect(habitsAfter.count == 1)
    #expect(habitsAfter.first?.id == habitA.id)
    #expect(habitsAfter.first?.events.count == 1)
    #expect(habitsAfter.first?.events.first?.dayKey == 20260810)

    let eventsAfter = try context.fetch(FetchDescriptor<LogEvent>())
    #expect(eventsAfter.count == 1)
}
