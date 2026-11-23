import SwiftUI
import WorkoutCore

/// The elapsed time of a workout, updated every second. Kept in its own view so only this
/// row redraws each second, not the whole workout screen.
struct WorkoutTimerView: View {
    let workout: Workout

    var body: some View {
        // Ticks start at `startedAt` so the display changes exactly as each whole second passes.
        TimelineView(.periodic(from: workout.startedAt, by: 1)) { context in
            LabeledContent("Time", value: Self.text(for: workout.duration(now: context.date)))
        }
    }

    /// Formats seconds as hours, minutes and seconds, e.g. "0:05:07".
    /// Rounds down so the display never runs ahead of the real time.
    static func text(for seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(
            .time(pattern: .hourMinuteSecond(padHourToLength: 1, roundFractionalSeconds: .down))
        )
    }
}

#Preview {
    List {
        WorkoutTimerView(workout: Workout(startedAt: .now.addingTimeInterval(-307)))
    }
}
