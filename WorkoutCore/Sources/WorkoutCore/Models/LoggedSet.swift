import Foundation

/// One completed set within a `LoggedExercise`.
public struct LoggedSet: Codable, Hashable, Identifiable, Sendable {
    /// Unique ID, generated once when the set is created.
    public let id: UUID

    /// Number of reps, read from the active rep counter when the set is completed.
    public var reps: Int

    /// Weight in pounds, exactly as entered (ADR-006). 0 means bodyweight.
    public var weightLb: Double

    /// When the set was completed.
    public var completedAt: Date

    /// Which rep source produced `reps`.
    public var repSource: RepCountSource

    public init(
        id: UUID = UUID(),
        reps: Int,
        weightLb: Double,
        completedAt: Date = .now,
        repSource: RepCountSource
    ) {
        self.id = id
        self.reps = reps
        self.weightLb = weightLb
        self.completedAt = completedAt
        self.repSource = repSource
    }
}
