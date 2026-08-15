//
//  PermanentDeleteConfirmationView.swift
//  Habit
//

import SwiftUI
import HabitKit

/// Spec §9's one destructive confirmation, reached only from "Delete now" in
/// Recently Deleted. States the cost in days rather than asking "are you
/// sure", offers export first, and puts the safe option ("Keep It") where
/// the thumb lands. The only place in the app that uses the word
/// "permanently" — everywhere else, absence is temporary by design.
struct PermanentDeleteConfirmationView: View {
    let habit: Habit
    let allHabits: [Habit]
    let onConfirmDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: habit.symbolName)
                .font(.system(size: 30))
                .foregroundStyle(Color("Ink"))
                .padding(.top, 8)

            Text("Delete \u{201C}\(habit.name)\u{201D} permanently?")
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(Color("Ink"))
                .multilineTextAlignment(.center)

            Text(permanentDeletionCostSummary(for: habit))
                .font(.body)
                .foregroundStyle(Color("Ink").opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ExportButton(habits: allHabits, label: "Export It First", fillsWidth: true)

                HStack(spacing: 10) {
                    Button {
                        onConfirmDelete()
                        dismiss()
                    } label: {
                        Text("Delete").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.habitSecondary)

                    Button {
                        dismiss()
                    } label: {
                        Text("Keep It").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.habitPrimary)
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: readableContentMaxWidth)
        .background(Color("Paper"))
    }
}

#Preview {
    let habit = Habit(name: "Cold shower", symbolName: "drop")
    return PermanentDeleteConfirmationView(habit: habit, allHabits: [habit]) {}
}
