//
//  GentleModeView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

/// One switch for a bad week (spec §6). Each habit carries a `gentleEnabled`
/// flag set once, in calmer weather; flipping the single global switch
/// rests every flagged habit indefinitely, until flipped back. Unlike
/// Vacation Mode there's no end date — the 14-day safeguard under the
/// Today header is what stands in for one.
struct GentleModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Deliberately NOT `@Query(sort: habitSortDescriptors)` — a sorted
    // `@Query` stops noticing changes to properties/relationships that
    // aren't part of the sort key (see `HabitOrdering.swift`'s
    // `sortedForDisplay` doc comment). `gentleEnabled` and `pauses` aren't
    // in `habitSortDescriptors`, so a sorted query here went stale after a
    // per-habit toggle and the global switch reconciled against a
    // habits array that no longer reflected reality — the open-ended
    // `.gentle` `Pause` never closed. Sort the fetched array for display
    // instead, matching every other screen in the app.
    @Query private var habits: [Habit]
    @AppStorage(GentleModeStorage.startedAtDayKeyDefaultsKey) private var startedAtDayKey = 0

    private var isOn: Bool { startedAtDayKey > 0 }
    private var todayKeyValue: Int { dayKey(for: Date()) }

    private var restingHabits: [Habit] { sortedForDisplay(habits).filter(\.gentleEnabled) }
    private var carryingOnHabits: [Habit] { sortedForDisplay(habits).filter { !$0.gentleEnabled } }

    private var startedAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "On since \(formatter.string(from: date(fromDayKey: startedAtDayKey)))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusBox

                    if isOn, restingHabits.isEmpty {
                        Text("Nothing is set to rest yet — tick habits below.")
                            .font(.footnote)
                            .foregroundStyle(Color("Tertiary"))
                    }

                    Text("While it's on, these rest. Their days are recorded as paused, never as missed, and nothing nudges you.")
                        .font(.subheadline)
                        .foregroundStyle(Color("Ink").opacity(0.7))

                    if !restingHabits.isEmpty {
                        section(title: "Resting", habits: restingHabits)
                    }
                    if !carryingOnHabits.isEmpty {
                        section(title: "Carrying on", habits: carryingOnHabits)
                    }

                    Text("Turn a habit's checkbox on or off any time — the switch just obeys it.")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color("Tertiary"))
                }
                .padding(.horizontal, contentMargin)
                .padding(.vertical, 20)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .navigationTitle("Gentle Mode")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.habitPrimary)
                }
            }
        }
    }

    private var statusBox: some View {
        HStack(spacing: 15) {
            Image(systemName: "moon")
                .font(.system(size: 20))
                .foregroundStyle(Color("Ink"))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gentle Mode")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color("Ink"))
                if isOn {
                    Text(startedAtText)
                        .font(.caption)
                        .foregroundStyle(Color("Tertiary"))
                }
            }

            Spacer(minLength: 0)

            Toggle("Gentle Mode", isOn: Binding(get: { isOn }, set: setGlobalSwitch))
                .labelsHidden()
                .tint(Color("Ink"))
        }
        .padding(15)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color("Rule"), lineWidth: 1))
    }

    private func section(title: String, habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(title)
                .padding(.bottom, 8)

            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                habitRow(habit)
                if index < habits.count - 1 {
                    Divider().overlay(Color("Rule"))
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        Button {
            habit.gentleEnabled.toggle()
            reconcileGentleMode(isOn: isOn, habits: [habit], today: todayKeyValue, modelContext: modelContext)
        } label: {
            HStack(spacing: 13) {
                MarkCheckbox(isOn: habit.gentleEnabled)

                Image(systemName: habit.symbolName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color("Ink"))
                    .opacity(habit.gentleEnabled ? 1 : 0.5)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("Ink"))
                        .opacity(habit.gentleEnabled ? 1 : 0.55)

                    if habit.gentleEnabled, isOn {
                        Text(pausedDurationText(for: habit))
                            .font(.caption)
                            .foregroundStyle(Color("Tertiary"))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pausedDurationText(for habit: Habit) -> String {
        guard let openPause = habit.pauses.first(where: { $0.reason == .gentle && $0.endDay == nil }) else {
            return ""
        }
        let days = Calendar.current.dateComponents(
            [.day],
            from: date(fromDayKey: openPause.startDay),
            to: date(fromDayKey: todayKeyValue)
        ).day ?? 0
        let total = days + 1 // inclusive of the day it started
        return total == 1 ? "Paused 1 day" : "Paused \(total) days"
    }

    private func setGlobalSwitch(_ newValue: Bool) {
        startedAtDayKey = newValue ? todayKeyValue : 0
        reconcileGentleMode(isOn: newValue, habits: habits, today: todayKeyValue, modelContext: modelContext)
    }
}

#Preview {
    GentleModeView()
        .modelContainer(for: Habit.self, inMemory: true)
}
