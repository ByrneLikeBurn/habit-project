//
//  Chip.swift
//  Habit
//

import SwiftUI

/// The pill-shaped selector used for tone and sort-mode choices — ink fill
/// with paper text when selected, transparent with a hairline `Rule`
/// outline otherwise. Matches the mockups' `.chip` / `.chip.on`.
struct Chip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(isSelected ? Color("Paper") : Color("Ink").opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? Color("Ink") : Color.clear))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color("Rule"), lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Load-bearing, not decoration — a precise hit-test shape is what
        // lets this control share a row with another interactive control
        // (e.g. RestingRow's Wake chip next to a tap-to-navigate name)
        // without both silently stopping registering clicks on macOS. See
        // ContentView.swift's HabitRow for where this was first found.
        .contentShape(Rectangle())
    }
}
