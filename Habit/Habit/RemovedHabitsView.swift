//
//  RemovedHabitsView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit

/// Reached from Settings (spec's mockups §17). Two lists: habits hidden from
/// Today but restorable whole, and habits on their way out entirely. "Delete
/// now" is the only path into `PermanentDeleteConfirmationView` — nothing
/// here deletes anything without that stop first.
struct RemovedHabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allHabits: [Habit]

    @State private var habitPendingPermanentDeletion: Habit?

    private var archivedHabits: [Habit] {
        allHabits.filter { $0.archivedAt != nil && $0.deletedAt == nil }
    }

    private var recentlyDeletedHabits: [Habit] {
        allHabits.filter { $0.deletedAt != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !archivedHabits.isEmpty {
                    archivedSection
                }

                if !recentlyDeletedHabits.isEmpty {
                    recentlyDeletedSection
                }

                if archivedHabits.isEmpty && recentlyDeletedHabits.isEmpty {
                    Text("Nothing archived or deleted.")
                        .font(.footnote)
                        .foregroundStyle(Color("Tertiary"))
                }

                VStack(alignment: .leading, spacing: 10) {
                    ExportButton(habits: allHabits, label: "Export Everything as JSON")

                    Text("Nothing here is ever uploaded anywhere but your own iCloud.")
                        .font(.footnote)
                        .foregroundStyle(Color("Tertiary"))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, contentMargin)
            .padding(.vertical, 20)
            .frame(maxWidth: readableContentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color("Paper"))
        .navigationTitle("Habits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $habitPendingPermanentDeletion) { habit in
            PermanentDeleteConfirmationView(habit: habit, allHabits: allHabits) {
                permanentlyDelete(habit, modelContext: modelContext)
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Archived")
                .padding(.bottom, 4)

            Text("Hidden from Today. History kept in full.")
                .font(.footnote)
                .foregroundStyle(Color("Tertiary"))
                .padding(.bottom, 8)

            ForEach(archivedHabits) { habit in
                removedHabitRow(habit, iconOpacity: 0.5, nameOpacity: 0.65, meta: "\(loggedDayCount(for: habit)) days logged") {
                    Chip(label: "Restore", isSelected: false) {
                        restoreFromArchive(habit, modelContext: modelContext)
                    }
                }
            }
        }
    }

    private var recentlyDeletedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Recently Deleted")
                .padding(.bottom, 4)

            Text("Removed for good after 30 days.")
                .font(.footnote)
                .foregroundStyle(Color("Tertiary"))
                .padding(.bottom, 8)

            ForEach(recentlyDeletedHabits) { habit in
                removedHabitRow(habit, iconOpacity: 0.35, nameOpacity: 0.5, meta: recentlyDeletedMeta(for: habit)) {
                    HStack(spacing: 9) {
                        Chip(label: "Restore", isSelected: false) {
                            restoreFromRecentlyDeleted(habit, modelContext: modelContext)
                        }
                        Chip(label: "Delete Now", isSelected: false) {
                            habitPendingPermanentDeletion = habit
                        }
                    }
                }
            }
        }
    }

    private func recentlyDeletedMeta(for habit: Habit) -> String {
        let logged = loggedDayCount(for: habit)
        guard let deletedAt = habit.deletedAt else { return "\(logged) days logged" }
        let daysLeft = daysRemainingBeforePurge(deletedAt: deletedAt)
        return "\(logged) days logged \u{00B7} \(daysLeft) days left"
    }

    private func removedHabitRow(
        _ habit: Habit,
        iconOpacity: Double,
        nameOpacity: Double,
        meta: String,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                Image(systemName: habit.symbolName)
                    .font(.system(size: 17))
                    .foregroundStyle(Color("Ink").opacity(iconOpacity))
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("Ink").opacity(nameOpacity))
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(Color("Tertiary"))
                }

                Spacer(minLength: 0)
            }

            actions()
                .padding(.leading, 49)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(Color("Rule"))
        }
    }
}

#Preview {
    NavigationStack {
        RemovedHabitsView()
    }
    .modelContainer(for: Habit.self, inMemory: true)
}
