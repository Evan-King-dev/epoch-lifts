/// A rep counter for sets with no sensor: the user enters the count after the set (V0.1).
///
/// Used when no Apple Watch is available or the exercise can't be counted from the wrist.
@MainActor
public final class ManualRepCounter: RepCountingService {
    public private(set) var count = 0
    public let repEvents: AsyncStream<RepEvent>
    public let sourceType = RepCountSource.manual

    private let continuation: AsyncStream<RepEvent>.Continuation

    /// Keeps only the newest unread event. Each event carries the full count and manual
    /// events have no metrics, so older unread events are safe to drop, and a reader that
    /// starts late never receives events from earlier sets.
    public init() {
        (repEvents, continuation) = AsyncStream.makeStream(
            of: RepEvent.self,
            bufferingPolicy: .bufferingNewest(1)
        )
    }

    deinit {
        continuation.finish()
    }

    // `startCounting()` and `stopCounting()` are required by `RepCountingService` so the
    // ViewModel can call them on every counter without knowing its type (ADR-009).
    // Sensor counters use them to start and stop motion updates; manual counting has
    // no sensor, so they do nothing here.

    /// Does nothing.
    public func startCounting() {}

    /// Does nothing.
    public func stopCounting() {}

    public func reset() {
        setCount(0)
    }

    public func correctCount(to reps: Int) {
        setCount(max(0, reps))
    }

    private func setCount(_ newCount: Int) {
        count = newCount
        continuation.yield(RepEvent(count: newCount))
    }
}
