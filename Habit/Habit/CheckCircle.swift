//
//  CheckCircle.swift
//  Habit
//

import SwiftUI

/// The imperfect, hand-drawn circle from the mockups (spec §2) — not a
/// geometric circle, four uneven cubic curves, traced from the mockup's SVG.
private struct HandDrawnCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 32
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        path.move(to: point(16, 2.6))
        path.addCurve(to: point(29.4, 15.8), control1: point(23.5, 2.2), control2: point(29.4, 8.2))
        path.addCurve(to: point(15.9, 29.4), control1: point(29.4, 23.6), control2: point(23.8, 29.4))
        path.addCurve(to: point(2.6, 16), control1: point(8.2, 29.4), control2: point(2.6, 23.5))
        path.addCurve(to: point(16, 2.6), control1: point(2.6, 8.4), control2: point(8.3, 3))
        path.closeSubpath()
        return path
    }
}

private struct HandDrawnCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 32
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }

        var path = Path()
        path.move(to: point(9.6, 16.4))
        path.addLine(to: point(13.9, 21))
        path.addLine(to: point(23, 11.4))
        return path
    }
}

/// The Today screen's binary-habit control: an empty hand-drawn circle,
/// or the same circle at full weight with a checkmark once done.
struct CheckCircle: View {
    let isDone: Bool

    var body: some View {
        ZStack {
            HandDrawnCircle()
                .stroke(Color("Ink"), lineWidth: isDone ? 1.5 : 1.3)
                .opacity(isDone ? 1 : 0.45)
            if isDone {
                HandDrawnCheckmark()
                    .stroke(Color("Ink"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 30, height: 30)
    }
}

/// Tally marks for a counted habit — one per unit of target, capped at ten
/// (spec §2's mockups quantize higher targets down to ten marks).
struct TallyMarks: View {
    let done: Int
    let target: Int

    private var markCount: Int { min(target, 10) }
    private var perMark: Double { Double(target) / Double(markCount) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<markCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color("Ink"))
                    .opacity(Double(index + 1) * perMark <= Double(done) ? 1 : 0.16)
                    .frame(width: 2, height: 14)
            }
        }
    }
}
