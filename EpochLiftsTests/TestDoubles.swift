import Foundation
import WorkoutCore

/// A rep counter for tests. Records every call and lets a test set `count` directly,
/// the way a sensor such as the Apple Watch would during a set.
@MainActor
final class FakeRepCounter: RepCountingService {
    /// A method call the ViewModel made on the counter.
    enum Call: Equatable {
        case startCounting
        case stopCounting
        case reset
        case correctCount(Int)
    }

    var count = 0
    let repEvents = AsyncStream<RepEvent> { $0.finish() }
    let sourceType: RepCountSource
    private(set) var calls: [Call] = []

    init(sourceType: RepCountSource = .manual) {
        self.sourceType = sourceType
    }

    func startCounting() {
        calls.append(.startCounting)
    }

    func stopCounting() {
        calls.append(.stopCounting)
    }

    func reset() {
        calls.append(.reset)
        count = 0
    }

    func correctCount(to reps: Int) {
        calls.append(.correctCount(reps))
        count = max(0, reps)
    }
}

/// Workout storage that can be made to fail, for testing error handling.
final class FailingWorkoutStorage: WorkoutStorage {
    struct StorageFailure: Error {}

    let loadFails: Bool
    /// Settable so a test can make one save fail and the next succeed.
    var saveFails: Bool
    private(set) var saveCallCount = 0

    init(loadFails: Bool = false, saveFails: Bool = false) {
        self.loadFails = loadFails
        self.saveFails = saveFails
    }

    func loadWorkouts() throws -> [Workout] {
        if loadFails { throw StorageFailure() }
        return []
    }

    func saveWorkouts(_ workouts: [Workout]) throws {
        saveCallCount += 1
        if saveFails { throw StorageFailure() }
    }
}
