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
    @Environment(\.modelContext) private var modelContext
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

    @State private var showingFileImporter = false
    @State private var showingImportModePicker = false
    @State private var showingReplaceConfirmation = false
    @State private var pendingImportData: Data?
    @State private var pendingImportExport: HabitExport?
    @State private var importErrorMessage: String?

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

                    dataSection
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
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.json]) { result in
                handleFilePicked(result)
            }
            .confirmationDialog(
                "Import This File?",
                isPresented: $showingImportModePicker,
                titleVisibility: .visible
            ) {
                Button("Merge") { performImport(mode: .merge) }
                Button("Replace Everything\u{2026}", role: .destructive) { showingReplaceConfirmation = true }
                Button("Cancel", role: .cancel) { cancelPendingImport() }
            } message: {
                Text(mergeSummaryText)
            }
            .alert("Replace Everything?", isPresented: $showingReplaceConfirmation) {
                Button("Replace", role: .destructive) { performImport(mode: .replace) }
                Button("Cancel", role: .cancel) { cancelPendingImport() }
            } message: {
                Text(replaceSummaryText)
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { importErrorMessage != nil },
                    set: { isPresented in if !isPresented { importErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "")
            }
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
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Data")

            Text("A complete copy of every habit, log and pause, as JSON — the escape hatch if this app or your device ever needs replacing.")
                .font(.footnote)
                .foregroundStyle(Color("Tertiary"))

            HStack(spacing: 10) {
                Button("Export\u{2026}") { exportNow() }
                    .buttonStyle(.habitSecondary)

                Button("Import\u{2026}") { showingFileImporter = true }
                    .buttonStyle(.habitSecondary)
            }
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

    private func handleFilePicked(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let export = try decodeExport(data)
            try validateExportVersion(export)
            pendingImportData = data
            pendingImportExport = export
            showingImportModePicker = true
        } catch is ImportError {
            importErrorMessage = "This file was exported by a newer version of Habit and can't be read yet."
        } catch {
            importErrorMessage = "That doesn't look like a Habit export."
        }
    }

    private func performImport(mode: ImportMode) {
        defer { cancelPendingImport() }
        guard let data = pendingImportData else { return }

        do {
            try importExport(data, mode: mode, existingHabits: habits, modelContext: modelContext)
            Task { await NotificationScheduler.reschedule(habits: habits) }
        } catch {
            importErrorMessage = "That file couldn't be imported."
        }
    }

    private func cancelPendingImport() {
        pendingImportData = nil
        pendingImportExport = nil
    }

    /// Stated up front, before anything happens — merge only ever adds.
    private var mergeSummaryText: String {
        guard let pendingImportExport else { return "" }
        let plan = planMerge(existingHabits: habits, incoming: pendingImportExport.habits)
        guard !plan.isEmpty else {
            return "Everything in this file is already on this device — merging will add nothing."
        }

        let newEventCount = plan.newHabits.reduce(0) { $0 + $1.events.count }
            + plan.additions.reduce(0) { $0 + $1.newEvents.count }
        let newPauseCount = plan.newHabits.reduce(0) { $0 + $1.pauses.count }
            + plan.additions.reduce(0) { $0 + $1.newPauses.count }

        var parts: [String] = []
        if !plan.newHabits.isEmpty { parts.append(pluralized(plan.newHabits.count, "new habit")) }
        if newEventCount > 0 { parts.append(pluralized(newEventCount, "new log")) }
        if newPauseCount > 0 { parts.append(pluralized(newPauseCount, "new pause")) }

        return "This will add \(parts.joined(separator: ", ")). Nothing already on this device will change."
    }

    /// The "clear confirmation stating what will be lost" the replace mode
    /// needs before it's allowed to touch anything.
    private var replaceSummaryText: String {
        guard let pendingImportExport else { return "" }
        let impact = replaceImpact(existingHabits: habits, incoming: pendingImportExport)
        return "This deletes \(pluralized(impact.habitsToDelete, "habit")) and \(pluralized(impact.eventsToDelete, "logged entry", plural: "logged entries")) currently on this device, replacing them with \(pluralized(impact.habitsToRestore, "habit")) from this file. This can't be undone."
    }

    private func pluralized(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        count == 1 ? "\(count) \(singular)" : "\(count) \(plural ?? singular + "s")"
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
