//
//  HabitDetailView.swift
//  Habit
//

import SwiftUI
import HabitKit

struct HabitDetailView: View {
    @Bindable var habit: Habit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Name", text: $habit.name)
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                    .foregroundStyle(Color("Ink"))
                    .textFieldStyle(.plain)

                MonthHeatMap(habit: habit, referenceDate: Date())
            }
            .padding(.horizontal, contentMargin)
            .padding(.top, 20)
            .frame(maxWidth: readableContentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color("Paper"))
        .navigationTitle(habit.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", symbolName: "book", scheduleMask: 127))
    }
}
