/// A kind of exercise from the catalogue, e.g. Bench Press. Each logged
/// `LoggedExercise` holds a copy of one.
public struct ExerciseType: Codable, Hashable, Identifiable, Sendable {
    /// Stable ID such as `"bench-press"`. Never generated at launch, so saved history and
    /// per-exercise data always refer to the same exercise (ADR-006).
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
        // Chest
        ExerciseType(id: "bench-press", name: "Bench Press"),
        ExerciseType(id: "incline-bench-press", name: "Incline Bench Press"),
        ExerciseType(id: "machine-chest-press", name: "Machine Chest Press"),
        ExerciseType(id: "pec-deck", name: "Pec Deck"),
        // Triceps
        ExerciseType(id: "tricep-pushdown", name: "Tricep Pushdown"),
        ExerciseType(id: "single-arm-tricep-pushdown", name: "Single-Arm Tricep Pushdown"),
        ExerciseType(id: "jm-press", name: "JM Press"),
        // Back
        ExerciseType(id: "lat-pulldown", name: "Lat Pulldown"),
        ExerciseType(id: "machine-high-row", name: "Machine High Row"),
        // Biceps
        ExerciseType(id: "dumbbell-bicep-curl", name: "Dumbbell Bicep Curl"),
        ExerciseType(id: "preacher-curl", name: "Preacher Curl"),
        ExerciseType(id: "cable-curl", name: "Cable Curl"),
        // Shoulders
        ExerciseType(id: "machine-shoulder-press", name: "Machine Shoulder Press"),
        ExerciseType(id: "cable-lateral-raise", name: "Cable Lateral Raise"),
        // Legs
        ExerciseType(id: "back-squat", name: "Back Squat"),
        ExerciseType(id: "leg-press", name: "Leg Press"),
        ExerciseType(id: "leg-extension", name: "Leg Extension"),
        ExerciseType(id: "romanian-deadlift", name: "Romanian Deadlift"),
        ExerciseType(id: "leg-curl", name: "Leg Curl"),
        ExerciseType(id: "calf-raise", name: "Calf Raise"),
    ]
}
