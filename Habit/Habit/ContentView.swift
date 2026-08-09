//
//  ContentView.swift
//  Habit
//
//  Created by Liam Byrne on 8/8/26.
//

import SwiftUI
import SwiftData
import HabitKit

private let contentMargin: CGFloat = 26

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                TodayHeader()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 14, leading: contentMargin, bottom: 20, trailing: contentMargin))
                    .listRowBackground(Color("Paper"))

                ForEach(habits) { habit in
                    HabitRow(habit: habit)
                        .listRowInsets(EdgeInsets(top: 0, leading: contentMargin, bottom: 0, trailing: contentMargin))
                        .listRowBackground(Color("Paper"))
                        .listRowSeparatorTint(Color("Rule"))
                }
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

private struct TodayHeader: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color("Tertiary"))

            Text(greeting)
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(Color("Ink"))
        }
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
            Image(systemName: habit.symbolName)
                .font(.system(size: 18))
                .foregroundStyle(Color("Ink"))
                .frame(width: 34, height: 34)

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
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
