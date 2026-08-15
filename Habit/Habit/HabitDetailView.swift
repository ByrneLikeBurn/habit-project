//
//  HabitDetailView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

struct HabitDetailView: View {
    @Bindable var habit: Habit

    @Environment(\.modelContext) private var modelContext
    @AppStorage(GentleModeStorage.startedAtDayKeyDefaultsKey) private var gentleModeStartedAtDayKey = 0

    private var isGentleModeOn: Bool { gentleModeStartedAtDayKey > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Name", text: $habit.name)
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                    .foregroundStyle(Color("Ink"))
                    .textFieldStyle(.plain)

                MonthHeatMap(habit: habit, referenceDate: Date())

                pausingSection
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

    private var pausingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Pausing")
                .padding(.bottom, 8)

            Button {
                habit.gentleEnabled.toggle()
                reconcileGentleMode(isOn: isGentleModeOn, habits: [habit], modelContext: modelContext)
            } label: {
                HStack(spacing: 13) {
                    MarkCheckbox(isOn: habit.gentleEnabled)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gentle Mode enabled")
                            .foregroundStyle(Color("Ink"))
                        Text("Rests when you turn Gentle Mode on")
                            .font(.caption)
                            .foregroundStyle(Color("Tertiary"))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", symbolName: "book", scheduleMask: 127))
    }
}
