import Foundation
import Testing
import WorkoutCore

/// Fixed times so results never depend on when the tests run.
private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let cutoff = WorkoutHistory.forgottenWorkoutCutoff

private let bench = ExerciseType.defaults[0]
private let squat = ExerciseType(id: "squat-test", name: "Squat")

private func makeSet(reps: Int = 8, weightLb: Double = 135, at date: Date = start) -> LoggedSet {
    LoggedSet(reps: reps, weightLb: weightLb, completedAt: date, repSource: .manual)
}

/// A history with one active workout holding one bench exercise, and that exercise's ID.
private func activeHistory(sets: [LoggedSet] = []) -> (WorkoutHistory, UUID) {
    let exercise = LoggedExercise(exercise: bench, sets: sets)
    let workout = Workout(startedAt: start, exercises: [exercise])
    return (WorkoutHistory(workouts: [workout]), exercise.id)
}

struct WorkoutHistoryTests {

    // MARK: - Init and lookups

    @Test func initKeepsLoadedWorkoutsAsIs() {
        let empty = Workout(startedAt: start, endedAt: start.addingTimeInterval(60))
        let history = WorkoutHistory(workouts: [empty])
        #expect(history.workouts == [empty])
    }

    @Test func activeWorkoutIsTheLastActiveOne() {
        let ended = Workout(startedAt: start, endedAt: start.addingTimeInterval(60))
        let active = Workout(startedAt: start.addingTimeInterval(120))
        let history = WorkoutHistory(workouts: [ended, active])
        #expect(history.activeWorkout == active)
        #expect(!history.canStartWorkout)
    }

    @Test func noActiveWorkoutWhenAllEnded() {
        let ended = Workout(startedAt: start, endedAt: start.addingTimeInterval(60))
        let history = WorkoutHistory(workouts: [ended])
        #expect(history.activeWorkout == nil)
        #expect(history.canStartWorkout)
        #expect(!history.isActiveWorkoutEmpty)
    }

    @Test func isActiveWorkoutEmptyFollowsSets() {
        let (empty, _) = activeHistory()
        #expect(empty.isActiveWorkoutEmpty)
        let (withSet, _) = activeHistory(sets: [makeSet()])
        #expect(!withSet.isActiveWorkoutEmpty)
    }

    @Test func pastWorkoutsAreEndedOnlyNewestFirst() {
        let older = Workout(startedAt: start, endedAt: start.addingTimeInterval(60))
        let newer = Workout(startedAt: start.addingTimeInterval(1000), endedAt: start.addingTimeInterval(1060))
        let active = Workout(startedAt: start.addingTimeInterval(2000))
        let history = WorkoutHistory(workouts: [older, newer, active])
        #expect(history.pastWorkouts == [newer, older])
    }

    @Test func workoutLookupByID() {
        let workout = Workout(startedAt: start)
        let history = WorkoutHistory(workouts: [workout])
        #expect(history.workout(id: workout.id) == workout)
        #expect(history.workout(id: UUID()) == nil)
    }

    @Test func activeExerciseLookupOnlySearchesTheActiveWorkout() {
        let endedExercise = LoggedExercise(exercise: bench, sets: [makeSet()])
        let ended = Workout(startedAt: start, endedAt: start.addingTimeInterval(60), exercises: [endedExercise])
        let activeExercise = LoggedExercise(exercise: bench)
        let active = Workout(startedAt: start.addingTimeInterval(120), exercises: [activeExercise])
        let history = WorkoutHistory(workouts: [ended, active])
        #expect(history.activeExercise(id: activeExercise.id) == activeExercise)
        #expect(history.activeExercise(id: endedExercise.id) == nil)
    }

    @Test func loggedSetLookupSearchesEveryWorkout() {
        let set = makeSet()
        let ended = Workout(
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            exercises: [LoggedExercise(exercise: bench, sets: [set])]
        )
        let history = WorkoutHistory(workouts: [ended, Workout(startedAt: start.addingTimeInterval(120))])
        #expect(history.loggedSet(id: set.id) == set)
        #expect(history.loggedSet(id: UUID()) == nil)
    }

    // MARK: - Start and end

    @Test func startAddsAnActiveWorkout() {
        var history = WorkoutHistory()
        let changed = history.start(at: start)
        #expect(changed)
        #expect(history.workouts.count == 1)
        #expect(history.activeWorkout?.startedAt == start)
    }

