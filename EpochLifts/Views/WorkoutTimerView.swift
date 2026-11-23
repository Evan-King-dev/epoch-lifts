import SwiftUI
import WorkoutCore

/// The elapsed time of a workout, updated every second. Kept in its own view so only this
/// row redraws each second, not the whole workout screen.
struct WorkoutTimerView: View {
    let workout: Workout

    var body: some View {
        // Ticks start at `startedAt` so the display changes exactly as each whole second passes.
        TimelineView(.periodic(from: workout.startedAt, by: 1)) { context in
            LabeledContent("Time", value: elapsedTimeText(workout.duration(now: context.date)))
        }
    }
}

#Preview {
    List {
        WorkoutTimerView(workout: Workout(startedAt: .now.addingTimeInterval(-307)))
    }
}
