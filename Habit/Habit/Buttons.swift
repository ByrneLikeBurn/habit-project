//
//  Buttons.swift
//  Habit
//

import SwiftUI

/// Ink fill, paper label, serif — the mockups' `.btn`. For the confirming
/// half of a pair (Save, Start, Done, Add) and any other primary action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .serif))
            .foregroundStyle(Color("Paper"))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color("Ink"), in: RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// Transparent fill, hairline `Rule` outline, ink label, serif — the
/// mockups' `.btn.ghost`. For the dismissing half of a pair (Cancel) and
/// any other secondary action.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .serif))
            .foregroundStyle(Color("Ink"))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color("Rule"), lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var habitPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var habitSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
