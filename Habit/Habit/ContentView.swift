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
    @Query private var habits: [Habit]

    var body: some View {
        List(habits) { habit in
            Text(habit.name)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
