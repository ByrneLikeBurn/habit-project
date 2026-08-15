//
//  Checkbox.swift
//  Habit
//

import SwiftUI

/// The ink-filled, rounded-rect checkbox used for pause-related toggles —
/// matches the mockups' `.cb` mark (Vacation Mode, Gentle Mode).
struct MarkCheckbox: View {
    let isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isOn ? Color("Ink") : Color.clear)
            .frame(width: 21, height: 21)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isOn ? Color("Ink") : Color("Rule"), lineWidth: 1.3)
            )
            .overlay {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color("Paper"))
                }
            }
    }
}
