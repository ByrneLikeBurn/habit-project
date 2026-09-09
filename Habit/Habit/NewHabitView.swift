//
//  NewHabitView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

/// Creating a habit (spec's mockups §5): pick a mark, then name it.
struct NewHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { $0.archivedAt == nil && $0.deletedAt == nil })
    private var habits: [Habit]

    @State private var name = ""
    @State private var symbolName = HabitIcons.all[0]
    @State private var showingIconPicker = false
    @State private var kind: HabitKind = .binary
    @State private var target = 1
    @State private var unit = ""
    @State private var scheduleMask = 127
    @State private var showingWeekdayChips = false
    @FocusState private var nameFieldFocused: Bool

    private static let weekdayAbbreviations = ["S", "M", "T", "W", "T", "F", "S"]
    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && scheduleMask != 0
    }

    /// "Every day" is the only wording the spec's mockups actually show for
    /// this row (§5); any other combination just lists the days it covers.
    /// No empty case — `canSave` keeps `scheduleMask` from ever reaching zero
    /// at Save.
    private var repeatsSummary: String {
        if scheduleMask == 127 { return "Every day" }
        return (0..<7)
            .filter { scheduleMask & (1 << $0) != 0 }
            .map { Self.weekdayNames[$0] }
            .joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Button {
                        showingIconPicker = true
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: symbolName)
                                .font(.system(size: 30))
                                .foregroundStyle(Color("Ink"))
                                .frame(width: 64, height: 64)
                                .overlay(Circle().strokeBorder(Color("Rule"), lineWidth: 1))

                            Text("Change mark")
                                .font(.caption)
                                .foregroundStyle(Color("Tertiary"))
                        }
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $name)
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(Color("Ink"))
                        .multilineTextAlignment(.center)
                        .focused($nameFieldFocused)
                        .textFieldStyle(.plain)
                        .padding(.bottom, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color("Rule")).frame(height: 1)
                        }
                        .onSubmit(save)

                    measurementSection

                    if kind == .counted {
                        targetSection
                    }

                    repeatsSection
                }
                .padding(.horizontal, contentMargin)
                .padding(.top, 24)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.habitSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.habitPrimary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedSymbolName: $symbolName)
            }
            .onAppear {
                nameFieldFocused = true
            }
        }
    }

    /// "Is this done-or-not, or does it have a number?" (spec's mockups §5)
    /// — the one real decision this screen asks for.
    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("How is it measured")
            HStack(spacing: 8) {
                Chip(label: "Done or not", isSelected: kind == .binary) { kind = .binary }
                Chip(label: "A number", isSelected: kind == .counted) { kind = .counted }
            }
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow("Target") {
                Stepper(value: $target, in: 1...999) {
                    Text("\(target)")
                        .font(.body)
                        .foregroundStyle(Color("Ink"))
                }
                .tint(Color("Ink"))
            }
            Divider().overlay(Color("Rule"))
            fieldRow("Unit") {
                TextField("pages, minutes, glasses", text: $unit)
                    .font(.body)
                    .foregroundStyle(Color("Ink"))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
        }
    }

    private var repeatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingWeekdayChips.toggle()
            } label: {
                fieldRow("Repeats") {
                    HStack(spacing: 6) {
                        Text(repeatsSummary)
                            .font(.body)
                            .foregroundStyle(Color("Ink").opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("Rule"))
                            .rotationEffect(.degrees(showingWeekdayChips ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)

            if showingWeekdayChips {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        Chip(
                            label: Self.weekdayAbbreviations[day],
                            isSelected: scheduleMask & (1 << day) != 0
                        ) {
                            scheduleMask ^= 1 << day
                        }
                    }
                }
            }

            if scheduleMask == 0 {
                Text("Pick at least one day")
                    .font(.caption)
                    .foregroundStyle(Color("Tertiary"))
            }
        }
    }

    private func fieldRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(Color("Ink"))
            Spacer(minLength: 12)
            value()
        }
        .padding(.vertical, 12)
    }

    private func save() {
        guard canSave else { return }
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let habit = Habit(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            kind: kind,
            target: kind == .binary ? 1 : target,
            unit: kind == .binary ? nil : (trimmedUnit.isEmpty ? nil : trimmedUnit),
            scheduleMask: scheduleMask,
            sortIndex: nextSortIndex(after: habits),
            // The first habit a new user creates is automatically Focus
            // (spec §5) — "start with one" survives contact with a list of
            // twenty because that one habit is already the one that nudges.
            isFocus: habits.isEmpty
        )
        modelContext.insert(habit)
        dismiss()
    }
}

#Preview {
    NewHabitView()
        .modelContainer(for: Habit.self, inMemory: true)
}
