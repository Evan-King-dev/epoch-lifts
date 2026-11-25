import Foundation
import Observation
import os
import WorkoutCore

/// Screen state and actions for logging workouts: starting and ending a workout, adding
/// exercises, logging sets, and editing and deleting history (ADR-002, ADR-011).
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

    /// The ID of the saved set the edit was opened on, or `nil` once it is saved or cancelled.
    /// It can name a set deleted mid-edit; use `editingSet` to tell whether an edit is open.
    private(set) var editingSetID: UUID?

    /// Text in the edit's weight box, in pounds. Separate from `weightText` so an edit never
    /// changes the set being logged.
    var editWeightText = ""

    /// Text in the edit's reps box.
    var editRepsText = ""

    /// Shown when the edit's weight or reps box holds an invalid value.
    private(set) var editErrorMessage: String?

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

    /// True when the workout in progress has no saved sets, so ending it deletes it.
    var isActiveWorkoutEmpty: Bool {
        activeWorkout?.totalSets == 0
    }

    /// True while a set has been started but not yet saved or cancelled.
    var isSetInProgress: Bool {
        setPhase != .notStarted
    }

    /// The workout with this ID, or `nil` if it no longer exists.
    func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    /// Ended workouts, newest first, for the history list.
    var pastWorkouts: [Workout] {
        workouts.filter { !$0.isActive }.sorted { $0.startedAt > $1.startedAt }
    }

    /// How long after its last activity an active workout counts as forgotten. The reason
    /// for four hours is in ADR-011.
    static let forgottenWorkoutCutoff: TimeInterval = 4 * 60 * 60

    private static let invalidWeightMessage = "Enter a weight of 0 or more (0 means bodyweight)."
    private static let invalidRepsMessage = "Enter reps as a whole number, 1 or more."

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
            return
        }
        endForgottenWorkout()
    }

    // MARK: - Workouts

    /// Starts a new workout. Does nothing if one is already in progress.
    func startWorkout() {
        guard activeWorkoutIndex == nil else { return }
        workouts.append(Workout(startedAt: now()))
        save()
    }

    /// Ends the workout in progress. An unfinished set is discarded. A workout with no
    /// sets is deleted instead of being kept in history.
    func endWorkout() {
        endActiveWorkout(at: now())
    }

    /// Adds an exercise to the workout in progress. With a manual counter, also opens its
    /// first set's weight and reps boxes, unless another set is in progress (ADR-011).
    func addExercise(_ exerciseType: ExerciseType) {
        guard let workoutIndex = activeWorkoutIndex else { return }
        let exercise = LoggedExercise(exercise: exerciseType)
        workouts[workoutIndex].exercises.append(exercise)
        save()

        if repCounter.sourceType == .manual {
            beginSet(for: exercise.id)
        }
    }

    /// Ends the workout in progress at its last activity if that was more than
    /// `forgottenWorkoutCutoff` ago, the same way `endWorkout()` does (ADR-011).
    /// Runs after a successful load and whenever the app becomes active, since the app may
    /// stay in memory for days. On launch it runs twice; the second run finds nothing to end.
    func endForgottenWorkout() {
        guard let lastActivityAt = activeWorkout?.lastActivityAt,
              now().timeIntervalSince(lastActivityAt) > Self.forgottenWorkoutCutoff
        else { return }
        logger.info("Ending a forgotten workout at its last activity")
        endActiveWorkout(at: lastActivityAt)
    }

    // MARK: - Sets

    /// Starts a set for an exercise in the workout in progress and starts the rep counter.
    /// Pre-fills the weight box with the previous set's weight for that exercise; the reps box
    /// is pre-filled by `finishSet()`.
    /// A manual counter has nothing to count during the set, so the set goes straight to
    /// entering weight and reps (ADR-011), with both boxes pre-filled.
    func beginSet(for exerciseID: UUID) {
        guard setPhase == .notStarted,
              let exercise = loggedExercise(id: exerciseID)
        else { return }

        weightText = exercise.sets.last.map { SetInput.text(forWeightLb: $0.weightLb) } ?? ""
        repsText = ""
        inputErrorMessage = nil

        repCounter.reset()
        repCounter.startCounting()
        setPhase = .lifting(exerciseID: exerciseID)

        if repCounter.sourceType == .manual {
            finishSet()
        }
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
    /// the set. The saved rep count is read from the counter (ADR-009).
    func completeSet() {
        guard case .enteringReps(let exerciseID) = setPhase else { return }

        guard let weightLb = SetInput.weightLb(from: weightText) else {
            inputErrorMessage = Self.invalidWeightMessage
            return
        }
        guard let reps = SetInput.reps(from: repsText) else {
            inputErrorMessage = Self.invalidRepsMessage
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

    // MARK: - Editing saved sets

    /// The saved set being edited, or `nil` when no edit is open or the set no longer exists.
    var editingSet: LoggedSet? {
        guard let setID = editingSetID, let position = findSet(id: setID) else { return nil }
        return workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex]
    }

    /// Opens an edit of a saved set in any workout, filling the edit boxes from it.
    /// Replaces an edit that is already open. Does nothing if no set has this ID.
    ///
    /// Edits change the saved set directly, without the rep counter, so they never affect
    /// the set being logged (ADR-011).
    func beginEdit(setID: UUID) {
        guard let position = findSet(id: setID) else { return }
        let set = workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex]
        editingSetID = setID
        editWeightText = SetInput.text(forWeightLb: set.weightLb)
        editRepsText = String(set.reps)
        editErrorMessage = nil
    }

    /// Validates the edit boxes like `completeSet()`, then changes the set's weight and reps
    /// and saves. Its ID, completion time and rep source never change. If the set was deleted
    /// while editing, the edit closes without changing or saving anything.
    func saveEdit() {
        guard let setID = editingSetID else { return }
        guard let position = findSet(id: setID) else {
            cancelEdit()
            return
        }
        guard let weightLb = SetInput.weightLb(from: editWeightText) else {
            editErrorMessage = Self.invalidWeightMessage
            return
        }
        guard let reps = SetInput.reps(from: editRepsText) else {
            editErrorMessage = Self.invalidRepsMessage
            return
        }

        workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex].weightLb = weightLb
        workouts[position.workoutIndex].exercises[position.exerciseIndex].sets[position.setIndex].reps = reps
        save()
        cancelEdit()
    }

    /// Closes the edit without changing anything.
    func cancelEdit() {
        editingSetID = nil
        editWeightText = ""
        editRepsText = ""
        editErrorMessage = nil
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

    /// Deletes an exercise and its sets from whichever workout contains it. An ended
    /// workout left with no sets is deleted too.
    func deleteExercise(id: UUID) {
        if setPhase.exerciseID == id {
            cancelSet()
        }
        for workoutIndex in workouts.indices {
            workouts[workoutIndex].exercises.removeAll { $0.id == id }
        }
        removeEmptyEndedWorkouts()
        save()
    }

    /// Deletes a single set from whichever exercise contains it. An ended workout left
    /// with no sets is deleted too.
    func deleteSet(id: UUID) {
        for workoutIndex in workouts.indices {
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                workouts[workoutIndex].exercises[exerciseIndex].sets.removeAll { $0.id == id }
            }
        }
        removeEmptyEndedWorkouts()
        save()
    }

    // MARK: - Private

    /// Ends the workout in progress at `date`: discards an unfinished set, deletes the
    /// workout if it has no sets, and saves.
    private func endActiveWorkout(at date: Date) {
        guard let workoutIndex = activeWorkoutIndex else { return }
        cancelSet()
        workouts[workoutIndex].endedAt = date
        removeEmptyEndedWorkouts()
        save()
    }

    /// Deletes ended workouts that have no sets, so history never holds an empty entry.
    /// The workout in progress is never deleted here (ADR-011).
    private func removeEmptyEndedWorkouts() {
        workouts.removeAll { !$0.isActive && $0.totalSets == 0 }
    }

    private var activeWorkoutIndex: Int? {
        workouts.lastIndex(where: \.isActive)
    }

    private func loggedExercise(id: UUID) -> LoggedExercise? {
        activeWorkout?.exercises.first { $0.id == id }
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
            storageErrorMessage = nil
        } catch {
            logger.error("Saving workouts failed: \(String(describing: error), privacy: .public)")
            storageErrorMessage = "Your last change couldn't be saved."
        }
    }
}
