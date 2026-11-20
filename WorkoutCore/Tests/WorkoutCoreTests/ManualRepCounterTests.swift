import Testing
import WorkoutCore

@MainActor
struct ManualRepCounterTests {

    @Test func startsAtZero() {
        #expect(ManualRepCounter().count == 0)
    }

    @Test func sourceIsManual() {
        #expect(ManualRepCounter().sourceType == .manual)
    }

    @Test func correctCountSetsTheCount() {
        let counter = ManualRepCounter()
        counter.correctCount(to: 8)
        #expect(counter.count == 8)

        counter.correctCount(to: 6)
        #expect(counter.count == 6)
    }

    @Test func correctCountClampsAtZero() {
        let counter = ManualRepCounter()
        counter.correctCount(to: 5)
        counter.correctCount(to: -3)
        #expect(counter.count == 0)
    }

    @Test func resetReturnsToZero() {
        let counter = ManualRepCounter()
        counter.correctCount(to: 8)
        counter.reset()
        #expect(counter.count == 0)
    }

    @Test func stopCountingKeepsCount() {
        let counter = ManualRepCounter()
        counter.startCounting()
        counter.correctCount(to: 5)
        counter.stopCounting()
        #expect(counter.count == 5)
    }

    @Test func everyChangeSendsAnEvent() async {
        let counter = ManualRepCounter()
        var events = counter.repEvents.makeAsyncIterator()

        counter.correctCount(to: 3)
        counter.correctCount(to: -1)
        counter.correctCount(to: 10)
        counter.reset()

        #expect(await events.next() == RepEvent(count: 3))
        #expect(await events.next() == RepEvent(count: 0))
        #expect(await events.next() == RepEvent(count: 10))
        #expect(await events.next() == RepEvent(count: 0))
    }
}
