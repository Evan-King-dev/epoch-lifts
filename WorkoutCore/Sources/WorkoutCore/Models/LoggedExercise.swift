import Foundation

/// One exercise within a workout, with its sets in order.
public struct LoggedExercise: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID

    /// A copy of the exercise, so history keeps its name even if the catalogue changes (ADR-007).
    public var exercise: ExerciseType

    /// Sets in the order they were completed.
    public var sets: [LoggedSet]

    public init(id: UUID = UUID(), exercise: ExerciseType, sets: [LoggedSet] = []) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
    }
}

