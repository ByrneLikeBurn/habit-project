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
    @State private var showingDatePicker = false

    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: endDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // This is the whole point of the feature, stated up
                    // front — without it, a paused week and a missed week
                    // look identical, and nobody would trust turning it on.
                    Text("Rested days are recorded as paused, never as missed.")
                        .font(.subheadline)
                        .foregroundStyle(Color("Ink").opacity(0.7))

                    endDateSection
                    habitsSection
                }
                .padding(.horizontal, contentMargin)
                .padding(.vertical, 20)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
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

    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Until")
            Button {
                showingDatePicker = true
            } label: {
                Text(formattedEndDate)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color("Ink"))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingDatePicker) {
                DatePicker("Until", selection: $endDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
            }
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Resting while you're away")
                .padding(.bottom, 10)

            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                habitRow(habit)
                if index < habits.count - 1 {
                    Divider().overlay(Color("Rule"))
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let isSelected = selectedHabitIDs.contains(habit.id)

        return Button {
            toggle(habit)
        } label: {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color("Ink") : Color.clear)
                    .frame(width: 21, height: 21)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(isSelected ? Color("Ink") : Color("Rule"), lineWidth: 1.3)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color("Paper"))
                        }
                    }

                Image(systemName: habit.symbolName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color("Ink"))
                    .opacity(isSelected ? 1 : 0.5)
                    .frame(width: 22, height: 22)

                Text(habit.name)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color("Ink"))
                    .opacity(isSelected ? 1 : 0.55)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

/// The small uppercase, letter-spaced section label used throughout the app
/// (see `TodayHeader`'s date line in `ContentView`).
private struct Eyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(Color("Tertiary"))
    }
}

#Preview {
    VacationModeView()
        .modelContainer(for: Habit.self, inMemory: true)
}
