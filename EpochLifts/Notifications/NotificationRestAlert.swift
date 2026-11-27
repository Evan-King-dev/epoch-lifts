import Foundation
import os
import UserNotifications
import WorkoutCore

/// Tells the user their rest is over with a local notification and sound (ADR-018).
///
/// Asks for notification permission the first time a rest is scheduled; iOS shows the
/// prompt only once. If permission is denied, nothing is scheduled and the countdown is
/// shown in the app only.
///
/// Also the notification center's delegate, so the notification shows with its sound
/// while the app is on screen too. It's the app's only notification.
@MainActor
final class NotificationRestAlert: NSObject, RestAlert, UNUserNotificationCenterDelegate {
    /// One fixed ID, so a new rest's notification replaces the previous one.
    private static let requestID = "rest-over"

    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "EpochLifts", category: "NotificationRestAlert")

    /// The scheduling in progress, cancelled if another rest starts or the rest is stopped
    /// while permission is still being asked for.
    private var scheduling: Task<Void, Never>?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func schedule(at date: Date) {
        scheduling?.cancel()
        scheduling = Task {
            do {
                let isAllowed = try await center.requestAuthorization(options: [.alert, .sound])
                let delay = date.timeIntervalSinceNow
                guard isAllowed, !Task.isCancelled, delay > 0 else { return }

                let content = UNMutableNotificationContent()
                content.title = "Rest over"
                content.body = "Time for your next set."
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                try await center.add(UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger))
            } catch {
                logger.error("Scheduling the rest notification failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func cancel() {
        scheduling?.cancel()
        scheduling = nil
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.requestID])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
