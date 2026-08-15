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
    // nudgeText itself has no history parameter at all — this just
    // reconfirms the day-1-vs-day-100 guarantee still holds after adding
    // the opt-in sibling function.
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    #expect(nudgeText(for: habit, tone: .plain) == "Read.")
    #expect(nudgeText(for: habit, tone: .invitation) == "A quiet moment for Read?")
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

    #expect(neverLogged == nudgeText(for: habit, tone: .plain))
    #expect(loggedToday == nudgeText(for: habit, tone: .plain))
}

@Test func missedDayAwareTextIsAlwaysEmptyForSilentTone() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let text = missedDayAwareNudgeText(
        for: habit, tone: .silent, lastLoggedDayKey: 20260801, today: 20260805, calendar: testCalendar
    )
    #expect(text == "")
}

@Test func nudgeUsesPlainWordingByDefaultEvenWithAGapInHistory() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)

    let result = nudge(
        for: habit, on: 20260805, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0,
        lastLoggedDayKey: 20260801, calendar: testCalendar
    )

    #expect(result?.text == "Read.")
}

@Test func nudgeUsesMissedDayAwareWordingOnlyWhenTheSettingIsOn() {
    let habit = Habit(name: "Read", symbolName: "book", scheduleMask: 127)
    let settings = NudgeSettings(mentionMissedDays: true)

    let result = nudge(
        for: habit, on: 20260805, hour: 12, todayLoggedTotal: 0,
        pauses: [], nudgesAlreadyScheduledToday: 0, settings: settings,
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
