//
//  VacationModeView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

/// Planned, dated pausing for a trip (spec §6) — pick habits, set an end
/// date, and it resumes itself. Distinct from Gentle Mode, which is
/// unplanned, undated, and one global switch (not built yet).
struct VacationModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: habitSortDescriptors) private var habits: [Habit]

    @State private var selectedHabitIDs: Set<UUID> = []
    @State private var hasPreselected = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Habits") {
                    ForEach(habits) { habit in
                        Button {
                            toggle(habit)
                        } label: {
                            HStack {
                                Text(habit.name)
                                    .foregroundStyle(Color("Ink"))
                                Spacer()
                                if selectedHabitIDs.contains(habit.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("Ink"))
                                }
                            }
                        }
                    }
                }

                Section("Ends") {
                    DatePicker("End date", selection: $endDate, in: Date()..., displayedComponents: .date)
                }
            }
            .navigationTitle("Vacation Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { confirm() }
                        .disabled(selectedHabitIDs.isEmpty)
                }
            }
            .onAppear {
                guard !hasPreselected else { return }
                hasPreselected = true
                selectedHabitIDs = Set(habits.filter(\.vacationByDefault).map(\.id))
            }
        }
    }

    private func toggle(_ habit: Habit) {
        if selectedHabitIDs.contains(habit.id) {
            selectedHabitIDs.remove(habit.id)
        } else {
            selectedHabitIDs.insert(habit.id)
        }
    }

    private func confirm() {
        let selected = habits.filter { selectedHabitIDs.contains($0.id) }
        startVacation(for: selected, endDay: dayKey(for: endDate), modelContext: modelContext)
        dismiss()
    }
}

#Preview {
    VacationModeView()
        .modelContainer(for: Habit.self, inMemory: true)
}
