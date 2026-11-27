import Foundation

/// Tells the user their rest is over, even when the app isn't on screen (ADR-018).
///
/// Implementations: `NotificationRestAlert` in the iPhone app, `SilentRestAlert` for
/// previews, and a recording fake in tests. The Watch app adds its own in V0.2.
@MainActor
public protocol RestAlert: AnyObject {
    /// Arranges the alert for `date`, replacing any alert already arranged.
    func schedule(at date: Date)

    /// Cancels the arranged alert, if there is one.
    func cancel()
}

/// A rest alert that never alerts. Used for SwiftUI previews.
@MainActor
public final class SilentRestAlert: RestAlert {
    public init() {}

    public func schedule(at date: Date) {}

    public func cancel() {}
}
