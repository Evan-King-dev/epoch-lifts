import Foundation
import Observation
import os
import WorkoutCore

/// Screen state and actions for logging workouts: starting and ending a workout, adding
/// exercises, logging sets and deleting history (ADR-001, ADR-015).
///
/// Reps always come from the injected `RepCountingService`, so the same ViewModel works
/// with manual input, the Apple Watch or a replayed recording.
@MainActor
@Observable
final class WorkoutViewModel {

    /// Where the user is in logging a set.
    nonisolated enum SetPhase: Equatable {
        /// No set is in progress.
        case notStarted
        /// The user is doing the set; the rep counter is running.
        case lifting(exerciseID: UUID)
        /// The set is done; the user is entering or checking weight and reps.
        case enteringReps(exerciseID: UUID)

        /// The `LoggedExercise` the current set belongs to, or `nil` when no set is in progress.
        var exerciseID: UUID? {
            switch self {
            case .notStarted: nil
            case .lifting(let id), .enteringReps(let id): id
            }
        }
    }

    /// All workouts, oldest first. The active workout, if any, is the last one.
    private(set) var workouts: [Workout] = []

    private(set) var setPhase: SetPhase = .notStarted

    /// Text in the weight box, in pounds.
    var weightText = ""

    /// Text in the reps box.
    var repsText = ""

    /// Shown when the weight or reps box holds an invalid value.
    private(set) var inputErrorMessage: String?

    /// Shown when saved workouts couldn't be read or a save failed.
    private(set) var storageErrorMessage: String?

    /// The workout in progress, if any.
    var activeWorkout: Workout? {
        activeWorkoutIndex.map { workouts[$0] }
    }

    /// True when no workout is in progress, so a new one can be started.
    var canStartWorkout: Bool {
        activeWorkoutIndex == nil
    }

    /// Ended workouts, newest first, for the history list.
    var pastWorkouts: [Workout] {
        workouts.filter { !$0.isActive }.sorted { $0.startedAt > $1.startedAt }
    }

    private let storage: any WorkoutStorage
    private let repCounter: any RepCountingService
    private let now: () -> Date
    private let logger = Logger(subsystem: "EpochLifts", category: "WorkoutViewModel")

    /// False after a failed load, so unreadable saved data is never overwritten (ADR-008).
    @ObservationIgnored private var canSave = true

    /// - Parameters:
    ///   - storage: Where workouts are loaded from and saved to.
    ///   - repCounter: The source of each set's rep count.
    ///   - now: The current time. Injectable so tests can use a fixed date.
    init(
        storage: any WorkoutStorage,
        repCounter: any RepCountingService,
        now: @escaping () -> Date = { .now }
    ) {
        self.storage = storage
        self.repCounter = repCounter
        self.now = now

        do {
            workouts = try storage.loadWorkouts()
        } catch {
            logger.error("Loading workouts failed: \(String(describing: error), privacy: .public)")
            canSave = false
            storageErrorMessage = "Your saved workouts couldn't be read. New changes won't be saved."
        }
    }

    // MARK: - Workouts

    /// Starts a new workout. Does nothing if one is already in progress.
    func startWorkout() {
        guard activeWorkoutIndex == nil else { return }
        workouts.append(Workout(startedAt: now()))
        save()
    }

    /// Ends the workout in progress. An unfinished set is discarded.
    func endWorkout() {
        guard let workoutIndex = activeWorkoutIndex else { return }
        cancelSet()
        workouts[workoutIndex].endedAt = now()
        save()
    }

    /// Adds an exercise to the workout in progress.
    func addExercise(_ exerciseType: ExerciseType) {
        guard let workoutIndex = activeWorkoutIndex else { return }
        workouts[workoutIndex].exercises.append(LoggedExercise(exercise: exerciseType))
        save()
    }

    // MARK: - Sets

