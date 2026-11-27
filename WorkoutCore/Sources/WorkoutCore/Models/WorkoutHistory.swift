import Foundation

/// Every saved workout and the rules for changing them: starting and ending a workout,
/// logging, editing and deleting, and ending a forgotten workout (ADR-011).
///
/// A value type with no storage or clock: callers pass the time in and save the result.
/// The rules hold for changes made through this type; loaded data is kept as-is.
public struct WorkoutHistory: Equatable, Sendable {

    /// How long after its last activity an active workout counts as forgotten. The reason
    /// for four hours is in ADR-011.
    public static let forgottenWorkoutCutoff: TimeInterval = 4 * 60 * 60

    /// All workouts, oldest first. The active workout, if any, is the last one.
    public private(set) var workouts: [Workout]

    /// - Parameter workouts: Loaded workouts, kept exactly as given.
    public init(workouts: [Workout] = []) {
        self.workouts = workouts
    }

    // MARK: - Reading

    /// The workout in progress, if any.
    public var activeWorkout: Workout? {
        activeWorkoutIndex.map { workouts[$0] }
    }

    /// True when no workout is in progress, so a new one can be started.
    public var canStartWorkout: Bool {
        activeWorkoutIndex == nil
    }

    /// True when the workout in progress has no saved sets, so ending it deletes it.
    public var isActiveWorkoutEmpty: Bool {
        activeWorkout?.totalSets == 0
    }

    /// Ended workouts, newest first.
    public var pastWorkouts: [Workout] {
        workouts.filter { !$0.isActive }.sorted { $0.startedAt > $1.startedAt }
    }

    /// The workout with this ID, or `nil` if it doesn't exist.
    public func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    /// The exercise with this ID in the workout in progress, or `nil` if it isn't there.
    public func activeExercise(id: UUID) -> LoggedExercise? {
        activeWorkout?.exercises.first { $0.id == id }
    }

    /// The saved set with this ID in any workout, or `nil` if it doesn't exist.
    public func loggedSet(id: UUID) -> LoggedSet? {
        findSet(id: id).map { workouts[$0.workoutIndex].exercises[$0.exerciseIndex].sets[$0.setIndex] }
    }

    /// The most recent set, by completion time, of the same exercise type as this exercise
    /// in the workout in progress, across every copy of it. Matches on the type's stable ID,
    /// so a renamed copy still counts. Used for pre-fill (ADR-011).
    public func latestSet(forExerciseID exerciseID: UUID) -> LoggedSet? {
        guard let typeID = activeExercise(id: exerciseID)?.exercise.id else { return nil }
        return activeWorkout?.exercises
            .filter { $0.exercise.id == typeID }
            .flatMap(\.sets)
            .max { $0.completedAt < $1.completedAt }
    }

    // MARK: - Workouts

    /// Starts a new workout at `date`.
    /// - Returns: `false`, changing nothing, if a workout is already in progress.
    @discardableResult
    public mutating func start(at date: Date) -> Bool {
        guard activeWorkoutIndex == nil else { return false }
        workouts.append(Workout(startedAt: date))
        return true
    }

    /// Ends the workout in progress at `date`. A workout with no sets is deleted instead.
    /// - Returns: `false`, changing nothing, if no workout is in progress.
    @discardableResult
    public mutating func end(at date: Date) -> Bool {
        guard let workoutIndex = activeWorkoutIndex else { return false }
        workouts[workoutIndex].endedAt = date
        removeEmptyEndedWorkouts()
        return true
    }

    /// Ends the workout in progress at its last activity if that was more than
    /// `forgottenWorkoutCutoff` before `now`, the same way `end(at:)` does (ADR-011).
    /// - Returns: `false`, changing nothing, if there is no forgotten workout.
    @discardableResult
    public mutating func endForgottenWorkout(now: Date) -> Bool {
        guard let lastActivityAt = activeWorkout?.lastActivityAt,
              now.timeIntervalSince(lastActivityAt) > Self.forgottenWorkoutCutoff
        else { return false }
        return end(at: lastActivityAt)
    }

    /// Deletes a workout, active or ended. Does nothing if no workout has this ID.
    public mutating func deleteWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    // MARK: - Exercises and sets

    /// Adds an exercise to the workout in progress.
    /// - Returns: The new `LoggedExercise`'s ID, or `nil` if no workout is in progress.
    public mutating func addExercise(_ exerciseType: ExerciseType) -> UUID? {
        guard let workoutIndex = activeWorkoutIndex else { return nil }
        let exercise = LoggedExercise(exercise: exerciseType)
        workouts[workoutIndex].exercises.append(exercise)
        return exercise.id
    }

    /// Adds a completed set to an exercise in the workout in progress.
    /// - Returns: `false`, changing nothing, if the exercise isn't in the workout in progress.
    public mutating func addSet(_ set: LoggedSet, toExerciseID exerciseID: UUID) -> Bool {
        guard let workoutIndex = activeWorkoutIndex,
              let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.id == exerciseID })
        else { return false }
        workouts[workoutIndex].exercises[exerciseIndex].sets.append(set)
        return true
    }

    /// Changes a saved set's weight and reps in any workout. Its ID, completion time and
    /// rep source never change (ADR-011). Does nothing if no set has this ID.
    public mutating func editSet(id: UUID, weightLb: Double, reps: Int) {
        guard let position = findSet(id: id) else { return }
        workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex].weightLb = weightLb
        workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex].reps = reps
    }

    /// Deletes an exercise and its sets from whichever workout contains it. An ended
    /// workout left with no sets is deleted too.
    public mutating func deleteExercise(id: UUID) {
        for workoutIndex in workouts.indices {
            workouts[workoutIndex].exercises.removeAll { $0.id == id }
        }
        removeEmptyEndedWorkouts()
    }

    /// Deletes a single set from whichever exercise contains it. An ended workout left
    /// with no sets is deleted too.
    public mutating func deleteSet(id: UUID) {
        for workoutIndex in workouts.indices {
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                workouts[workoutIndex].exercises[exerciseIndex].sets.removeAll { $0.id == id }
            }
        }
        removeEmptyEndedWorkouts()
    }

    // MARK: - Private

    private var activeWorkoutIndex: Int? {
        workouts.lastIndex(where: \.isActive)
    }

    /// Deletes ended workouts that have no sets, so history never holds an empty entry.
    /// The workout in progress is never deleted here (ADR-011).
    private mutating func removeEmptyEndedWorkouts() {
        workouts.removeAll { !$0.isActive && $0.totalSets == 0 }
    }

    /// Where the saved set with this ID is, in any workout, or `nil` if it doesn't exist.
    private func findSet(id: UUID) -> (workoutIndex: Int, exerciseIndex: Int, setIndex: Int)? {
        for workoutIndex in workouts.indices {
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                if let setIndex = workouts[workoutIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.id == id }) {
                    return (workoutIndex, exerciseIndex, setIndex)
                }
            }
        }
        return nil
    }
}
