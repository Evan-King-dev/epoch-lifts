import Testing
import WorkoutCore

struct EpochLiftsTests {

    /// Checks the app target can see WorkoutCore's public types.
    @Test func workoutCoreIsLinked() {
        #expect(!ExerciseType.defaults.isEmpty)
    }

}
