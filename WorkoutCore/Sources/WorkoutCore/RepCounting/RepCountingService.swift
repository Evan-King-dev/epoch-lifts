/// Anything that counts reps during a set: manual input, the Apple Watch, or a replayed recording (ADR-002).
///
/// The ViewModel depends only on this protocol, so a rep source can be swapped without changing any UI code.
/// This is the strategy pattern: the counting method is chosen in the composition root.
@MainActor
public protocol RepCountingService: AnyObject {
    /// The current rep count for the set. Never negative.
    var count: Int { get }

    /// Sends a `RepEvent` every time `count` changes.
    var repEvents: AsyncStream<RepEvent> { get }

    /// Where this counter's reps come from. Stored on each saved set.
    var sourceType: RepCountSource { get }

    /// Begins counting for a new set.
    func startCounting()

    /// Stops counting. `count` keeps its value until `reset()`.
    func stopCounting()

    /// Sets `count` back to 0.
    func reset()

    /// Replaces the count with the number the user entered after the set.
    /// Negative numbers are treated as 0.
    func correctCount(to reps: Int)
}
