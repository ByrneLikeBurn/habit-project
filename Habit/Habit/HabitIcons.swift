//
//  HabitIcons.swift
//  Habit
//

import Foundation

/// One named group of marks in the icon picker.
struct HabitIconCategory: Identifiable, Hashable {
    let name: String
    let symbolNames: [String]

    var id: String { name }
}

/// The marks a habit can be created with, grouped by theme.
///
/// Deliberately object-representing, not geometric primitives (circle,
/// square, star) — those read as UI controls next to a checkbox or a check
/// circle, not as icons. Every name here is a plain, default-rendering SF
/// Symbol: no `.fill` variants, no multicolour palette symbols, nothing
/// that doubles as system chrome (back chevrons, gear, ellipsis). Every
/// name has been verified to actually resolve — an unresolvable name
/// renders blank, which is worse than a slightly-off icon.
enum HabitIcons {
    static let categories: [HabitIconCategory] = [
        HabitIconCategory(name: "Movement", symbolNames: [
            "figure.walk", "figure.run", "figure.hiking", "bicycle", "figure.outdoor.cycle",
            "figure.pool.swim", "figure.dance", "figure.stairs", "figure.strengthtraining.traditional",
            "skateboard", "tennis.racket", "soccerball", "basketball",
        ]),
        HabitIconCategory(name: "Food and Drink", symbolNames: [
            "fork.knife", "cup.and.saucer", "mug", "wineglass", "birthday.cake", "fish", "cart",
            "takeoutbag.and.cup.and.straw", "popcorn", "frying.pan", "leaf", "basket", "flame",
        ]),
        HabitIconCategory(name: "Rest", symbolNames: [
            "moon", "moon.zzz", "moon.stars", "bed.double", "powersleep", "hourglass", "cloud.moon",
            "sunset", "sunrise", "alarm", "beach.umbrella", "zzz", "book.closed",
        ]),
        HabitIconCategory(name: "Mind", symbolNames: [
            "brain.head.profile", "figure.mind.and.body", "book", "books.vertical", "text.book.closed",
            "quote.bubble", "lightbulb", "puzzlepiece", "eye", "brain", "scribble", "text.quote", "infinity",
        ]),
        HabitIconCategory(name: "Home", symbolNames: [
            "house", "sofa", "washer", "dishwasher", "refrigerator", "oven", "lamp.desk", "lamp.floor",
            "trash", "tree", "wrench", "hammer", "sink",
        ]),
        HabitIconCategory(name: "Work", symbolNames: [
            "briefcase", "laptopcomputer", "desktopcomputer", "doc.text", "calendar", "envelope", "phone",
            "printer", "folder", "paperclip", "chart.bar", "target", "building.2",
        ]),
        HabitIconCategory(name: "Creative", symbolNames: [
            "paintpalette", "paintbrush", "pencil.and.outline", "camera", "music.note", "guitars",
            "pianokeys", "music.mic", "theatermasks", "film", "scissors", "ruler", "camera.aperture",
        ]),
        HabitIconCategory(name: "Health", symbolNames: [
            "heart", "cross.case", "pills", "bandage", "stethoscope", "lungs", "drop", "thermometer",
            "syringe", "waveform.path.ecg", "figure.arms.open", "eyeglasses", "ear",
        ]),
    ]

    static let all: [String] = categories.flatMap(\.symbolNames)
}
