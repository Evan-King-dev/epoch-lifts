import Foundation
import Testing
import WorkoutCore
@testable import EpochLifts

@MainActor
struct WorkoutViewModelTests {

    let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
    let bench = ExerciseType.defaults[0]

    func makeViewModel(
        storage: any WorkoutStorage = InMemoryWorkoutStorage(),
        counter: FakeRepCounter = FakeRepCounter()
    ) -> WorkoutViewModel {
        let date = fixedDate
        return WorkoutViewModel(storage: storage, repCounter: counter, now: { date })
    }

    /// Starts a workout, adds bench press, and returns the new exercise's ID.
    func startWorkoutWithBench(_ viewModel: WorkoutViewModel) throws -> UUID {
        viewModel.startWorkout()
        viewModel.addExercise(bench)
        return try #require(viewModel.activeWorkout?.exercises.last?.id)
    }

    /// Logs one full set through the normal flow.
    func logSet(_ viewModel: WorkoutViewModel, exerciseID: UUID, weight: String, reps: String) {
        viewModel.beginSet(for: exerciseID)
        viewModel.finishSet()
        viewModel.weightText = weight
        viewModel.repsText = reps
        viewModel.completeSet()
    }

    // MARK: - Loading

    @Test func startsEmptyWithNoSavedWorkouts() {
        let viewModel = makeViewModel()
        #expect(viewModel.workouts.isEmpty)
        #expect(viewModel.activeWorkout == nil)
        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.storageErrorMessage == nil)
    }

    @Test func resumesActiveWorkoutAfterReload() {
        let unfinished = Workout(startedAt: fixedDate)
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [unfinished]))
        #expect(viewModel.activeWorkout?.id == unfinished.id)
    }

    @Test func loadFailureShowsErrorAndNeverSaves() {
        let storage = FailingWorkoutStorage(loadFails: true)
        let viewModel = makeViewModel(storage: storage)

        viewModel.startWorkout()
        viewModel.addExercise(bench)
        viewModel.endWorkout()

        #expect(viewModel.storageErrorMessage != nil)
        #expect(storage.saveCallCount == 0)
    }

    @Test func saveFailureShowsError() {
        let storage = FailingWorkoutStorage(saveFails: true)
        let viewModel = makeViewModel(storage: storage)

        viewModel.startWorkout()

        #expect(storage.saveCallCount == 1)
        #expect(viewModel.storageErrorMessage != nil)
    }

    @Test func successfulSaveClearsEarlierSaveError() {
        let storage = FailingWorkoutStorage(saveFails: true)
        let viewModel = makeViewModel(storage: storage)
        viewModel.startWorkout()
        #expect(viewModel.storageErrorMessage != nil)

        storage.saveFails = false
        viewModel.addExercise(bench)

        #expect(viewModel.storageErrorMessage == nil)
    }

    @Test func saveFailureDuringCompleteSetKeepsSetInMemory() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let exerciseID = try startWorkoutWithBench(viewModel)

        storage.saveFails = true
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        #expect(viewModel.activeWorkout?.exercises[0].sets.count == 1)
        #expect(viewModel.storageErrorMessage != nil)
        #expect(viewModel.setPhase == .notStarted)
    }

    // MARK: - Workouts

    @Test func startWorkoutCreatesActiveWorkoutAndSaves() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)

        viewModel.startWorkout()

        let workout = try #require(viewModel.activeWorkout)
        #expect(workout.startedAt == fixedDate)
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func startWorkoutTwiceDoesNothing() {
        let viewModel = makeViewModel()
        viewModel.startWorkout()
        viewModel.startWorkout()
        #expect(viewModel.workouts.count == 1)
    }

    @Test func canStartWorkoutOnlyWhenNoneIsActive() {
        let viewModel = makeViewModel()
        #expect(viewModel.canStartWorkout)

        viewModel.startWorkout()
        #expect(!viewModel.canStartWorkout)

        viewModel.endWorkout()
        #expect(viewModel.canStartWorkout)
    }

    @Test func pastWorkoutsAreEndedOnesNewestFirst() {
        let older = Workout(startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(3600))
        let newer = Workout(
            startedAt: fixedDate.addingTimeInterval(86_400),
            endedAt: fixedDate.addingTimeInterval(90_000)
        )
        let active = Workout(startedAt: fixedDate.addingTimeInterval(172_800))
        let storage = InMemoryWorkoutStorage(workouts: [older, newer, active])

        let viewModel = makeViewModel(storage: storage)

        #expect(viewModel.pastWorkouts.map(\.id) == [newer.id, older.id])
    }

    @Test func endWorkoutSetsEndDateAndSaves() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)

        viewModel.startWorkout()
        viewModel.endWorkout()

        #expect(viewModel.activeWorkout == nil)
        let saved = try #require(storage.loadWorkouts().first)
        #expect(saved.endedAt == fixedDate)
    }

    @Test func endWorkoutDiscardsUnfinishedSet() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        viewModel.endWorkout()

        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.workouts[0].totalSets == 0)
        #expect(counter.calls.last == .reset)
    }

    @Test func addExerciseAppendsAndSaves() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)

        _ = try startWorkoutWithBench(viewModel)

        #expect(viewModel.activeWorkout?.exercises.map(\.exercise) == [bench])
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func addExerciseWithoutActiveWorkoutDoesNothing() {
        let viewModel = makeViewModel()
        viewModel.addExercise(bench)
        #expect(viewModel.workouts.isEmpty)
    }

    // MARK: - Set flow

    @Test func beginSetResetsAndStartsCounter() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)

        #expect(counter.calls == [.reset, .startCounting])
        #expect(viewModel.setPhase == .lifting(exerciseID: exerciseID))
    }

    @Test func beginSetForUnknownExerciseDoesNothing() {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        viewModel.startWorkout()

        viewModel.beginSet(for: UUID())

        #expect(viewModel.setPhase == .notStarted)
        #expect(counter.calls.isEmpty)
    }

    @Test func finishSetStopsCounter() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        viewModel.finishSet()

        #expect(counter.calls.last == .stopCounting)
        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
    }

    @Test func completeSetSavesSetFromCounter() throws {
        let storage = InMemoryWorkoutStorage()
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(storage: storage, counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        let set = try #require(viewModel.activeWorkout?.exercises[0].sets.first)
        #expect(set.reps == 5)
        #expect(set.weightLb == 225)
        #expect(set.completedAt == fixedDate)
        #expect(set.repSource == .manual)
        #expect(counter.calls.contains(.correctCount(5)))
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func completeSetClearsInputAndResetsCounter() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.weightText.isEmpty)
        #expect(viewModel.repsText.isEmpty)
        #expect(counter.count == 0)
    }

    @Test func sensorCountFillsRepsBox() throws {
        let counter = FakeRepCounter(sourceType: .watch)
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        counter.count = 8
        viewModel.finishSet()
        #expect(viewModel.repsText == "8")

        viewModel.weightText = "135"
        viewModel.completeSet()

        let set = try #require(viewModel.activeWorkout?.exercises[0].sets.first)
        #expect(set.reps == 8)
        #expect(set.repSource == .watch)
    }

    @Test func typedRepsOverrideSensorCount() throws {
        let counter = FakeRepCounter(sourceType: .watch)
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        counter.count = 8
        viewModel.finishSet()
        viewModel.weightText = "135"
        viewModel.repsText = "7"
        viewModel.completeSet()

        #expect(viewModel.activeWorkout?.exercises[0].sets.first?.reps == 7)
    }

    @Test func cancelSetSavesNothing() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        viewModel.cancelSet()

        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.workouts[0].totalSets == 0)
        #expect(counter.calls == [.reset, .startCounting, .stopCounting, .reset])
    }

    // MARK: - Pre-fill

    @Test func firstSetStartsWithEmptyBoxes() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)

        viewModel.beginSet(for: exerciseID)
        #expect(viewModel.weightText.isEmpty)
        viewModel.finishSet()
        #expect(viewModel.repsText.isEmpty)
    }

    @Test func nextSetPrefillsPreviousWeightAndReps() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        viewModel.beginSet(for: exerciseID)
        #expect(viewModel.weightText == "225")
        viewModel.finishSet()
        #expect(viewModel.repsText == "5")
    }

    @Test func sensorCountWinsOverPreviousReps() throws {
        let counter = FakeRepCounter(sourceType: .watch)
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        viewModel.beginSet(for: exerciseID)
        counter.count = 3
        viewModel.finishSet()

        #expect(viewModel.repsText == "3")
    }

    // MARK: - Validation

    @Test(arguments: ["", "abc", "-5", "nan"])
    func invalidWeightIsRejected(weight: String) throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)

        logSet(viewModel, exerciseID: exerciseID, weight: weight, reps: "5")

        #expect(viewModel.inputErrorMessage != nil)
        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
        #expect(viewModel.workouts[0].totalSets == 0)
    }

    @Test(arguments: ["", "0", "-1", "2.5", "x"])
    func invalidRepsAreRejected(reps: String) throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)

        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: reps)

        #expect(viewModel.inputErrorMessage != nil)
        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
        #expect(viewModel.workouts[0].totalSets == 0)
    }

    @Test func bodyweightSetIsAccepted() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)

        logSet(viewModel, exerciseID: exerciseID, weight: "0", reps: "10")

        #expect(viewModel.activeWorkout?.exercises[0].sets.first?.weightLb == 0)
    }

    // MARK: - Deleting

    @Test func deleteSetRemovesOnlyThatSet() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "4")
        let firstSetID = try #require(viewModel.activeWorkout?.exercises[0].sets.first?.id)

        viewModel.deleteSet(id: firstSetID)

        #expect(viewModel.activeWorkout?.exercises[0].sets.map(\.reps) == [4])
    }

    @Test func deleteExerciseCancelsItsSetInProgress() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)
        viewModel.beginSet(for: exerciseID)

        viewModel.deleteExercise(id: exerciseID)

        #expect(viewModel.activeWorkout?.exercises.isEmpty == true)
        #expect(viewModel.setPhase == .notStarted)
        #expect(counter.calls.last == .reset)
    }

    @Test func deleteWorkoutRemovesItAndSaves() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        viewModel.startWorkout()
        let workoutID = try #require(viewModel.activeWorkout?.id)

        viewModel.deleteWorkout(id: workoutID)

        #expect(viewModel.workouts.isEmpty)
        #expect(storage.loadWorkouts().isEmpty)
    }

    @Test func deleteActiveWorkoutCancelsSetInProgress() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        viewModel.beginSet(for: exerciseID)
        let workoutID = try #require(viewModel.activeWorkout?.id)

        viewModel.deleteWorkout(id: workoutID)

        #expect(viewModel.setPhase == .notStarted)
    }

    @Test func changesSurviveReload() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        let reloaded = makeViewModel(storage: storage)

        #expect(reloaded.workouts == viewModel.workouts)
        #expect(reloaded.activeWorkout?.totalSets == 1)
    }
}
