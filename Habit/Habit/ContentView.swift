//
//  ContentView.swift
//  Habit
//
//  Created by Liam Byrne on 8/8/26.
//

import SwiftUI
import SwiftData
import HabitKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @State private var showingVacationMode = false

    private var todayKeyValue: Int { dayKey(for: Date()) }

    /// Habits currently covered by a `Pause` — vacation or (once it exists)
    /// Gentle Mode. They leave the Today list, per spec §6, but stay
    /// loggable from the habit detail screen.
    private var restingHabits: [Habit] {
        sortedForDisplay(habits).filter { habit in
            habit.pauses.contains { $0.covers(todayKeyValue) }
        }
    }

    private var visibleHabits: [Habit] {
        sortedForDisplay(habits).filter { habit in
            !habit.pauses.contains { $0.covers(todayKeyValue) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    TodayHeader(restingHabits: restingHabits, today: todayKeyValue)
                        .padding(.top, 14)
                        .padding(.bottom, 20)

                    RuleDivider()

                    ForEach(Array(visibleHabits.enumerated()), id: \.element.id) { index, habit in
                        HabitRow(habit: habit)
                        if index < visibleHabits.count - 1 {
                            RuleDivider()
                        }
                    }
                }
                .padding(.horizontal, contentMargin)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .toolbar {
                ToolbarItem {
                    Button {
                        showingVacationMode = true
                    } label: {
                        Label("Vacation Mode", systemImage: "airplane")
                    }
                }
                ToolbarItem {
                    Button(action: addHabit) {
                        Label("Add Habit", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingVacationMode) {
                VacationModeView()
            }
        }
    }

    private func addHabit() {
        let habit = Habit(name: "New Habit", symbolName: "leaf", sortIndex: nextSortIndex(after: habits))
        modelContext.insert(habit)
    }
}

private struct RuleDivider: View {
    var body: some View {
        Divider()
            .overlay(Color("Rule"))
    }
}

private struct TodayHeader: View {
    let restingHabits: [Habit]
    let today: Int

    private var eyebrow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: "Good morning."
        case 12..<18: "Good afternoon."
        default: "Good evening."
        }
    }

    /// e.g. "3 resting until 20 August" — the quiet, guilt-free acknowledgement
    /// that Vacation Mode is doing something, since the habits themselves
    /// have already left the list below.
    private var restingSummary: String? {
        guard !restingHabits.isEmpty else { return nil }

        let endDays = restingHabits.compactMap { habit in
            habit.pauses.first { $0.covers(today) }?.endDay
        }

        guard let latestEndDay = endDays.max() else {
            return "\(restingHabits.count) resting"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        let untilDate = formatter.string(from: date(fromDayKey: latestEndDay))
        return "\(restingHabits.count) resting until \(untilDate)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color("Tertiary"))

            Text(greeting)
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(Color("Ink"))
                .fixedSize(horizontal: false, vertical: true)

            if let restingSummary {
                Text(restingSummary)
                    .font(.footnote)
                    .foregroundStyle(Color("Tertiary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitRow: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 8

    private var todayTotal: Int {
        let today = dayKey(for: Date())
        return habit.events
            .filter { $0.dayKey == today }
            .reduce(0) { $0 + $1.delta }
    }

    private func logDone() {
        // Lands exactly on target (done) or exactly on 0 (cleared),
        // whatever today's total already was — not a blind ±1, which left
        // over-accumulated habits unclearable in a single tap. Counted
        // habits get +1 per tap for now — a real stepper is future work.
        let delta = toggleDelta(currentTotal: todayTotal, target: habit.target)
        logHabit(habit, delta: delta, source: .manual, modelContext: modelContext)
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: habit.symbolName)
                .font(.system(size: iconSize * 0.53))
                .foregroundStyle(Color("Ink"))
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 3) {
                NavigationLink(destination: HabitDetailView(habit: habit)) {
                    Text(habit.name)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("Ink"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)

                if habit.kind == .counted {
                    HStack(spacing: 7) {
                        TallyMarks(done: todayTotal, target: habit.target)
                        Text("\(todayTotal) of \(habit.target)\(habit.unit.map { " \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(Color("Ink").opacity(0.7))
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if habit.kind == .binary {
                Button(action: logDone) {
                    CheckCircle(isDone: todayTotal >= habit.target)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
