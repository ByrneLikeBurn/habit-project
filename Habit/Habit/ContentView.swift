//
//  ContentView.swift
//  Habit
//

import SwiftUI
import SwiftData
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
                // Every row below carries an explicit, section-prefixed
                // `.id(...)` (e.g. "resting-<uuid>" vs "rest-<uuid>") on top
                // of whatever identity `ForEach`'s own `id:` gives it. A
                // habit moving between sections — e.g. Wake taking it out
                // of Resting and into this list — is a genuine change of
                // view type (`RestingRow` to `HabitRow`), not a move within
                // the same list, but sharing the bare habit UUID as the
                // only identity let SwiftUI conflate the two across the
                // two ForEach loops: the row kept rendering as the old
                // RestingRow, Wake button and all, after "moving." The
                // prefix makes the two sections' identities disjoint so
                // that can't happen.
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
                                .id("focus-\(habit.id)")
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
                            HabitRow(habit: habit, allHabits: habits)
                                .id("rest-\(habit.id)")
                            if index < restHabits.count - 1 {
                                RuleDivider()
                            }
                        }
                    }

                    // Pause state used to be visible only by opening the
                    // Gentle or Vacation Mode screens — invisible, and
                    // unfixable, if either ever left a habit stuck resting.
                    // This is the direct, always-visible escape hatch:
                    // every currently-paused habit, why, and a way to wake
                    // it on the spot.
                    if !restingHabits.isEmpty {
                        SectionEyebrow("Resting")
                            .padding(.top, 16)
                            .padding(.bottom, 4)

                        ForEach(Array(restingHabits.enumerated()), id: \.element.id) { index, habit in
                            RestingRow(habit: habit, today: todayKeyValue)
                                .id("resting-\(habit.id)")
                            if index < restingHabits.count - 1 {
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
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
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

    // Drag-to-reorder is deliberately not implemented right now. It was
    // removed while chasing an unrelated bug (check-off not registering —
    // the actual cause turned out to be missing `.contentShape`, see
    // `HabitRow`), on the reasonable but not fully substantiated suspicion
    // that `.onDrag`/`.onDrop`/`.draggable` were involved; neither the old
    // nor the new drag API pair was ever confirmed to reliably reorder
    // rows in the first place. Logging a habit is the app's core, everyday
    // action; reordering is a lower-priority feature (spec's own build
    // order puts Ordering after Core loop), so it stayed off rather than
    // spending more time re-verifying it blind. Re-adding it needs its own
    // deliberate pass — including checking whether the same hit-testing
    // ambiguity `.contentShape` just fixed also affects it.
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

    /// e.g. "Gentle Mode is on — 3 habits resting" — names the cause rather
    /// than just the count (spec §6), so this line alone tells you *why*
    /// habits are missing from the list below instead of leaving that to a
    /// mode screen you'd have to go dig into.
    private var restingSummary: String? {
        todayRestingSummary(restingHabits, today: today)
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

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 8

    private var todayTotal: Int {
        let today = dayKey(for: Date())
        return habit.events
            .filter { $0.dayKey == today }
            .reduce(0) { $0 + $1.delta }
    }

    /// Routes through `LogHabitIntent` — the same App Intent Shortcuts, NFC
    /// and Siri use — rather than calling `logHabit` a second way, so
    /// there's genuinely one write path (CLAUDE.md's invariant). The
    /// toggle-to-target-or-zero math lives once, inside the intent.
    private func logDone() {
        Task {
            var intent = LogHabitIntent()
            intent.habit = HabitEntity(habit: habit)
            intent.source = .manual
            _ = try? await intent.perform()
            await NotificationScheduler.reschedule(habits: allHabits)
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: habit.symbolName)
                .font(.system(size: iconSize * 0.53))
                .foregroundStyle(Color("Ink"))
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 3) {
                // `.contentShape(Rectangle())` here and on the check-off
                // button below is load-bearing, not decoration: two sibling
                // interactive controls sharing one HStack, inside this
                // ForEach/LazyVStack/ScrollView structure, silently failed
                // to register *any* click on macOS without it — confirmed
                // by driving real accessibility clicks via XCUITest and
                // checking the persisted store directly. A row with only
                // one control (Resting's Wake) or a flat, non-repeated
                // group of buttons (the sort-mode chips) never had this
                // problem; only rows with two-or-more sibling controls did.
                NavigationLink(value: habit) {
                    Text(habit.name)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color("Ink"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityIdentifier("habitName-\(habit.id.uuidString)")

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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("checkCircle-\(habit.id.uuidString)")
            }
        }
        .padding(.vertical, rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RestingRow: View {
    let habit: Habit
    let today: Int

    @Environment(\.modelContext) private var modelContext

    private var reasonLabel: String? {
        guard let pause = habit.pauses.first(where: { $0.covers(today) }) else { return nil }
        return switch pause.reason {
        case .gentle: "Gentle"
        case .vacation: "Vacation"
        case .manual: "Paused"
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: habit.symbolName)
                .font(.system(size: 15))
                .foregroundStyle(Color("Ink").opacity(0.5))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color("Ink").opacity(0.65))
                if let reasonLabel {
                    Text(reasonLabel)
                        .font(.caption)
                        .foregroundStyle(Color("Tertiary"))
                }
            }

            Spacer(minLength: 0)

            // The direct, per-habit fix — independent of whether the
            // broader Gentle/Vacation switch state is itself correct, which
            // is exactly what was needed when the switch's own bookkeeping
            // was the thing stuck.
            Chip(label: "Wake", isSelected: false) {
                wakeHabit(habit, today: today, modelContext: modelContext)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
