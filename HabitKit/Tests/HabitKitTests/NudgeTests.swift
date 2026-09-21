import Testing
import Foundation
@testable import HabitKit

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

@Test func habitDefaultsToNineAMForItsNudgeHour() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    #expect(habit.nudgeHour == 9)
}

@Test func defaultNudgeTextNeverMentionsElapsedTimeEvenWhenAskedToViaTheWrongFunction() {
    // nudgeWording itself has no history parameter at all — this just
    // reconfirms the day-1-vs-day-100 guarantee still holds after adding
    // the opt-in sibling function.
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    #expect(nudgeWording(for: habit, appTone: .plain, dayKey: 20260801) == "Read.")
    #expect(nudgeWording(for: habit, appTone: .invitation, dayKey: 20260801) == "A quiet moment for Read?")
}

@Test func missedDayAwareTextStatesAFactWithCorrectPluralisation() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let twoDays = missedDayAwareNudgeText(
        for: habit, tone: .plain, lastLoggedDayKey: 20260801, today: 20260803, calendar: testCalendar
    )
    let oneDay = missedDayAwareNudgeText(
        for: habit, tone: .plain, lastLoggedDayKey: 20260801, today: 20260802, calendar: testCalendar
    )

    #expect(twoDays == "2 days since you last logged Read.")
    #expect(oneDay == "1 day since you last logged Read.")
}

@Test func missedDayAwareTextNeverImpliesDisappointment() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let guiltWords = ["missed", "miss", "broke", "broken", "failed", "fail", "forgot", "let down", "should have", "let yourself"]

    for tone in [NudgeTone.invitation, .plain] {
        let text = missedDayAwareNudgeText(
            for: habit, tone: tone, lastLoggedDayKey: 20260801, today: 20260805, calendar: testCalendar
        )
        for word in guiltWords {
            #expect(!text.localizedCaseInsensitiveContains(word), "\"\(text)\" contains guilt-language: \"\(word)\"")
        }
    }
}

@Test func missedDayAwareTextFallsBackToPlainWordingWithNothingToReport() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let neverLogged = missedDayAwareNudgeText(
        for: habit, tone: .plain, lastLoggedDayKey: nil, today: 20260803, calendar: testCalendar
    )
    let loggedToday = missedDayAwareNudgeText(
        for: habit, tone: .plain, lastLoggedDayKey: 20260803, today: 20260803, calendar: testCalendar
    )

    #expect(neverLogged == nudgeWording(for: habit, appTone: .plain, dayKey: 20260803))
    #expect(loggedToday == nudgeWording(for: habit, appTone: .plain, dayKey: 20260803))
}

@Test func nudgeUsesPlainWordingByDefaultEvenWithAGapInHistory() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let result = nudge(
        for: habit, on: 20260805, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, appTone: .plain,
        lastLoggedDayKey: 20260801, calendar: testCalendar
    )

    #expect(result?.text == "Read.")
}

@Test func nudgeUsesMissedDayAwareWordingOnlyWhenTheSettingIsOn() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let settings = NudgeSettings(mentionMissedDays: true)

    let result = nudge(
        for: habit, on: 20260805, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, appTone: .plain, settings: settings,
        lastLoggedDayKey: 20260801, calendar: testCalendar
    )

    #expect(result?.text == "4 days since you last logged Read.")
}

@Test func nudgeIsBlockedOnADayOutsideTheHabitsSchedule() {
    // Tuesday (weekday 3) and Saturday (weekday 7) only.
    let tuesdayAndSaturday = (1 << (3 - 1)) | (1 << (7 - 1))
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: tuesdayAndSaturday)

    let tuesday = 20260804
    let wednesday = 20260805
    let saturday = 20260808

    let onWednesday = nudge(
        for: habit, on: wednesday, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, calendar: testCalendar
    )
    let onTuesday = nudge(
        for: habit, on: tuesday, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, calendar: testCalendar
    )
    let onSaturday = nudge(
        for: habit, on: saturday, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, calendar: testCalendar
    )

    #expect(onWednesday == nil)
    #expect(onTuesday != nil)
    #expect(onSaturday != nil)
}

@Test func dailyCapDefaultsToThreeAndIsClampedToTheCeilingOfSix() {
    #expect(NudgeSettings().dailyCap == 3)
    #expect(NudgeSettings(dailyCap: 10).dailyCap == 6)
    #expect(NudgeSettings(dailyCap: -1).dailyCap == 0)
}

@Test func nudgeIsBlockedWhenNotificationsAreDisabled() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let settings = NudgeSettings(notificationsEnabled: false)

    let result = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, settings: settings
    )

    #expect(result == nil)
}