    /// Starts a set for an exercise in the workout in progress and starts the rep counter.
    /// Pre-fills the weight box with the previous set's weight for that exercise.
    func beginSet(for exerciseID: UUID) {
        guard setPhase == .notStarted,
              let exercise = activeWorkout?.exercises.first(where: { $0.id == exerciseID })
        else { return }

        weightText = exercise.sets.last.map { SetInput.text(forWeightLb: $0.weightLb) } ?? ""
        repsText = ""
        inputErrorMessage = nil

        repCounter.reset()
        repCounter.startCounting()
        setPhase = .lifting(exerciseID: exerciseID)
    }

    /// Stops the rep counter and fills the reps box for the user to check.
    /// Uses the counter's count if it counted any reps, otherwise the previous set's reps.
    func finishSet() {
        guard case .lifting(let exerciseID) = setPhase else { return }
        repCounter.stopCounting()

        if repCounter.count > 0 {
            repsText = String(repCounter.count)
        } else if let previousSet = loggedExercise(id: exerciseID)?.sets.last {
            repsText = String(previousSet.reps)
        } else {
            repsText = ""
        }
        setPhase = .enteringReps(exerciseID: exerciseID)
    }

    /// Validates the weight and reps boxes, applies the typed reps to the counter, and saves
    /// the set. The saved rep count is read from the counter (ADR-002).
    func completeSet() {
        guard case .enteringReps(let exerciseID) = setPhase else { return }

        guard let weightLb = SetInput.weightLb(from: weightText) else {
            inputErrorMessage = "Enter a weight of 0 or more (0 means bodyweight)."
            return
        }
        guard let reps = SetInput.reps(from: repsText) else {
            inputErrorMessage = "Enter reps as a whole number, 1 or more."
            return
        }
        guard let workoutIndex = activeWorkoutIndex,
              let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.id == exerciseID })
        else {
            cancelSet()
            return
        }

        repCounter.correctCount(to: reps)
        let set = LoggedSet(
            reps: repCounter.count,
            weightLb: weightLb,
            completedAt: now(),
            repSource: repCounter.sourceType
        )
        workouts[workoutIndex].exercises[exerciseIndex].sets.append(set)
        save()
        clearSet()
    }

    /// Discards the set in progress without saving anything.
    func cancelSet() {
        guard setPhase != .notStarted else { return }
        repCounter.stopCounting()
        clearSet()
    }

    // MARK: - Deleting

    /// Deletes a workout. If it's the workout in progress, its unfinished set is discarded.
    func deleteWorkout(id: UUID) {
        if activeWorkout?.id == id {
            cancelSet()
        }
        workouts.removeAll { $0.id == id }
        save()
    }

    /// Deletes an exercise and its sets from whichever workout contains it.
    func deleteExercise(id: UUID) {
        if setPhase.exerciseID == id {
            cancelSet()
        }
        for workoutIndex in workouts.indices {
            workouts[workoutIndex].exercises.removeAll { $0.id == id }
        }
        save()
    }

    /// Deletes a single set from whichever exercise contains it.
    func deleteSet(id: UUID) {
        for workoutIndex in workouts.indices {
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                workouts[workoutIndex].exercises[exerciseIndex].sets.removeAll { $0.id == id }
            }
        }
        save()
    }

    // MARK: - Private

    private var activeWorkoutIndex: Int? {
        workouts.lastIndex(where: \.isActive)
    }

    private func loggedExercise(id: UUID) -> LoggedExercise? {
        activeWorkout?.exercises.first { $0.id == id }
    }

    /// Resets the counter and the input boxes after a set is saved or cancelled.
    private func clearSet() {
        repCounter.reset()
        setPhase = .notStarted
        weightText = ""
        repsText = ""
        inputErrorMessage = nil
    }

    private func save() {
        guard canSave else { return }
        do {
            try storage.saveWorkouts(workouts)
        } catch {
            logger.error("Saving workouts failed: \(String(describing: error), privacy: .public)")
            storageErrorMessage = "Your last change couldn't be saved."
        }
    }
}
