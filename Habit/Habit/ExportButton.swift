//
//  ExportButton.swift
//  Habit
//

import SwiftUI
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

/// A complete JSON dump of every habit, log and pause (spec §9) — shared via
/// the system share sheet on iOS and a save panel on macOS. Reused wherever
/// export is offered: Settings, Recently Deleted, and the permanent-delete
/// confirmation's "export first" escape hatch.
struct ExportButton: View {
    let habits: [Habit]
    var label = "Export\u{2026}"
    var fillsWidth = false

    #if os(iOS)
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    #endif

    var body: some View {
        Button {
            exportNow()
        } label: {
            if fillsWidth {
                Text(label).frame(maxWidth: .infinity)
            } else {
                Text(label)
            }
        }
        .buttonStyle(.habitSecondary)
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            if let exportFileURL {
                ActivityView(activityItems: [exportFileURL])
            }
        }
        #endif
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
}
