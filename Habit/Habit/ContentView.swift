//
//  ContentView.swift
//  Habit
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import HabitKit

private let sortModeDefaultsKey = "habitSortMode"

struct ContentView: View {
    @Query(filter: #Predicate<Habit> { $0.archivedAt == nil && $0.deletedAt == nil })
    private var habits: [Habit]
    @Query(filter: #Predicate<Habit> { $0.deletedAt != nil })
    private var recentlyDeletedHabits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(sortModeDefaultsKey) private var sortModeRawValue = HabitSortMode.manual.rawValue
    @State private var draggingHabitID: UUID?
    @State private var showingVacationMode = false
    @State private var showingGentleMode = false
    @State private var showingNewHabit = false
    @State private var showingSettings = false

    private var sortMode: HabitSortMode { HabitSortMode(rawValue: sortModeRawValue) ?? .manual }
    private var todayKeyValue: Int { dayKey(for: Date()) }

    /// Habits currently covered by a `Pause` — vacation or Gentle Mode. They
    /// leave the Today list, per spec §6, but stay loggable from the habit
    /// detail screen.
    private var restingHabits: [Habit] {
        sortedForDisplay(habits).filter { habit in
            habit.pauses.contains { $0.covers(todayKeyValue) }
        }
    }

    private var unpausedHabits: [Habit] {
        habits.filter { habit in !habit.pauses.contains { $0.covers(todayKeyValue) } }
    }

    /// Only Focus habits nudge and reach the (future) widget and
    /// complication (spec §5) — everything else is loggable but quiet.
    private var focusHabits: [Habit] {
        sortedHabits(unpausedHabits.filter(\.isFocus), mode: sortMode)
    }

    private var restHabits: [Habit] {
        sortedHabits(unpausedHabits.filter { !$0.isFocus }, mode: sortMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    TodayHeader(restingHabits: restingHabits, today: todayKeyValue)
                        .padding(.top, 14)
                        .padding(.bottom, 20)

                    sortModeChips
                        .padding(.bottom, 4)

                    if !focusHabits.isEmpty {
                        SectionEyebrow("Focus")
                            .padding(.top, 16)
                            .padding(.bottom, 4)

                        ForEach(Array(focusHabits.enumerated()), id: \.element.id) { index, habit in
                            HabitRow(habit: habit, allHabits: habits)
                            if index < focusHabits.count - 1 {
                                RuleDivider()
                            }
                        }

                        RuleDivider()
                            .padding(.top, 8)
                    }

                    if !restHabits.isEmpty {
                        SectionEyebrow(focusHabits.isEmpty ? "Habits" : "Everything else")
                            .padding(.top, 16)
                            .padding(.bottom, 4)

                        ForEach(Array(restHabits.enumerated()), id: \.element.id) { index, habit in
                            reorderableRestRow(habit)
                            if index < restHabits.count - 1 {
                                RuleDivider()
                            }
                        }
                    }
                }
                .padding(.horizontal, contentMargin)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .toolbar {
                ToolbarItem {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem {
                    Button {
                        showingGentleMode = true
                    } label: {
                        Label("Gentle Mode", systemImage: "moon")
                    }
                }
                ToolbarItem {
                    Button {
                        showingVacationMode = true
                    } label: {
                        Label("Vacation Mode", systemImage: "airplane")
                    }
                }
                ToolbarItem {
                    Button {
                        showingNewHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.habitPrimary)
                    .accessibilityLabel("Add Habit")
                }
            }
            .sheet(isPresented: $showingVacationMode) {
                VacationModeView()
            }
            .sheet(isPresented: $showingGentleMode) {
                GentleModeView()
            }
            .sheet(isPresented: $showingNewHabit) {
                NewHabitView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await NotificationScheduler.reschedule(habits: habits) }
            }
            // A date comparison at launch, not a scheduled task (spec §9) —
            // a device that's been off for months still purges correctly
            // the moment it's opened, and re-running this is a no-op, which
            // is what keeps two devices on day 31 from needing to coordinate.
            .task {
                purgeExpiredDeletions(habits: recentlyDeletedHabits, modelContext: modelContext)
            }
        }
    }

    private var sortModeChips: some View {
        HStack(spacing: 8) {
            Chip(label: "Manual", isSelected: sortMode == .manual) { sortModeRawValue = HabitSortMode.manual.rawValue }
            Chip(label: "By time", isSelected: sortMode == .byTime) { sortModeRawValue = HabitSortMode.byTime.rawValue }
            Chip(label: "Smart", isSelected: sortMode == .smart) { sortModeRawValue = HabitSortMode.smart.rawValue }
        }
    }

    /// Drag-to-reorder only does anything in Manual mode — in By Time or
    /// Smart the list is computed, and a drag would just be undone on the
    /// next render.
    private func reorderableRestRow(_ habit: Habit) -> some View {
        HabitRow(habit: habit, allHabits: habits)
            .opacity(draggingHabitID == habit.id ? 0.5 : 1)
            .onDrag {
                guard sortMode == .manual else { return NSItemProvider() }
                draggingHabitID = habit.id
                return NSItemProvider(object: habit.id.uuidString as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: HabitDropDelegate(
                    habit: habit,
                    habits: restHabits,
                    draggingHabitID: $draggingHabitID,
                    isEnabled: sortMode == .manual
                )
            )
    }
}

/// Reorders `habits` by moving whichever one is being dragged to the
/// position it's hovering over, renumbering `sortIndex` as it goes. Only
/// `sortIndex` within this one group is touched — Focus and "Everything
/// else" are sorted independently, so their index spaces don't need to
/// stay distinct from each other.
private struct HabitDropDelegate: DropDelegate {
    let habit: Habit
    let habits: [Habit]
    @Binding var draggingHabitID: UUID?
    let isEnabled: Bool

    func dropEntered(info: DropInfo) {
        guard isEnabled,
              let draggingHabitID,
              draggingHabitID != habit.id,
              let fromIndex = habits.firstIndex(where: { $0.id == draggingHabitID }),
              let toIndex = habits.firstIndex(where: { $0.id == habit.id })
        else { return }

        var reordered = habits
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
        for (index, reorderedHabit) in reordered.enumerated() {
            reorderedHabit.sortIndex = index
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingHabitID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct RuleDivider: View {
    var body: some View {
        Divider()
            .overlay(Color("Rule"))
    }
}

private struct TodayHeader: View {
    let restingHabits: [Habit]
    let today: Int

    @AppStorage(GentleModeStorage.startedAtDayKeyDefaultsKey) private var gentleModeStartedAtDayKey = 0
    @AppStorage(GentleModeStorage.safeguardDismissedDefaultsKey) private var gentleModeSafeguardDismissedForDayKey = 0

    /// The one quiet, dismissible line the whole safeguard consists of
    /// (spec §6) — no notification, ever, and it only appears once per
    /// continuous on-period.
    private var showGentleModeSafeguard: Bool {
        gentleModeSafeguardDismissedForDayKey != gentleModeStartedAtDayKey
            && gentleModeHasBeenOnForTwoWeeks(startedAtDayKey: gentleModeStartedAtDayKey, today: today)
    }

    private var eyebrow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: "Good morning."
        case 12..<18: "Good afternoon."
        default: "Good evening."
        }
    }

    /// e.g. "3 resting until 20 August" — the quiet, guilt-free acknowledgement
    /// that Vacation Mode is doing something, since the habits themselves
    /// have already left the list below.
    private var restingSummary: String? {
        guard !restingHabits.isEmpty else { return nil }

        let endDays = restingHabits.compactMap { habit in
            habit.pauses.first { $0.covers(today) }?.endDay
        }

        guard let latestEndDay = endDays.max() else {
            return "\(restingHabits.count) resting"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        let untilDate = formatter.string(from: date(fromDayKey: latestEndDay))
        return "\(restingHabits.count) resting until \(untilDate)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color("Tertiary"))

            Text(greeting)
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(Color("Ink"))
                .fixedSize(horizontal: false, vertical: true)

            if let restingSummary {
                Text(restingSummary)
                    .font(.footnote)
                    .foregroundStyle(Color("Tertiary"))
            }

            if showGentleModeSafeguard {
                HStack(spacing: 6) {
                    Text("Gentle Mode has been on for two weeks.")
                        .font(.footnote)
                        .foregroundStyle(Color("Tertiary"))

                    Button {
                        gentleModeSafeguardDismissedForDayKey = gentleModeStartedAtDayKey
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color("Tertiary"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitRow: View {
    let habit: Habit
    let allHabits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 8

    private var todayTotal: Int {
        let today = dayKey(for: Date())
        return habit.events
            .filter { $0.dayKey == today }
            .reduce(0) { $0 + $1.delta }
    }

    private func logDone() {
        // Lands exactly on target (done) or exactly on 0 (cleared),
        // whatever today's total already was — not a blind ±1, which left
        // over-accumulated habits unclearable in a single tap. Counted
        // habits get +1 per tap for now — a real stepper is future work.
        let delta = toggleDelta(currentTotal: todayTotal, target: habit.target)
        logHabit(habit, delta: delta, source: .manual, modelContext: modelContext)
        Task { await NotificationScheduler.reschedule(habits: allHabits) }
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: habit.symbolName)
                .font(.system(size: iconSize * 0.53))
                .foregroundStyle(Color("Ink"))
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 3) {
                NavigationLink(destination: HabitDetailView(habit: habit)) {
                    Text(habit.name)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("Ink"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)

                if habit.kind == .counted {
                    HStack(spacing: 7) {
                        TallyMarks(done: todayTotal, target: habit.target)
                        Text("\(todayTotal) of \(habit.target)\(habit.unit.map { " \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(Color("Ink").opacity(0.7))
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if habit.kind == .binary {
                Button(action: logDone) {
                    CheckCircle(isDone: todayTotal >= habit.target)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
