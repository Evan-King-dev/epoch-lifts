import SwiftUI
import WorkoutCore

/// One row per saved set of an exercise, numbered from 1. Tap to edit, swipe to delete.
/// Shared by the workout in progress and past workouts.
struct LoggedSetRows: View {
    var viewModel: WorkoutViewModel
    let exercise: LoggedExercise

    var body: some View {
        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
            Button("Set \(index + 1): \(SetInput.text(forWeightLb: set.weightLb)) lb × \(set.reps)") {
                viewModel.beginEdit(setID: set.id)
            }
            .swipeActions {
                Button("Delete", role: .destructive) {
                    viewModel.deleteSet(id: set.id)
                }
            }
        }
    }
}

#Preview {
    let bench = LoggedExercise(
        exercise: ExerciseType.defaults[0],
        sets: [
            LoggedSet(reps: 8, weightLb: 135, completedAt: .now, repSource: .manual),
            LoggedSet(reps: 6, weightLb: 22.5, completedAt: .now, repSource: .manual),
        ]
    )
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now, exercises: [bench])])
    List {
        LoggedSetRows(
            viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()),
            exercise: bench
        )
    }
}
