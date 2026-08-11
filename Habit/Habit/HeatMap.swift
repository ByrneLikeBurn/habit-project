//
//  HeatMap.swift
//  Habit
//

import SwiftUI
import HabitKit

/// A month grid of a single habit's day states (spec §2's seven-state
/// vocabulary, minus "today" which is an overlay rather than a state —
/// see `DayState`). Density comes from hatching, never colour (invariant 2).
struct MonthHeatMap: View {
    let habit: Habit
    let referenceDate: Date

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 22
    private let cellSpacing: CGFloat = 4
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7)
    }

    private var days: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else { return [] }
        let components = calendar.dateComponents([.year, .month], from: referenceDate)
        return range.compactMap { day in
            calendar.date(from: DateComponents(year: components.year, month: components.month, day: day))
        }
    }

    private var leadingEmptyCells: Int {
        guard let first = days.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first) // 1 = Sunday ... 7 = Saturday
        return (weekday + 5) % 7 // Monday-first offset, matching the mockups
    }

    private var todayKey: Int { dayKey(for: Date(), calendar: calendar) }

    var body: some View {
        // Weekday labels are the grid's own first row, not a separate
        // HStack — that's what guarantees a cell lines up under its letter,
        // rather than two independently-sized layouts hoping to agree.
        LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.caption2)
                    .foregroundStyle(Color("Tertiary"))
                    .frame(width: cellSize)
            }

            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear
                    .frame(width: cellSize, height: cellSize)
            }
            ForEach(days, id: \.self) { date in
                cell(for: date)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func cell(for date: Date) -> some View {
        let day = dayKey(for: date, calendar: calendar)
        let loggedTotal = habit.events
            .filter { $0.dayKey == day }
            .reduce(0) { $0 + $1.delta }
        let result = dayState(
            for: habit,
            on: day,
            loggedTotal: loggedTotal,
            pauses: habit.pauses,
            today: todayKey,
            calendar: calendar
        )
        return HeatMapCell(state: result.state, isToday: result.isToday, date: date, size: cellSize)
    }
}

private struct HeatMapCell: View {
    let state: DayState
    let isToday: Bool
    let date: Date
    let size: CGFloat

    private let cornerRadius: CGFloat = 2

    var body: some View {
        ZStack {
            mark
            if isToday {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color("Ink"), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .full:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color("Ink").opacity(0.94))
        case .partial:
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color("Rule"), lineWidth: 1)
                Hatching()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        case .missed:
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color("Rule"), lineWidth: 1)
        case .paused:
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color("Rule"), lineWidth: 1)
                Capsule()
                    .fill(Color("Ink").opacity(0.55))
                    .frame(width: 10, height: 1.6)
            }
        case .extraCredit:
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color("Rule"), lineWidth: 1)
                Rectangle()
                    .fill(Color("Ink"))
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
            }
        case .offSchedule:
            Color.clear
        case .future:
            // A day that hasn't happened yet — dashed and dim, never "missed".
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color("Rule"), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .opacity(0.3)
        }
    }

    private var accessibilityLabel: String {
        let dateString = date.formatted(date: .abbreviated, time: .omitted)
        let stateDescription: String
        switch state {
        case .full: stateDescription = "done"
        case .partial: stateDescription = "partially done"
        case .missed: stateDescription = "missed"
        case .paused: stateDescription = "paused"
        case .extraCredit: stateDescription = "extra credit"
        case .offSchedule: stateDescription = "not scheduled"
        case .future: stateDescription = "upcoming"
        }
        return isToday ? "\(dateString), \(stateDescription), today" : "\(dateString), \(stateDescription)"
    }
}

/// A 45° hatch of diagonal lines, clipped to whatever shape it's masked
/// with. Texture, not colour, carries the "partial" signal (spec §2).
private struct Hatching: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 3
            var offset: CGFloat = -size.height
            while offset < size.width {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(Color("Ink")), lineWidth: 1)
                offset += spacing
            }
        }
        .opacity(0.85)
    }
}
