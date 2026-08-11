import Testing
@testable import HabitKit

@Test func togglingAnOverAccumulatedHabitClearsToZeroInOneTap() {
    let delta = toggleDelta(currentTotal: 14, target: 1)

    #expect(delta == -14)
    #expect(14 + delta == 0)
}

@Test func togglingAnIncompleteHabitCompletesToExactlyTarget() {
    let delta = toggleDelta(currentTotal: 0, target: 1)

    #expect(delta == 1)
    #expect(0 + delta == 1)
}
