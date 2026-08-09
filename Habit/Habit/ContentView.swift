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
                Text(habit.name)
            }
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

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
