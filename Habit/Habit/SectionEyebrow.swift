//
//  SectionEyebrow.swift
//  Habit
//

import SwiftUI

/// The small uppercase, letter-spaced section label used throughout the app.
struct SectionEyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(Color("Tertiary"))
    }
}
