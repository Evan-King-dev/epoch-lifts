import Foundation

/// One gym visit: from pressing Start to pressing End.
public struct Workout: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID

    public var startedAt: Date

    /// `nil` while the workout is in progress.
    public var endedAt: Date?

    /// Exercises in the order they were added.
    public var exercises: [LoggedExercise]

    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        exercises: [LoggedExercise] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
    }

    /// True until the workout is ended.
    public var isActive: Bool {
        endedAt == nil
    }

    /// Total number of sets across all exercises.
    public var totalSets: Int {
        exercises.reduce(0) { total, session in total + session.sets.count }
    }

    /// Elapsed time in seconds. For an active workout, measured up to `now`.
    /// - Parameter now: The current time. Injectable so tests can use a fixed date.
    public func duration(now: Date = .now) -> TimeInterval {
        (endedAt ?? now).timeIntervalSince(startedAt)
    }
}
