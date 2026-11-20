/// Somewhere the workout history is kept between app launches (ADR-008).
///
/// Implementations: `FileWorkoutStorage` for the app,
/// `InMemoryWorkoutStorage` for tests and previews.
/// This is the repository pattern: callers load and save workouts without knowing where they are kept.
public protocol WorkoutStorage {
    /// Returns every saved workout. Returns an empty list when nothing has been saved yet.
    /// Throws if saved data exists but cannot be read. Callers must not save over it in that case.
    func loadWorkouts() throws -> [Workout]

    /// Replaces the saved history with `workouts`.
    func saveWorkouts(_ workouts: [Workout]) throws
}

/// Errors specific to reading saved workout data.
public enum WorkoutStorageError: Error, Equatable {
    /// The file was written by a newer version of the app.
    case unsupportedFormatVersion(Int)
}
