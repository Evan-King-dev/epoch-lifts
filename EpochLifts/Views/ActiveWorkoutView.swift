import SwiftUI
import WorkoutCore

/// The workout in progress: its exercises and sets, logging new sets, adding exercises
/// and ending the workout.
struct ActiveWorkoutView: View {
    var viewModel: WorkoutViewModel

    @State private var isShowingExercisePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let message = viewModel.storageErrorMessage {
                Section {
                    Text(message)
                }
            }

            if let workout = viewModel.activeWorkout {
                ForEach(workout.exercises) { exercise in
                    Section {
                        Text(exercise.exercise.name)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteExercise(id: exercise.id)
                                }
                            }

                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            Text("Set \(index + 1): \(SetInput.text(forWeightLb: set.weightLb)) lb × \(set.reps)")
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteSet(id: set.id)
                                    }
                                }
                        }

                        LogSetView(viewModel: viewModel, exerciseID: exercise.id)
                    }
                }

                Section {
                    Button("Add exercise") {
                        isShowingExercisePicker = true
                    }
                    Button("End workout", role: .destructive) {
                        viewModel.endWorkout()
                        dismiss()
                    }
                }
            } else {
                Text("No workout in progress.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Workout")
        .sheet(isPresented: $isShowingExercisePicker) {
            ExercisePickerView { exerciseType in
                viewModel.addExercise(exerciseType)
                isShowingExercisePicker = false
            }
        }
    }
}

#Preview {
    let bench = LoggedExercise(
        exercise: ExerciseType.defaults[0],
        sets: [
            LoggedSet(reps: 8, weightLb: 135, completedAt: .now, repSource: .manual),
            LoggedSet(reps: 6, weightLb: 145, completedAt: .now, repSource: .manual),
        ]
    )
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now, exercises: [bench])])
    NavigationStack {
        ActiveWorkoutView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()))
    }
}
