import Foundation

/// The rest countdown between sets (ADR-018). Stores when the rest started and ends, not a
/// ticking count, so the time left is worked out from the clock and never drifts while the
/// app is in the background.
public struct RestTimer: Equatable, Sendable {
    /// The rest duration until the user picks another, in seconds.
    public static let defaultDuration: TimeInterval = 120

    /// The durations the user can pick, in seconds.
    public static let durationRange: ClosedRange<TimeInterval> = 15...600

    /// How much one tap of the duration control changes it, in seconds.
    public static let durationStep: TimeInterval = 15

    /// When the current rest started, or `nil` when there is no rest.
    public private(set) var startedAt: Date?

    /// When the current rest ends, or `nil` when there is no rest. Kept after the rest is
    /// over, so the app can show that it is over until the rest is stopped.
    public private(set) var endsAt: Date?

    public init() {}

    /// Starts a new rest, replacing any rest already started.
    /// - Returns: When the new rest ends.
    @discardableResult
    public mutating func start(at now: Date, duration: TimeInterval) -> Date {
        let endsAt = now.addingTimeInterval(duration)
        startedAt = now
        self.endsAt = endsAt
        return endsAt
    }

    /// Clears the rest, whether or not it is over.
    public mutating func stop() {
        startedAt = nil
        endsAt = nil
    }

    /// Seconds left in the rest, never below 0, or `nil` when there is no rest.
    public func remaining(now: Date) -> TimeInterval? {
        endsAt.map { max(0, $0.timeIntervalSince(now)) }
    }

    /// True when a rest was started and its end has been reached.
    public func isFinished(now: Date) -> Bool {
        guard let endsAt else { return false }
        return now >= endsAt
    }

    /// `seconds` limited to `durationRange`, for a saved duration that may be out of range.
    /// Returns `defaultDuration` for a value that isn't a number.
    public static func clampedDuration(_ seconds: TimeInterval) -> TimeInterval {
        guard !seconds.isNaN else { return defaultDuration }
        return min(max(seconds, durationRange.lowerBound), durationRange.upperBound)
    }
}
