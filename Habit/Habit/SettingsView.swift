//
//  SettingsView.swift
//  Habit
//

import SwiftUI
import HabitKit

/// Granular, non-escalating (spec §10). Global rules first — hard ceilings
/// exposed as real settings, not copy: a daily cap, quiet hours, and an
/// explicit switch for whether a missed day is ever mentioned (off by
/// default). Nothing here can be made to nag.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(NudgeSettingsStorage.notificationsEnabledKey) private var notificationsEnabled = true
    @AppStorage(NudgeSettingsStorage.dailyCapKey) private var dailyCap = 3
    @AppStorage(NudgeSettingsStorage.quietHoursStartKey) private var quietHoursStart = 22
    @AppStorage(NudgeSettingsStorage.quietHoursEndKey) private var quietHoursEnd = 8
    @AppStorage(NudgeSettingsStorage.skipWhenAlreadyLoggedKey) private var skipWhenAlreadyLogged = true
    @AppStorage(NudgeSettingsStorage.mentionMissedDaysKey) private var mentionMissedDays = false
    @AppStorage(NudgeSettingsStorage.toneKey) private var toneRawValue = NudgeTone.plain.rawValue

    private var tone: NudgeTone { NudgeTone(rawValue: toneRawValue) ?? .plain }

    private var exampleHabit: Habit {
        Habit(name: "Sit quietly", symbolName: "figure.mind.and.body", scheduleMask: 127)
    }

    private var exampleWording: String {
        let text = nudgeText(for: exampleHabit, tone: tone)
        return text.isEmpty ? "No text — delivered silently, nothing on screen." : "\u{201C}\(text)\u{201D}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "bell")
                            .font(.system(size: 22))
                            .foregroundStyle(Color("Ink").opacity(0.8))
                            .frame(width: 40, height: 40)

                        Text("Habit will never send more than you allow, never escalate, and never mention a day you missed.")
                            .font(.body)
                            .foregroundStyle(Color("Ink").opacity(0.7))
                    }

                    Divider().overlay(Color("Rule"))

                    VStack(alignment: .leading, spacing: 0) {
                        fieldRow("Notifications") {
                            Toggle("Notifications", isOn: $notificationsEnabled)
                                .labelsHidden()
                                .tint(Color("Ink"))
                        }
                        Divider().overlay(Color("Rule"))

                        fieldRow("Most per day") {
                            Picker("Most per day", selection: $dailyCap) {
                                ForEach(1...NudgeSettings.dailyCapCeiling, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(Color("Ink"))
                        }
                        Divider().overlay(Color("Rule"))

                        fieldRow("Quiet hours") {
                            HStack(spacing: 6) {
                                hourPicker("Starts", selection: $quietHoursStart)
                                Text("\u{2013}")
                                    .foregroundStyle(Color("Ink").opacity(0.7))
                                hourPicker("Ends", selection: $quietHoursEnd)
                            }
                        }
                        Divider().overlay(Color("Rule"))

                        fieldRow("Skip when I've already logged") {
                            Toggle("Skip when I've already logged", isOn: $skipWhenAlreadyLogged)
                                .labelsHidden()
                                .tint(Color("Ink"))
                        }
                        Divider().overlay(Color("Rule"))

                        fieldRow("Mention missed days") {
                            Toggle("Mention missed days", isOn: $mentionMissedDays)
                                .labelsHidden()
                                .tint(Color("Ink"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionEyebrow("Tone")

                        HStack(spacing: 8) {
                            toneChip(.invitation, label: "Invitation")
                            toneChip(.plain, label: "Plain")
                            toneChip(.silent, label: "Silent")
                        }

                        Text(exampleWording)
                            .font(.footnote)
                            .italic()
                            .foregroundStyle(Color("Tertiary"))
                    }
                }
                .padding(.horizontal, contentMargin)
                .padding(.vertical, 20)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .navigationTitle("Nudges")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.habitPrimary)
                }
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

    private func hourPicker(_ label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text("\(hour):00").tag(hour)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(Color("Ink"))
    }

    private func toneChip(_ chipTone: NudgeTone, label: String) -> some View {
        let isSelected = chipTone == tone

        return Button {
            toneRawValue = chipTone.rawValue
        } label: {
            Text(label)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(isSelected ? Color("Paper") : Color("Ink").opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? Color("Ink") : Color.clear))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color("Rule"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
