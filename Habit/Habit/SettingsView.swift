//
//  SettingsView.swift
//  Habit
//

import SwiftUI
import SwiftData
import HabitKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
/// Wraps `UIActivityViewController` so Export can write the file first, then
/// present the system share sheet — `ShareLink` alone can't sequence those
/// two steps.
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

/// Granular, non-escalating (spec §10). Global rules first — hard ceilings
/// exposed as real settings, not copy: a daily cap, quiet hours, and an
/// explicit switch for whether a missed day is ever mentioned (off by
/// default). Nothing here can be made to nag.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [Habit]

    @AppStorage(NudgeSettingsStorage.notificationsEnabledKey) private var notificationsEnabled = true
    @AppStorage(NudgeSettingsStorage.dailyCapKey) private var dailyCap = 3
    @AppStorage(NudgeSettingsStorage.quietHoursStartKey) private var quietHoursStart = 22
    @AppStorage(NudgeSettingsStorage.quietHoursEndKey) private var quietHoursEnd = 8
    @AppStorage(NudgeSettingsStorage.skipWhenAlreadyLoggedKey) private var skipWhenAlreadyLogged = true
    @AppStorage(NudgeSettingsStorage.mentionMissedDaysKey) private var mentionMissedDays = false
    @AppStorage(NudgeSettingsStorage.toneKey) private var toneRawValue = NudgeTone.plain.rawValue

    #if os(iOS)
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    #endif

    private var tone: NudgeTone { NudgeTone(rawValue: toneRawValue) ?? .plain }

    private var exampleHabit: Habit {
        Habit(name: "Sit quietly", symbolName: "figure.mind.and.body", scheduleMask: 127)
    }

    /// Reflects what would actually be sent — including the "Mention missed
    /// days" toggle, using a stand-in two-day gap so there's something to
    /// preview even though this screen has no real habit history to draw on.
    private var exampleWording: String {
        let text: String
        if mentionMissedDays {
            let today = dayKey(for: Date())
            let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            text = missedDayAwareNudgeText(
                for: exampleHabit,
                tone: tone,
                lastLoggedDayKey: dayKey(for: twoDaysAgo),
                today: today
            )
        } else {
            text = nudgeText(for: exampleHabit, tone: tone)
        }
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

                    SectionEyebrow("Nudges")

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

                    Divider().overlay(Color("Rule"))

                    exportSection
                }
                .padding(.horizontal, contentMargin)
                .padding(.vertical, 20)
                .frame(maxWidth: readableContentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("Paper"))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.habitPrimary)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingShareSheet) {
                if let exportFileURL {
                    ActivityView(activityItems: [exportFileURL])
                }
            }
            #endif
            .onChange(of: notificationsEnabled) { _, newValue in
                Task {
                    if newValue {
                        let granted = await NotificationScheduler.requestAuthorizationIfNeeded()
                        if !granted {
                            notificationsEnabled = false
                            return
                        }
                    }
                    await NotificationScheduler.reschedule(habits: habits)
                }
            }
            .onChange(of: dailyCap) { _, _ in rescheduleNudges() }
            .onChange(of: quietHoursStart) { _, _ in rescheduleNudges() }
            .onChange(of: quietHoursEnd) { _, _ in rescheduleNudges() }
            .onChange(of: skipWhenAlreadyLogged) { _, _ in rescheduleNudges() }
            .onChange(of: mentionMissedDays) { _, _ in rescheduleNudges() }
            .onChange(of: toneRawValue) { _, _ in rescheduleNudges() }
        }
    }

    private func rescheduleNudges() {
        Task { await NotificationScheduler.reschedule(habits: habits) }
    }

    /// A complete dump of every habit, log and pause (spec §9) — the escape
    /// hatch for every persistence risk this app takes on, available any
    /// time from here, not only on the way out of a delete flow.
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Data")

            Text("A complete copy of every habit, log and pause, as JSON — the escape hatch if this app or your device ever needs replacing.")
                .font(.footnote)
                .foregroundStyle(Color("Tertiary"))

            Button("Export\u{2026}") { exportNow() }
                .buttonStyle(.habitSecondary)
        }
    }

    private func exportNow() {
        guard let data = try? exportData(habits: habits, exportedAt: Date()) else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Habit Export.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
        #else
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Habit Export.json")
        do {
            try data.write(to: url)
            exportFileURL = url
            showingShareSheet = true
        } catch {
            return
        }
        #endif
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
        .modelContainer(for: Habit.self, inMemory: true)
}
