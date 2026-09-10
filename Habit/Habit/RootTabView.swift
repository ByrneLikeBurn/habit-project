//
//  RootTabView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

/// Four tabs (spec §63): Today's the list and check-offs, Progress the
/// all-habit ledger, Tags the NFC screens, You the settings tree. Progress
/// and Tags have nothing behind them yet — placeholders until §7 and §63's
/// history view land. Replaces `ContentView`'s toolbar, which was interim
/// scaffolding standing in for this.
struct RootTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }

            NavigationStack {
                PlaceholderView(text: "Every habit's ledger, side by side. Not built yet.")
                    .navigationTitle("Progress")
            }
            .tabItem {
                Label("Progress", systemImage: "square.grid.3x3")
            }

            NavigationStack {
                PlaceholderView(text: "NFC tags, so logging doesn't need the app. Not built yet.")
                    .navigationTitle("Tags")
            }
            .tabItem {
                Label("Tags", systemImage: "wave.3.right")
            }

            SettingsView()
                .tabItem {
                    Label("You", systemImage: "gearshape")
                }
        }
    }
}

private struct PlaceholderView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color("Tertiary"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, contentMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Paper"))
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Habit.self, LogEvent.self, Pause.self, AppSettings.self], inMemory: true)
}
