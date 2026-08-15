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
    @Query private var allHabits: [Habit]
    @AppStorage(GentleModeStorage.startedAtDayKeyDefaultsKey) private var gentleModeStartedAtDayKey = 0
    @AppStorage(NudgeSettingsStorage.toneKey) private var toneRawValue = NudgeTone.plain.rawValue

    private var isGentleModeOn: Bool { gentleModeStartedAtDayKey > 0 }

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
                TextField("Name", text: $habit.name)
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                    .foregroundStyle(Color("Ink"))
                    .textFieldStyle(.plain)

                MonthHeatMap(habit: habit, referenceDate: Date())

                nudgeSection
                pausingSection
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
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", symbolName: "book", scheduleMask: 127))
    }
}
