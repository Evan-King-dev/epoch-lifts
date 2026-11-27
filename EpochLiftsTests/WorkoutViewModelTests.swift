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

    /// A bench press set of 135 lb completed at `completedAt`.
    func benchSet(reps: Int = 5, completedAt: Date) -> LoggedSet {
        LoggedSet(reps: reps, weightLb: 135, completedAt: completedAt, repSource: .manual)
    }

    /// Logs one full set through the normal flow. Works with manual and sensor counters:
    /// steps that don't apply to the current phase do nothing.
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
        #expect(storage.saveCallCount == 0)

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

    // MARK: - Forgotten workouts

    /// An active workout that started 6 hours before `fixedDate`, with one bench press set per date given.
    func makeActiveWorkout(setsCompletedAt dates: [Date]) -> Workout {
        Workout(
            startedAt: fixedDate.addingTimeInterval(-6 * 60 * 60),
            exercises: [LoggedExercise(exercise: bench, sets: dates.map { benchSet(completedAt: $0) })]
        )
    }

    var cutoff: TimeInterval { WorkoutViewModel.forgottenWorkoutCutoff }

    @Test func workoutWithLastSetJustUnderCutoffStaysActive() {
        let workout = makeActiveWorkout(setsCompletedAt: [fixedDate.addingTimeInterval(-cutoff + 1)])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [workout]))

        #expect(viewModel.activeWorkout == workout)
    }

    @Test func workoutWithLastSetJustOverCutoffEndsAtLastSetAndSaves() {
        let lastSetDate = fixedDate.addingTimeInterval(-cutoff - 1)
        let workout = makeActiveWorkout(setsCompletedAt: [lastSetDate.addingTimeInterval(-600), lastSetDate])
        let storage = InMemoryWorkoutStorage(workouts: [workout])
        let viewModel = makeViewModel(storage: storage)

        #expect(viewModel.activeWorkout == nil)
        #expect(viewModel.workouts.first?.endedAt == lastSetDate)
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func workoutWithNoSetsStartedJustUnderCutoffStaysActive() {
        let workout = Workout(startedAt: fixedDate.addingTimeInterval(-cutoff + 1))
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [workout]))

        #expect(viewModel.activeWorkout == workout)
    }

    @Test func forgottenWorkoutWithNoSetsIsDeletedAndSaved() {
        let workout = Workout(startedAt: fixedDate.addingTimeInterval(-cutoff - 1))
        let storage = InMemoryWorkoutStorage(workouts: [workout])
        let viewModel = makeViewModel(storage: storage)

        #expect(viewModel.workouts.isEmpty)
        #expect(storage.loadWorkouts().isEmpty)
    }

    @Test func workoutThatBecomesForgottenAfterLoadEndsWhenCheckedAgain() throws {
        let clock = TestClock(now: fixedDate)
        let storage = InMemoryWorkoutStorage()
        let viewModel = WorkoutViewModel(storage: storage, repCounter: FakeRepCounter(), now: { clock.now })
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")

        clock.now = fixedDate.addingTimeInterval(cutoff - 1)
        viewModel.endForgottenWorkout()
        #expect(viewModel.activeWorkout != nil)

        clock.now = fixedDate.addingTimeInterval(cutoff + 1)
        viewModel.endForgottenWorkout()
        #expect(viewModel.activeWorkout == nil)
        #expect(viewModel.workouts.first?.endedAt == fixedDate)
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func endingForgottenWorkoutDiscardsUnfinishedSet() throws {
        let clock = TestClock(now: fixedDate)
        let viewModel = WorkoutViewModel(storage: InMemoryWorkoutStorage(), repCounter: FakeRepCounter(), now: { clock.now })
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")
        viewModel.beginSet(for: exerciseID)

        clock.now = fixedDate.addingTimeInterval(cutoff + 1)
        viewModel.endForgottenWorkout()

        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.workouts.first?.totalSets == 1)
    }

    @Test func endingForgottenWorkoutLeavesEndedWorkoutsUnchanged() {
        let oldSet = fixedDate.addingTimeInterval(-3 * 24 * 60 * 60)
        let ended = Workout(
            startedAt: oldSet.addingTimeInterval(-600),
            endedAt: oldSet.addingTimeInterval(600),
            exercises: [LoggedExercise(exercise: bench, sets: [benchSet(completedAt: oldSet)])]
        )
        let lastSetDate = fixedDate.addingTimeInterval(-cutoff - 1)
        let forgotten = makeActiveWorkout(setsCompletedAt: [lastSetDate])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [ended, forgotten]))

        #expect(viewModel.workouts.count == 2)
        #expect(viewModel.workouts.first == ended)
        #expect(viewModel.workouts.last?.endedAt == lastSetDate)
    }

    @Test func forgottenCheckOnRecentWorkoutDoesNotSave() {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        viewModel.startWorkout()
        let savesBefore = storage.saveCallCount

        viewModel.endForgottenWorkout()

        #expect(viewModel.activeWorkout != nil)
        #expect(storage.saveCallCount == savesBefore)
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

    @Test func startOrEndThatChangesNothingDoesNotSave() {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)

        viewModel.endWorkout()
        #expect(storage.saveCallCount == 0)

        viewModel.startWorkout()
        let savesAfterStart = storage.saveCallCount
        viewModel.startWorkout()
        #expect(storage.saveCallCount == savesAfterStart)
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
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "8")

        viewModel.endWorkout()

        #expect(viewModel.activeWorkout == nil)
        #expect(viewModel.pastWorkouts.count == 1)
        let saved = try #require(storage.loadWorkouts().first)
        #expect(saved.endedAt == fixedDate)
        #expect(saved.totalSets == 1)
    }

    @Test func endWorkoutWithNoExercisesDeletesIt() {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)

        viewModel.startWorkout()
        viewModel.endWorkout()

        #expect(viewModel.workouts.isEmpty)
        #expect(storage.loadWorkouts().isEmpty)
        #expect(viewModel.canStartWorkout)
    }

    @Test func endWorkoutWithExercisesButNoSetsDeletesIt() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        _ = try startWorkoutWithBench(viewModel)

        viewModel.endWorkout()

        #expect(viewModel.workouts.isEmpty)
        #expect(storage.loadWorkouts().isEmpty)
    }

    @Test func isActiveWorkoutEmptyUntilFirstSet() throws {
        let viewModel = makeViewModel()
        #expect(!viewModel.isActiveWorkoutEmpty)

        let exerciseID = try startWorkoutWithBench(viewModel)
        #expect(viewModel.isActiveWorkoutEmpty)

        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "8")
        #expect(!viewModel.isActiveWorkoutEmpty)
    }

    @Test func isSetInProgressFollowsSetFlow() throws {
        let viewModel = makeViewModel(counter: FakeRepCounter(sourceType: .watch))
        let exerciseID = try startWorkoutWithBench(viewModel)
        #expect(!viewModel.isSetInProgress)

        viewModel.beginSet(for: exerciseID)
        #expect(viewModel.isSetInProgress)

        viewModel.finishSet()
        #expect(viewModel.isSetInProgress)

        viewModel.cancelSet()
        #expect(!viewModel.isSetInProgress)
    }

    @Test func endWorkoutDiscardsUnfinishedSet() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "8")

        viewModel.beginSet(for: exerciseID)
        viewModel.endWorkout()

        #expect(viewModel.setPhase == .notStarted)
        #expect(viewModel.workouts[0].totalSets == 1)
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

    @Test func addExerciseOpensFirstSetForManualCounter() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
    }

    @Test func addExerciseDoesNotStartSensorCounting() throws {
        let counter = FakeRepCounter(sourceType: .watch)
        let viewModel = makeViewModel(counter: counter)
        _ = try startWorkoutWithBench(viewModel)

        #expect(viewModel.setPhase == .notStarted)
        #expect(counter.calls.isEmpty)
    }

    @Test func addExerciseKeepsSetInProgress() throws {
        let viewModel = makeViewModel()
        let benchID = try startWorkoutWithBench(viewModel)

        viewModel.addExercise(ExerciseType.defaults[1])

        #expect(viewModel.activeWorkout?.exercises.count == 2)
        #expect(viewModel.setPhase == .enteringReps(exerciseID: benchID))
    }

    // MARK: - Set flow

    @Test func manualBeginSetGoesStraightToEnteringReps() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)
        viewModel.cancelSet()

        viewModel.beginSet(for: exerciseID)

        #expect(Array(counter.calls.suffix(3)) == [.reset, .startCounting, .stopCounting])
        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
    }

    @Test func sensorBeginSetResetsAndStartsCounter() throws {
        let counter = FakeRepCounter(sourceType: .watch)
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

    @Test func sensorFinishSetStopsCounter() throws {
        let counter = FakeRepCounter(sourceType: .watch)
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
        let counter = FakeRepCounter(sourceType: .watch)
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
        _ = try startWorkoutWithBench(viewModel)

        #expect(viewModel.weightText.isEmpty)
        #expect(viewModel.repsText.isEmpty)
    }

    @Test func nextSetPrefillsPreviousWeightAndReps() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "225", reps: "5")

        viewModel.beginSet(for: exerciseID)

        #expect(viewModel.weightText == "225")
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

    @Test func secondCopyOfExercisePrefillsFromFirstCopy() throws {
        let viewModel = makeViewModel()
        let firstCopyID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: firstCopyID, weight: "225", reps: "5")

        viewModel.addExercise(bench)

        #expect(viewModel.weightText == "225")
        #expect(viewModel.repsText == "5")
    }

    @Test func latestSetByCompletedAtWinsOverLatestCopy() throws {
        let earlier = fixedDate.addingTimeInterval(-600)
        let later = fixedDate.addingTimeInterval(-60)
        let firstCopy = LoggedExercise(exercise: bench, sets: [
            LoggedSet(reps: 3, weightLb: 225, completedAt: later, repSource: .manual),
        ])
        let secondCopy = LoggedExercise(exercise: bench, sets: [
            LoggedSet(reps: 8, weightLb: 185, completedAt: earlier, repSource: .manual),
        ])
        let workout = Workout(startedAt: earlier, exercises: [firstCopy, secondCopy])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [workout]))

        viewModel.beginSet(for: secondCopy.id)

        #expect(viewModel.weightText == "225")
        #expect(viewModel.repsText == "3")
    }

    @Test func copyMatchesByExerciseTypeIDNotName() throws {
        let renamedBench = ExerciseType(id: bench.id, name: "Flat Bench")
        let viewModel = makeViewModel()
        let firstCopyID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: firstCopyID, weight: "225", reps: "5")

        viewModel.addExercise(renamedBench)

        #expect(viewModel.weightText == "225")
        #expect(viewModel.repsText == "5")
    }

    @Test func differentExerciseTypeIsNeverUsedForPrefill() throws {
        let squat = try #require(ExerciseType.defaults.first { $0.id == "back-squat" })
        let viewModel = makeViewModel()
        let benchID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: benchID, weight: "225", reps: "5")

        viewModel.addExercise(squat)

        #expect(viewModel.weightText.isEmpty)
        #expect(viewModel.repsText.isEmpty)
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

    // MARK: - Editing saved sets

    /// Starts a workout with one bench press set of 135 lb × 5 and returns that set's ID.
    func logOneBenchSet(_ viewModel: WorkoutViewModel) throws -> UUID {
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")
        return try #require(viewModel.activeWorkout?.exercises[0].sets.last?.id)
    }

    @Test func beginEditFillsBoxesFromSavedSet() throws {
        let past = pastWorkout(reps: [5])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [past]))
        let set = past.exercises[0].sets[0]

        viewModel.beginEdit(setID: set.id)

        #expect(viewModel.editingSet == set)
        #expect(viewModel.editWeightText == "135")
        #expect(viewModel.editRepsText == "5")
        #expect(viewModel.editErrorMessage == nil)
    }

    @Test func beginEditWithUnknownSetDoesNothing() {
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [pastWorkout(reps: [5])]))

        viewModel.beginEdit(setID: UUID())

        #expect(viewModel.editingSetID == nil)
        #expect(viewModel.editingSet == nil)
    }

    @Test func beginEditReplacesOpenEdit() {
        let past = pastWorkout(reps: [5, 4])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [past]))
        viewModel.beginEdit(setID: past.exercises[0].sets[0].id)
        viewModel.editRepsText = "99"

        viewModel.beginEdit(setID: past.exercises[0].sets[1].id)

        #expect(viewModel.editingSetID == past.exercises[0].sets[1].id)
        #expect(viewModel.editRepsText == "4")
    }

    @Test func cancelEditChangesNothingAndDoesNotSave() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let savesBefore = storage.saveCallCount

        viewModel.beginEdit(setID: setID)
        viewModel.editRepsText = "8"
        viewModel.cancelEdit()

        #expect(viewModel.editingSetID == nil)
        #expect(viewModel.activeWorkout?.exercises[0].sets[0].reps == 5)
        #expect(storage.saveCallCount == savesBefore)
    }

    @Test func saveEditWithNoOpenEditDoesNothing() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        _ = try logOneBenchSet(viewModel)
        let savesBefore = storage.saveCallCount

        viewModel.saveEdit()

        #expect(viewModel.activeWorkout?.exercises[0].sets[0].reps == 5)
        #expect(storage.saveCallCount == savesBefore)
    }

    @Test func validEditChangesWeightAndRepsOnlyAndSaves() throws {
        let storage = InMemoryWorkoutStorage()
        let viewModel = makeViewModel(storage: storage, counter: FakeRepCounter(sourceType: .watch))
        let setID = try logOneBenchSet(viewModel)
        let original = try #require(viewModel.activeWorkout?.exercises[0].sets[0])

        viewModel.beginEdit(setID: setID)
        viewModel.editWeightText = "140"
        viewModel.editRepsText = "6"
        viewModel.saveEdit()

        let edited = try #require(viewModel.activeWorkout?.exercises[0].sets[0])
        #expect(edited.weightLb == 140)
        #expect(edited.reps == 6)
        #expect(edited.id == original.id)
        #expect(edited.completedAt == original.completedAt)
        #expect(edited.repSource == .watch)
        #expect(viewModel.editingSetID == nil)
        #expect(makeViewModel(storage: storage).workouts == viewModel.workouts)
    }

    @Test func saveEditWithUnchangedValuesStillSaves() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let savesBefore = storage.saveCallCount

        viewModel.beginEdit(setID: setID)
        viewModel.saveEdit()

        #expect(storage.saveCallCount == savesBefore + 1)
        #expect(viewModel.editingSetID == nil)
    }

    @Test(arguments: ["", "abc", "-5", "nan"])
    func invalidEditWeightIsRejected(weight: String) throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let savesBefore = storage.saveCallCount

        viewModel.beginEdit(setID: setID)
        viewModel.editWeightText = weight
        viewModel.saveEdit()

        #expect(viewModel.editErrorMessage != nil)
        #expect(viewModel.inputErrorMessage == nil)
        #expect(viewModel.editingSetID == setID)
        #expect(viewModel.activeWorkout?.exercises[0].sets[0].weightLb == 135)
        #expect(storage.saveCallCount == savesBefore)

        let exerciseID = try #require(viewModel.activeWorkout?.exercises[0].id)
        logSet(viewModel, exerciseID: exerciseID, weight: weight, reps: "5")
        #expect(viewModel.inputErrorMessage == viewModel.editErrorMessage)
    }

    @Test(arguments: ["", "0", "-1", "2.5", "x"])
    func invalidEditRepsAreRejected(reps: String) throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let savesBefore = storage.saveCallCount

        viewModel.beginEdit(setID: setID)
        viewModel.editRepsText = reps
        viewModel.saveEdit()

        #expect(viewModel.editErrorMessage != nil)
        #expect(viewModel.inputErrorMessage == nil)
        #expect(viewModel.editingSetID == setID)
        #expect(viewModel.activeWorkout?.exercises[0].sets[0].reps == 5)
        #expect(storage.saveCallCount == savesBefore)

        let exerciseID = try #require(viewModel.activeWorkout?.exercises[0].id)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: reps)
        #expect(viewModel.inputErrorMessage == viewModel.editErrorMessage)
    }

    @Test func editInPastWorkoutKeepsItEnded() {
        let past = pastWorkout(reps: [5])
        let storage = InMemoryWorkoutStorage(workouts: [past])
        let viewModel = makeViewModel(storage: storage)

        viewModel.beginEdit(setID: past.exercises[0].sets[0].id)
        viewModel.editRepsText = "8"
        viewModel.saveEdit()

        let edited = viewModel.workout(id: past.id)
        #expect(edited?.exercises[0].sets[0].reps == 8)
        #expect(edited?.endedAt == past.endedAt)
        #expect(storage.loadWorkouts() == viewModel.workouts)
    }

    @Test func editAfterFailedLoadAppliesInMemoryAndNeverSaves() throws {
        let storage = FailingWorkoutStorage(loadFails: true)
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)

        viewModel.beginEdit(setID: setID)
        viewModel.editRepsText = "8"
        viewModel.saveEdit()

        #expect(viewModel.activeWorkout?.exercises[0].sets[0].reps == 8)
        #expect(viewModel.editingSetID == nil)
        #expect(storage.saveCallCount == 0)
    }

    @Test func saveFailureDuringEditKeepsChangeInMemory() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)

        storage.saveFails = true
        viewModel.beginEdit(setID: setID)
        viewModel.editRepsText = "8"
        viewModel.saveEdit()

        #expect(viewModel.activeWorkout?.exercises[0].sets[0].reps == 8)
        #expect(viewModel.storageErrorMessage != nil)
        #expect(viewModel.editingSetID == nil)
    }

    @Test func editingLastSetLeavesOpenSetBoxesUnchanged() throws {
        let counter = FakeRepCounter()
        let viewModel = makeViewModel(counter: counter)
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")
        let setID = try #require(viewModel.activeWorkout?.exercises[0].sets.last?.id)
        viewModel.beginSet(for: exerciseID)
        let callsBefore = counter.calls

        viewModel.beginEdit(setID: setID)
        viewModel.editWeightText = "225"
        viewModel.editRepsText = "3"
        viewModel.saveEdit()

        #expect(viewModel.setPhase == .enteringReps(exerciseID: exerciseID))
        #expect(viewModel.weightText == "135")
        #expect(viewModel.repsText == "5")
        #expect(viewModel.inputErrorMessage == nil)
        #expect(counter.calls == callsBefore)
    }

    @Test func nextSetPrefillsFromEditedSet() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")
        let setID = try #require(viewModel.activeWorkout?.exercises[0].sets.last?.id)

        viewModel.beginEdit(setID: setID)
        viewModel.editWeightText = "225"
        viewModel.editRepsText = "3"
        viewModel.saveEdit()
        viewModel.beginSet(for: exerciseID)

        #expect(viewModel.weightText == "225")
        #expect(viewModel.repsText == "3")
    }

    @Test func saveEditAfterSetIsDeletedChangesNothing() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        viewModel.beginEdit(setID: setID)

        viewModel.deleteSet(id: setID)
        #expect(viewModel.editingSet == nil)
        let savesBefore = storage.saveCallCount
        viewModel.saveEdit()

        #expect(viewModel.editingSetID == nil)
        #expect(viewModel.activeWorkout?.totalSets == 0)
        #expect(storage.saveCallCount == savesBefore)
    }

    @Test func saveEditAfterExerciseIsDeletedChangesNothing() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let exerciseID = try #require(viewModel.activeWorkout?.exercises[0].id)
        viewModel.beginEdit(setID: setID)

        viewModel.deleteExercise(id: exerciseID)
        #expect(viewModel.editingSet == nil)
        let savesBefore = storage.saveCallCount
        viewModel.saveEdit()

        #expect(viewModel.editingSetID == nil)
        #expect(viewModel.activeWorkout?.exercises.isEmpty == true)
        #expect(storage.saveCallCount == savesBefore)
    }

    @Test func saveEditAfterWorkoutIsDeletedChangesNothing() throws {
        let storage = FailingWorkoutStorage()
        let viewModel = makeViewModel(storage: storage)
        let setID = try logOneBenchSet(viewModel)
        let workoutID = try #require(viewModel.activeWorkout?.id)
        viewModel.beginEdit(setID: setID)

        viewModel.deleteWorkout(id: workoutID)
        #expect(viewModel.editingSet == nil)
        let savesBefore = storage.saveCallCount
        viewModel.saveEdit()

        #expect(viewModel.editingSetID == nil)
        #expect(viewModel.workouts.isEmpty)
        #expect(storage.saveCallCount == savesBefore)
    }

    @Test func editDoesNotKeepForgottenWorkoutAlive() throws {
        let clock = TestClock(now: fixedDate)
        let viewModel = WorkoutViewModel(storage: InMemoryWorkoutStorage(), repCounter: FakeRepCounter(), now: { clock.now })
        let setID = try logOneBenchSet(viewModel)

        clock.now = fixedDate.addingTimeInterval(cutoff - 60)
        viewModel.beginEdit(setID: setID)
        viewModel.editRepsText = "6"
        viewModel.saveEdit()
        clock.now = fixedDate.addingTimeInterval(cutoff + 1)
        viewModel.endForgottenWorkout()

        #expect(viewModel.activeWorkout == nil)
        #expect(viewModel.workouts.first?.endedAt == fixedDate)
        #expect(viewModel.workouts.first?.exercises[0].sets[0].reps == 6)
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

    /// An ended workout with one bench press exercise holding the given rep counts as sets.
    func pastWorkout(reps: [Int]) -> Workout {
        let sets = reps.map { benchSet(reps: $0, completedAt: fixedDate) }
        return Workout(
            startedAt: fixedDate,
            endedAt: fixedDate.addingTimeInterval(3600),
            exercises: [LoggedExercise(exercise: bench, sets: sets)]
        )
    }

    @Test func deleteLastSetOfPastWorkoutDeletesIt() throws {
        let past = pastWorkout(reps: [5])
        let storage = InMemoryWorkoutStorage(workouts: [past])
        let viewModel = makeViewModel(storage: storage)
        let setID = try #require(past.exercises[0].sets.first?.id)

        viewModel.deleteSet(id: setID)

        #expect(viewModel.workout(id: past.id) == nil)
        #expect(storage.loadWorkouts().isEmpty)
    }

    @Test func deleteSetKeepsPastWorkoutWithOtherSets() throws {
        let past = pastWorkout(reps: [5, 4])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [past]))
        let setID = try #require(past.exercises[0].sets.first?.id)

        viewModel.deleteSet(id: setID)

        #expect(viewModel.workout(id: past.id)?.totalSets == 1)
    }

    @Test func deleteLastExerciseOfPastWorkoutDeletesIt() {
        let past = pastWorkout(reps: [5, 4])
        let storage = InMemoryWorkoutStorage(workouts: [past])
        let viewModel = makeViewModel(storage: storage)

        viewModel.deleteExercise(id: past.exercises[0].id)

        #expect(viewModel.workout(id: past.id) == nil)
        #expect(storage.loadWorkouts().isEmpty)
    }

    @Test func deleteLastSetOfActiveWorkoutKeepsIt() throws {
        let viewModel = makeViewModel()
        let exerciseID = try startWorkoutWithBench(viewModel)
        logSet(viewModel, exerciseID: exerciseID, weight: "135", reps: "5")
        let setID = try #require(viewModel.activeWorkout?.exercises[0].sets.first?.id)

        viewModel.deleteSet(id: setID)

        #expect(viewModel.activeWorkout?.totalSets == 0)
    }

    @Test func workoutLookupFindsByID() {
        let past = pastWorkout(reps: [5])
        let viewModel = makeViewModel(storage: InMemoryWorkoutStorage(workouts: [past]))

        #expect(viewModel.workout(id: past.id) == past)
        #expect(viewModel.workout(id: UUID()) == nil)
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