    @Test func startWhileActiveReturnsFalseAndChangesNothing() {
        var (history, _) = activeHistory()
        let before = history
        let changed = history.start(at: start.addingTimeInterval(60))
        #expect(!changed)
        #expect(history == before)
    }

    @Test func endSetsEndDateAndKeepsWorkoutWithSets() {
        var (history, _) = activeHistory(sets: [makeSet()])
        let end = start.addingTimeInterval(3600)
        let changed = history.end(at: end)
        #expect(changed)
        #expect(history.workouts.count == 1)
        #expect(history.workouts[0].endedAt == end)
        #expect(history.activeWorkout == nil)
    }

    @Test func endDeletesAnEmptyWorkout() {
        var (history, _) = activeHistory()
        let changed = history.end(at: start.addingTimeInterval(60))
        #expect(changed)
        #expect(history.workouts.isEmpty)
    }

    @Test func endWithNoActiveWorkoutReturnsFalseAndChangesNothing() {
        let ended = Workout(
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            exercises: [LoggedExercise(exercise: bench, sets: [makeSet()])]
        )
        var history = WorkoutHistory(workouts: [ended])
        let before = history
        let changed = history.end(at: start.addingTimeInterval(120))
        #expect(!changed)
        #expect(history == before)
    }

    // MARK: - Forgotten workouts

    @Test func forgottenWorkoutEndsAtLastSet() {
        let lastSetAt = start.addingTimeInterval(600)
        var (history, _) = activeHistory(sets: [makeSet(at: start), makeSet(at: lastSetAt)])
        let changed = history.endForgottenWorkout(now: lastSetAt.addingTimeInterval(cutoff + 1))
        #expect(changed)
        #expect(history.workouts[0].endedAt == lastSetAt)
    }

    @Test func forgottenEmptyWorkoutIsDeleted() {
        var (history, _) = activeHistory()
        let changed = history.endForgottenWorkout(now: start.addingTimeInterval(cutoff + 1))
        #expect(changed)
        #expect(history.workouts.isEmpty)
    }

    @Test func workoutAtExactlyTheCutoffIsNotForgotten() {
        var (history, _) = activeHistory(sets: [makeSet()])
        let before = history
        let changed = history.endForgottenWorkout(now: start.addingTimeInterval(cutoff))
        #expect(!changed)
        #expect(history == before)
    }

    @Test func forgottenCheckWithNoActiveWorkoutReturnsFalse() {
        var history = WorkoutHistory()
        let changed = history.endForgottenWorkout(now: start.addingTimeInterval(cutoff * 10))
        #expect(!changed)
        #expect(history.workouts.isEmpty)
    }

    @Test func cutoffIsFourHours() {
        #expect(cutoff == 4 * 60 * 60)
    }

    // MARK: - Exercises and sets

    @Test func addExerciseReturnsTheNewID() throws {
        var history = WorkoutHistory()
        history.start(at: start)
        let newID = history.addExercise(bench)
        let id = try #require(newID)
        #expect(history.activeWorkout?.exercises.map(\.id) == [id])
        #expect(history.activeWorkout?.exercises.first?.exercise == bench)
    }

    @Test func addExerciseWithNoActiveWorkoutReturnsNil() {
        var history = WorkoutHistory()
        #expect(history.addExercise(bench) == nil)
        #expect(history.workouts.isEmpty)
    }

    @Test func addSetAppendsToTheExercise() {
        var (history, exerciseID) = activeHistory()
        let set = makeSet()
        let changed = history.addSet(set, toExerciseID: exerciseID)
        #expect(changed)
        #expect(history.activeExercise(id: exerciseID)?.sets == [set])
    }

    @Test func addSetToMissingExerciseReturnsFalse() {
        var (history, _) = activeHistory()
        let before = history
        let changed = history.addSet(makeSet(), toExerciseID: UUID())
        #expect(!changed)
        #expect(history == before)
    }

    @Test func addSetToAnExerciseInAnEndedWorkoutReturnsFalse() {
        let exercise = LoggedExercise(exercise: bench, sets: [makeSet()])
        let ended = Workout(startedAt: start, endedAt: start.addingTimeInterval(60), exercises: [exercise])
        var history = WorkoutHistory(workouts: [ended])
        let before = history
        let changed = history.addSet(makeSet(), toExerciseID: exercise.id)
        #expect(!changed)
        #expect(history == before)
    }

