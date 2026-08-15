import Testing
import Foundation
@testable import HabitKit

@Test func dailyCapDefaultsToThreeAndIsClampedToTheCeilingOfSix() {
    #expect(NudgeSettings().dailyCap == 3)
    #expect(NudgeSettings(dailyCap: 10).dailyCap == 6)
    #expect(NudgeSettings(dailyCap: -1).dailyCap == 0)
}

@Test func nudgeIsBlockedOnceTheDailyCapIsReached() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let settings = NudgeSettings(dailyCap: 3)

    let atCap = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 3, settings: settings
    )
    let underCap = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 2, settings: settings
    )

    #expect(atCap == nil)
    #expect(underCap != nil)
}

@Test func nudgeIsBlockedDuringTheDefaultQuietHours() {
    #expect(isWithinQuietHours(hour: 23, start: 22, end: 8) == true)
    #expect(isWithinQuietHours(hour: 6, start: 22, end: 8) == true)
    #expect(isWithinQuietHours(hour: 22, start: 22, end: 8) == true)
    #expect(isWithinQuietHours(hour: 8, start: 22, end: 8) == false)
    #expect(isWithinQuietHours(hour: 13, start: 22, end: 8) == false)

    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let duringQuietHours = nudge(
        for: habit, on: 20260801, hour: 23, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0
    )
    let inTheDay = nudge(
        for: habit, on: 20260801, hour: 13, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0
    )

    #expect(duringQuietHours == nil)
    #expect(inTheDay != nil)
}

@Test func nudgeIsCancelledWhenTheHabitIsAlreadyLoggedToday() {
    let habit = Habit(name: "Read", symbolName: "book", kind: .binary, target: 1, scheduleMask: 127)

    let alreadyDone = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 1,
        pauses: [], nudgesAlreadyScheduledToday: 0
    )
    let notYetDone = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0
    )

    #expect(alreadyDone == nil)
    #expect(notYetDone != nil)
}

@Test func pausedHabitNeverGetsANudge() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let pauses = [Pause(startDay: 20260730, endDay: 20260805, reason: .vacation)]

    // Otherwise-favourable conditions on every other axis.
    let result = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: pauses, nudgesAlreadyScheduledToday: 0
    )

    #expect(result == nil)
}

@Test func nudgeIsAlwaysPassive() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let result = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0
    )

    #expect(result?.interruptionLevel == .passive)
}

@Test func nudgeWordingIsIdenticalOnDayOneAndDayOneHundred() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let dayOne = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, tone: .invitation
    )
    let dayOneHundred = nudge(
        for: habit, on: 20261109, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, tone: .invitation
    )

    #expect(dayOne?.text == dayOneHundred?.text)
}

@Test func noScheduledNudgeEverReferencesAMissedDay() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    for tone in [NudgeTone.invitation, .plain, .silent] {
        let text = nudgeText(for: habit, tone: tone)
        #expect(!text.localizedCaseInsensitiveContains("missed"))
        #expect(!text.localizedCaseInsensitiveContains("streak"))
    }
}
