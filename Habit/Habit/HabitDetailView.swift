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
    @Environment(\.dismiss) private var dismiss
    @State private var showingIconPicker = false
    @Query private var allHabits: [Habit]
    // Unsorted, matching `GentleModeView`'s own query — see its comment.
    @Query private var appSettings: [AppSettings]
    @AppStorage(NudgeSettingsStorage.toneKey) private var toneRawValue = NudgeTone.plain.rawValue

    private var isGentleModeOn: Bool { mergedGentleModeState(appSettings).startedAtDayKey > 0 }

    private var toneLabel: String {
        switch NudgeTone(rawValue: toneRawValue) ?? .plain {
        case .invitation: "Invitation"
        case .plain: "Plain"
        case .silent: "Silent"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 14) {
                    Button {
                        showingIconPicker = true
                    } label: {
                        Image(systemName: habit.symbolName)
                            .font(.system(size: 30))
                            .foregroundStyle(Color("Ink"))
                            .frame(width: 64, height: 64)
                            .overlay(Circle().strokeBorder(Color("Rule"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $habit.name)
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                        .foregroundStyle(Color("Ink"))
                        .textFieldStyle(.plain)
                }

                MonthHeatMap(habit: habit, referenceDate: Date())

                if habit.kind == .counted {
                    measurementSection
                }
                focusSection
                nudgeSection
                pausingSection
                removalSection
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
        .onChange(of: habit.nudgeHour) { _, _ in
            Task { await NotificationScheduler.reschedule(habits: allHabits) }
        }
        .onChange(of: habit.isFocus) { _, _ in
            Task { await NotificationScheduler.reschedule(habits: allHabits) }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedSymbolName: $habit.symbolName)
        }
    }

    private var unitBinding: Binding<String> {
        Binding(
            get: { habit.unit ?? "" },
            set: { habit.unit = $0.isEmpty ? nil : $0 }
        )
    }

    /// Only shown for counted habits — a binary habit has no unit to name.
    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Measurement")
                .padding(.bottom, 8)

            HStack {
                Text("Unit")
                    .font(.body)
                    .foregroundStyle(Color("Ink"))
                Spacer(minLength: 12)
                TextField("pages, minutes, glasses", text: unitBinding)
                    .font(.body)
                    .foregroundStyle(Color("Ink"))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        let trimmed = (habit.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        habit.unit = trimmed.isEmpty ? nil : trimmed
                    }
            }
            .padding(.vertical, 12)
        }
    }

    /// Only Focus habits are eligible to nudge (spec §5). Without a way to
    /// change this after creation, every habit past the first — which
    /// becomes Focus automatically — could never nudge, permanently.
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Focus")
                .padding(.bottom, 8)

            HStack {
                Text("In Focus")
                    .font(.body)
                    .foregroundStyle(Color("Ink"))
                Spacer(minLength: 12)
                Toggle("In Focus", isOn: $habit.isFocus)
                    .labelsHidden()
                    .tint(Color("Ink"))
            }
            .padding(.vertical, 12)
        }
    }

    /// "Nudge — 09:00 · Plain" (spec's mockups §15) — the time is this
    /// habit's own, editable here; the tone is global (set in Settings),
    /// shown for reference so the row reads as a preview of what will
    /// actually fire.
    private var nudgeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow("Nudge")
                .padding(.bottom, 8)

            HStack {
                Text("At")
                    .font(.body)
                    .foregroundStyle(Color("Ink"))

                Spacer(minLength: 12)

                Picker("At", selection: $habit.nudgeHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(Color("Ink"))

                Text("\u{00B7} \(toneLabel)")
                    .font(.body)
                    .foregroundStyle(Color("Ink").opacity(0.7))
            }
            .padding(.vertical, 12)
        }
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

            Button {
                habit.vacationByDefault.toggle()
            } label: {
                HStack(spacing: 13) {
                    MarkCheckbox(isOn: habit.vacationByDefault)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paused during vacations")
                            .foregroundStyle(Color("Ink"))
                        Text("Preselected when you start a vacation")
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

    /// Both are one-way from here (spec §9 / mockups §15): archiving hides
    /// the habit from Today but keeps it, restorable whole; deleting moves
    /// it to Recently Deleted for 30 days, also restorable. Either way
    /// there's nothing left to show on this screen once it's done, so we
    /// pop back to Today.
    private var removalSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    archiveHabit(habit, modelContext: modelContext)
                    dismiss()
                } label: {
                    Text("Archive").frame(maxWidth: .infinity)
                }
                .buttonStyle(.habitSecondary)

                Button {
                    moveToRecentlyDeleted(habit, modelContext: modelContext)
                    dismiss()
                } label: {
                    Text("Delete").frame(maxWidth: .infinity)
                }
                .buttonStyle(.habitSecondary)
            }

            Text("Archiving keeps every day you logged. Deleting doesn't.")
                .font(.caption)
                .foregroundStyle(Color("Tertiary"))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", symbolName: "book", scheduleMask: 127))
    }
}
