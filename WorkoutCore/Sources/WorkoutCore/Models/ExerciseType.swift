/// A kind of exercise from the catalogue, e.g. Bench Press. Each logged
/// `LoggedExercise` holds a copy of one.
public struct ExerciseType: Codable, Hashable, Identifiable, Sendable {
    /// Stable ID such as `"bench-press"`. Never generated at launch, so saved history and
    /// per-exercise data always refer to the same exercise (ADR-010).
    public let id: String

    /// Name shown in the UI, e.g. "Bench Press".
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

extension ExerciseType {
    /// The built-in catalogue. IDs must never change once released: saved workouts
    /// refer to them. Add new exercises at the end.
    public static let defaults: [ExerciseType] = [
        ExerciseType(id: "bench-press", name: "Bench Press"),
        ExerciseType(id: "incline-bench-press", name: "Incline Bench Press"),
        ExerciseType(id: "overhead-press", name: "Overhead Press"),
        ExerciseType(id: "barbell-row", name: "Barbell Row"),
        ExerciseType(id: "lat-pulldown", name: "Lat Pulldown"),
        ExerciseType(id: "pull-up", name: "Pull-Up"),
        ExerciseType(id: "back-squat", name: "Back Squat"),
        ExerciseType(id: "deadlift", name: "Deadlift"),
        ExerciseType(id: "romanian-deadlift", name: "Romanian Deadlift"),
        ExerciseType(id: "leg-press", name: "Leg Press"),
        ExerciseType(id: "bicep-curl", name: "Bicep Curl"),
        ExerciseType(id: "tricep-pushdown", name: "Tricep Pushdown"),
    ]
}
