import Testing
import WorkoutCore

struct ExerciseTypeTests {

    /// Saved workouts refer to these IDs, so changing or removing one breaks history.
    /// If this test fails, an ID was edited: put it back. New exercises go at the end.
    @Test func defaultIDsNeverChange() {
        let ids = ExerciseType.defaults.map(\.id)
        #expect(ids == [
            "bench-press", "incline-bench-press", "machine-chest-press", "pec-deck",
            "tricep-pushdown", "single-arm-tricep-pushdown", "jm-press",
            "lat-pulldown", "machine-high-row",
            "dumbbell-curl", "preacher-curl", "cable-curl",
            "machine-shoulder-press", "cable-lateral-raise",
            "back-squat", "leg-press", "leg-extension",
            "romanian-deadlift", "leg-curl", "calf-raise",
        ])
    }

    @Test func defaultIDsAreUnique() {
        let ids = ExerciseType.defaults.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func defaultIDsAreLowercaseKebabCase() {
        for exercise in ExerciseType.defaults {
            #expect(exercise.id.wholeMatch(of: #/[a-z]+(-[a-z]+)*/#) != nil, "Bad ID: \(exercise.id)")
        }
    }

    @Test func defaultNamesAreNotEmpty() {
        for exercise in ExerciseType.defaults {
            #expect(!exercise.name.isEmpty)
        }
    }
}
