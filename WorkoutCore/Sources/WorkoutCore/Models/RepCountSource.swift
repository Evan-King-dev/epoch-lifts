/// Where a set's rep count came from. Raw values are stored in the saved JSON,
/// so existing cases must not be renamed.
public enum RepCountSource: String, Codable, Hashable, Sendable {
    /// Entered by the user.
    case manual
    /// Counted by the Apple Watch (V0.2).
    case watch
    /// Replayed from a recorded motion file (ADR-007).
    case replay
}
