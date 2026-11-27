import Foundation
import Testing
import WorkoutCore

/// A fixed time so results never depend on when the tests run.
private let start = Date(timeIntervalSince1970: 1_800_000_000)

struct RestTimerTests {

    @Test func newTimerHasNoRest() {
        let timer = RestTimer()
        #expect(timer.startedAt == nil)
        #expect(timer.endsAt == nil)
        #expect(timer.remaining(now: start) == nil)
        #expect(!timer.isFinished(now: start))
    }

    @Test func startSetsStartAndEnd() {
        var timer = RestTimer()
        let endsAt = timer.start(at: start, duration: 120)

        #expect(endsAt == start.addingTimeInterval(120))
        #expect(timer.startedAt == start)
        #expect(timer.endsAt == endsAt)
    }

    @Test func remainingCountsDown() {
        var timer = RestTimer()
        timer.start(at: start, duration: 120)

        #expect(timer.remaining(now: start) == 120)
        #expect(timer.remaining(now: start.addingTimeInterval(45)) == 75)
    }

    @Test func remainingIsZeroAfterTheEnd() {
        var timer = RestTimer()
        timer.start(at: start, duration: 120)
        #expect(timer.remaining(now: start.addingTimeInterval(500)) == 0)
    }

    @Test func isFinishedFromTheEndOnwards() {
        var timer = RestTimer()
        timer.start(at: start, duration: 120)

        #expect(!timer.isFinished(now: start.addingTimeInterval(119)))
        #expect(timer.isFinished(now: start.addingTimeInterval(120)))
        #expect(timer.isFinished(now: start.addingTimeInterval(500)))
    }

    @Test func startReplacesARunningRest() {
        var timer = RestTimer()
        timer.start(at: start, duration: 120)
        let later = start.addingTimeInterval(60)
        timer.start(at: later, duration: 90)

        #expect(timer.startedAt == later)
        #expect(timer.endsAt == later.addingTimeInterval(90))
    }

    @Test func stopClearsTheRest() {
        var timer = RestTimer()
        timer.start(at: start, duration: 120)
        timer.stop()

        #expect(timer.startedAt == nil)
        #expect(timer.endsAt == nil)
        #expect(!timer.isFinished(now: start.addingTimeInterval(500)))
    }

    @Test func defaultDurationIsInRange() {
        #expect(RestTimer.durationRange.contains(RestTimer.defaultDuration))
    }

    @Test(arguments: [
        (10.0, 15.0),
        (15.0, 15.0),
        (120.0, 120.0),
        (600.0, 600.0),
        (900.0, 600.0),
    ])
    func clampedDurationStaysInRange(seconds: TimeInterval, expected: TimeInterval) {
        #expect(RestTimer.clampedDuration(seconds) == expected)
    }

    @Test func clampedDurationRejectsNotANumber() {
        #expect(RestTimer.clampedDuration(.nan) == RestTimer.defaultDuration)
    }
}
