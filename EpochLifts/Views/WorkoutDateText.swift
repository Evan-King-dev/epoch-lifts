import Foundation

/// Formats when a workout started, e.g. "Wed, Nov 25, 6:30 PM" in US English.
/// Shared so the history list and the workout screen always show the same format.
func workoutDateText(_ date: Date) -> String {
    date.formatted(.dateTime.weekday().month().day().hour().minute())
}