    @Test func editSetChangesOnlyWeightAndReps() {
        let set = makeSet(reps: 8, weightLb: 135)
        var (history, _) = activeHistory(sets: [set])
        history.editSet(id: set.id, weightLb: 145, reps: 6)
        let edited = history.loggedSet(id: set.id)
        #expect(edited?.weightLb == 145)
        #expect(edited?.reps == 6)
        #expect(edited?.completedAt == set.completedAt)
        #expect(edited?.repSource == set.repSource)
    }

    @Test func editMissingSetChangesNothing() {
        var (history, _) = activeHistory(sets: [makeSet()])
        let before = history
        history.editSet(id: UUID(), weightLb: 1, reps: 1)
        #expect(history == before)
    }

    // MARK: - Pre-fill

    @Test func latestSetIsNewestAcrossCopiesOfTheSameType() {
        let older = makeSet(reps: 5, at: start)
        let newer = makeSet(reps: 3, at: start.addingTimeInterval(300))
        let first = LoggedExercise(exercise: bench, sets: [newer])
        let renamedCopy = LoggedExercise(exercise: ExerciseType(id: bench.id, name: "Renamed"), sets: [older])
        let other = LoggedExercise(exercise: squat, sets: [makeSet(at: start.addingTimeInterval(900))])
        let workout = Workout(startedAt: start, exercises: [first, renamedCopy, other])
        let history = WorkoutHistory(workouts: [workout])
        #expect(history.latestSet(forExerciseID: renamedCopy.id) == newer)
    }

    @Test func latestSetIgnoresEndedWorkouts() {
        let ended = Workout(
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            exercises: [LoggedExercise(exercise: bench, sets: [makeSet()])]
        )
        let exercise = LoggedExercise(exercise: bench)
        let active = Workout(startedAt: start.addingTimeInterval(120), exercises: [exercise])
        let history = WorkoutHistory(workouts: [ended, active])
        #expect(history.latestSet(forExerciseID: exercise.id) == nil)
    }

    @Test func latestSetForMissingExerciseIsNil() {
        let (history, _) = activeHistory(sets: [makeSet()])
        #expect(history.latestSet(forExerciseID: UUID()) == nil)
    }

    // MARK: - Deleting

    @Test func deleteWorkoutRemovesIt() {
        let workout = Workout(startedAt: start)
        var history = WorkoutHistory(workouts: [workout])
        history.deleteWorkout(id: workout.id)
        #expect(history.workouts.isEmpty)
    }

    @Test func deleteExerciseRemovesItAndItsSets() {
        var (history, exerciseID) = activeHistory(sets: [makeSet()])
        history.deleteExercise(id: exerciseID)
        #expect(history.activeWorkout?.exercises.isEmpty == true)
    }

    @Test func deleteLastExerciseOfEndedWorkoutDeletesTheWorkout() {
        let exercise = LoggedExercise(exercise: bench, sets: [makeSet()])
        let ended = Workout(startedAt: start, endedAt: start.addingTimeInterval(60), exercises: [exercise])
        var history = WorkoutHistory(workouts: [ended])
        history.deleteExercise(id: exercise.id)
        #expect(history.workouts.isEmpty)
    }

    @Test func deleteLastSetOfEndedWorkoutDeletesTheWorkout() {
        let set = makeSet()
        let ended = Workout(
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            exercises: [LoggedExercise(exercise: bench, sets: [set])]
        )
        var history = WorkoutHistory(workouts: [ended])
        history.deleteSet(id: set.id)
        #expect(history.workouts.isEmpty)
    }

    @Test func deleteLastSetOfActiveWorkoutKeepsTheWorkout() {
        let set = makeSet()
        var (history, exerciseID) = activeHistory(sets: [set])
        history.deleteSet(id: set.id)
        #expect(history.workouts.count == 1)
        #expect(history.activeExercise(id: exerciseID)?.sets.isEmpty == true)
    }

    @Test func deleteSetKeepsOtherSets() {
        let kept = makeSet(reps: 5)
        let deleted = makeSet(reps: 6)
        var (history, exerciseID) = activeHistory(sets: [kept, deleted])
        history.deleteSet(id: deleted.id)
        #expect(history.activeExercise(id: exerciseID)?.sets == [kept])
    }
}
