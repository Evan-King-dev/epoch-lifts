/// A change in the rep count, sent by a rep counter whenever its count changes (ADR-010).
public struct RepEvent: Hashable, Sendable {
    /// The rep count after the change.
    public let count: Int
    /// Data about the rep that caused the change. `nil` for manual input, corrections and resets.
    public let metrics: RepMetrics?

    public init(count: Int, metrics: RepMetrics? = nil) {
        self.count = count
        self.metrics = metrics
    }
}
