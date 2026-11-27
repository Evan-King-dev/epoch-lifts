import SwiftUI
import WorkoutCore

/// The rest rows on the workout screen: the countdown and Skip while a rest is running,
/// and the rest duration control (ADR-018).
struct RestTimerView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        if let startedAt = viewModel.restTimer.startedAt {
            // Ticks start at `startedAt`, and durations are whole seconds, so the last tick
            // lands exactly on the end of the rest.
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                if viewModel.restTimer.isFinished(now: context.date) {
                    LabeledContent("Rest", value: "Rest over")
                } else {
                    LabeledContent("Rest", value: restTimeText(viewModel.restTimer.remaining(now: context.date) ?? 0))
                }
            }
            Button("Skip rest") {
                viewModel.skipRest()
            }
        }

        Stepper(value: $viewModel.restDuration, in: RestTimer.durationRange, step: RestTimer.durationStep) {
            LabeledContent("Rest time", value: restTimeText(viewModel.restDuration))
        }
    }
}

/// Formats a number of seconds as minutes and seconds, e.g. "1:45".
/// Rounds up so a countdown shows "0:00" only once the time is over.
func restTimeText(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(
        .time(pattern: .minuteSecond(padMinuteToLength: 1, roundFractionalSeconds: .up))
    )
}

#Preview {
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now)])
    List {
        RestTimerView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter(), restAlert: SilentRestAlert()))
    }
}