@Test func nudgeStillFiresWhenAlreadyLoggedIfSkipIsTurnedOff() {
    let habit = Habit(name: "Read", symbolName: "book", kind: .binary, target: 1, scheduleMask: 127)
    let settings = NudgeSettings(skipWhenAlreadyLogged: false)

    let result = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 1,
        pauses: [], nudgesAlreadyScheduledToday: 0, settings: settings
    )

    #expect(result != nil)
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
    // Scoped to a habit that did not choose vary — nudgePhrase is nil, so
    // it follows the app tone rather than rotating on dayKey.
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let dayOne = nudge(
        for: habit, on: 20260801, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, appTone: .invitation
    )
    let dayOneHundred = nudge(
        for: habit, on: 20261109, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, appTone: .invitation
    )

    #expect(dayOne?.text == dayOneHundred?.text)
}

@Test func noScheduledNudgeEverReferencesAMissedDay() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    for tone in NudgeTone.allCases {
        let text = nudgeWording(for: habit, appTone: tone, dayKey: 20260801)
        #expect(!text.localizedCaseInsensitiveContains("missed"))
        #expect(!text.localizedCaseInsensitiveContains("streak"))
    }
}

@Test func noWordingAndNoAppToneGivesInvitation() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    #expect(nudgeWording(for: habit, appTone: nil, dayKey: 20260801) == "A quiet moment for Read?")
}

@Test func lockedPhraseStaysInItsOwnToneWhileKeepWordingIsOn() {
    let habit = Habit(
        name: "Read", symbolName: "book", scheduleMask: 127,
        nudgePhrase: "playful.1", keepWordingOnToneChange: true
    )
    #expect(nudgeWording(for: habit, appTone: .encouraging, dayKey: 20260801) == "The cushion is not going to sit on itself.")
}

@Test func lockedPhraseIsReachedByTheAppToneWhenKeepWordingIsOff() {
    let habit = Habit(
        name: "Read", symbolName: "book", scheduleMask: 127,
        nudgePhrase: "playful.1", keepWordingOnToneChange: false
    )
    #expect(nudgeWording(for: habit, appTone: .encouraging, dayKey: 20260801) == "Ten quiet minutes is a good gift to yourself.")
}

@Test func lockedVaryRotatesWithinItsOwnToneRegardlessOfAppTone() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127, nudgePhrase: "playful.vary")

    #expect(nudgeWording(for: habit, appTone: .encouraging, dayKey: 20260801) == "The cushion is not going to sit on itself.")
    #expect(nudgeWording(for: habit, appTone: nil, dayKey: 20260801) == "The cushion is not going to sit on itself.")
}

@Test func varyIgnoresLogHistoryEntirely() {
    // nudgeWording has no history parameter at all — this constructs the
    // gap directly to make the point concrete: a habit that's never been
    // logged and one logged for 99 days say exactly the same thing.
    let freshHabit = Habit(name: "Read", symbolName: "book", scheduleMask: 127, nudgePhrase: "vary")
    let seasonedHabit = Habit(name: "Read", symbolName: "book", scheduleMask: 127, nudgePhrase: "vary")
    for day in 0..<99 {
        seasonedHabit.events.append(LogEvent(dayKey: 20260101 + day, delta: 1, source: .manual, deviceID: "test"))
    }

    let freshText = nudgeWording(for: freshHabit, appTone: .playful, dayKey: 20260801)
    let seasonedText = nudgeWording(for: seasonedHabit, appTone: .playful, dayKey: 20260801)

    #expect(freshText == seasonedText)
}

@Test func bareTonePrefersDescriptorThenFormattedTargetThenNudgeTime() {
    let withDescriptor = Habit(
        name: "Read", symbolName: "book", kind: .counted, target: 20, unit: "pages", scheduleMask: 127,
        descriptor: "Chapter 3"
    )
    #expect(nudgeWording(for: withDescriptor, appTone: .bare, dayKey: 20260801) == "Read \u{00B7} Chapter 3")

    let withTargetOnly = Habit(
        name: "Read", symbolName: "book", kind: .counted, target: 20, unit: "pages", scheduleMask: 127
    )
    #expect(nudgeWording(for: withTargetOnly, appTone: .bare, dayKey: 20260801) == "Read \u{00B7} 20 pages")

    let binaryWithNeither = Habit(
        name: "Meditate", symbolName: "leaf", kind: .binary, scheduleMask: 127, nudgeHour: 7
    )
    #expect(nudgeWording(for: binaryWithNeither, appTone: .bare, dayKey: 20260801) == "Meditate \u{00B7} 07:00")
}

@Test func unparseableNudgePhraseFallsBackToTheAppTone() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127, nudgePhrase: "not-a-real-choice")
    #expect(nudgeWording(for: habit, appTone: .plain, dayKey: 20260801) == "Read.")
}
