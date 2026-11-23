import Foundation

/// Formats a number of seconds as hours, minutes and seconds, e.g. "0:05:07".
/// Rounds down so a running timer never shows a second early.
func elapsedTimeText(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(
        .time(pattern: .hourMinuteSecond(padHourToLength: 1, roundFractionalSeconds: .down))
    )
}
