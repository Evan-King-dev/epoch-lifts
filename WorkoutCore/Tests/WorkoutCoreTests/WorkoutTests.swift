import Foundation
import Testing
import WorkoutCore

/// Fixed times so results never depend on when the tests run.
private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let oneHourLater = start.addingTimeInterval(3600)

private func makeSet(reps: Int = 8) -> LoggedSet {
    LoggedSet(reps: reps, weightLb: 135, completedAt: start, repSource: .manual)
}

struct WorkoutTests {

    @Test func isActiveUntilEnded() {
        var workout = Workout(startedAt: start)
        #expect(workout.isActive)

        workout.endedAt = oneHourLater
        #expect(!workout.isActive)
    }

    @Test func durationOfFinishedWorkout() {
        let workout = Workout(startedAt: start, endedAt: oneHourLater)
        #expect(workout.duration() == 3600)
    }

    @Test func durationOfActiveWorkoutUsesNow() {
        let workout = Workout(startedAt: start)
        let now = start.addingTimeInterval(90)
        #expect(workout.duration(now: now) == 90)
    }

    @Test func totalSetsCountsAcrossExercises() {
        let bench = LoggedExercise(exercise: ExerciseType.defaults[0], sets: [makeSet(), makeSet(), makeSet()])
        let squat = LoggedExercise(exercise: ExerciseType.defaults[1], sets: [makeSet(), makeSet()])
        let workout = Workout(startedAt: start, exercises: [bench, squat])
        #expect(workout.totalSets == 5)
    }

    @Test func totalSetsIsZeroForEmptyWorkout() {
        #expect(Workout(startedAt: start).totalSets == 0)
    }

    @Test func jsonRoundTripKeepsEverything() throws {
        let session = LoggedExercise(
            exercise: ExerciseType.defaults[0],
            sets: [
                makeSet(reps: 10),
                LoggedSet(reps: 6, weightLb: 22.5, completedAt: oneHourLater, repSource: .watch),
            ]
        )
        let original = Workout(startedAt: start, endedAt: oneHourLater, exercises: [session])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Workout.self, from: data)

        #expect(decoded == original)
    }
}
