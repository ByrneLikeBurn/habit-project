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
    @Query private var habits: [Habit]

    @State private var name = ""
    @State private var symbolName = HabitIcons.all[0]
    @State private var showingIconPicker = false
    @FocusState private var nameFieldFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func save() {
        guard canSave else { return }
        let habit = Habit(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
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
