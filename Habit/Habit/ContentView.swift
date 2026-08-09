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

    var body: some View {
        NavigationStack {
            List(habits) { habit in
                HabitRow(habit: habit)
                    .listRowBackground(Color("Paper"))
                    .listRowSeparatorTint(Color("Rule"))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color("Paper"))
            .toolbar {
                ToolbarItem {
                    Button(action: addHabit) {
                        Label("Add Habit", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addHabit() {
        let habit = Habit(name: "New Habit", symbolName: "circle")
        modelContext.insert(habit)
    }
}

private struct HabitRow: View {
    let habit: Habit

    private var todayTotal: Int {
        let today = dayKey(for: Date())
        return habit.events
            .filter { $0.dayKey == today }
            .reduce(0) { $0 + $1.delta }
    }

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color("Ink"))

                if habit.kind == .counted {
                    HStack(spacing: 7) {
                        TallyMarks(done: todayTotal, target: habit.target)
                        Text("\(todayTotal) of \(habit.target)\(habit.unit.map { " \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(Color("Ink").opacity(0.7))
                    }
                }
            }

            Spacer()

            if habit.kind == .binary {
                CheckCircle(isDone: todayTotal >= habit.target)
            }
        }
        .padding(.vertical, 15)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
