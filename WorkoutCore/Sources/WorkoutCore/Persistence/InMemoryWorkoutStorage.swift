/// Keeps workouts in memory only. Used for tests and SwiftUI previews.
public final class InMemoryWorkoutStorage: WorkoutStorage {
    private var workouts: [Workout]

    public init(workouts: [Workout] = []) {
        self.workouts = workouts
    }

    public func loadWorkouts() -> [Workout] {
        workouts
    }

    public func saveWorkouts(_ workouts: [Workout]) {
        self.workouts = workouts
    }
}
