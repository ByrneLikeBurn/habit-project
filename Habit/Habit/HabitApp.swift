//
//  HabitApp.swift
//  Habit
//
//  Created by Liam Byrne on 8/8/26.
//

import SwiftUI
import SwiftData
import HabitKit

@main
struct HabitApp: App {
    // Static so `LogHabitIntent` and `HabitEntityQuery` — invoked by
    // Shortcuts/Siri outside any SwiftUI view hierarchy — can open a
    // `ModelContext` on the same container the app's own views use.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            LogEvent.self,
            Pause.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .frame(minWidth: 380)
#endif
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
