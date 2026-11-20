/// A rep counter for sets with no sensor: the user enters the count after the set (V0.1).
///
/// Used when no Apple Watch is available or the exercise can't be counted from the wrist.
@MainActor
public final class ManualRepCounter: RepCountingService {
    public private(set) var count = 0
    public let repEvents: AsyncStream<RepEvent>
    public let sourceType = RepCountSource.manual

    private let continuation: AsyncStream<RepEvent>.Continuation

    public init() {
        (repEvents, continuation) = AsyncStream.makeStream(of: RepEvent.self)
    }

    deinit {
        continuation.finish()
    }

    // `startCounting()` and `stopCounting()` are required by `RepCountingService` so the
    // ViewModel can call them on every counter without knowing its type (ADR-002).
    // Sensor counters use them to start and stop motion updates; manual counting has
    // no sensor, so they do nothing here.

    /// Does nothing: manual counting has no sensor to start.
    public func startCounting() {}

    /// Does nothing: manual counting has no sensor to stop.
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
