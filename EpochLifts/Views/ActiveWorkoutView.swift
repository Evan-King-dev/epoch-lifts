import SwiftUI
import WorkoutCore

/// The workout in progress: its exercises and sets, logging new sets, adding exercises
/// and ending the workout.
struct ActiveWorkoutView: View {
    var viewModel: WorkoutViewModel

    @State private var isShowingExercisePicker = false
    @State private var isConfirmingEndWorkout = false
    @State private var isConfirmingDeleteExercise = false
    @State private var exerciseToDelete: LoggedExercise?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            StorageErrorSection(message: viewModel.storageErrorMessage)

            if let workout = viewModel.activeWorkout {
                Section {
                    WorkoutTimerView(workout: workout)
                    RestTimerView(viewModel: viewModel)
                }

                ForEach(workout.exercises) { exercise in
                    Section {
                        Text(exercise.exercise.name)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    exerciseToDelete = exercise
                                    isConfirmingDeleteExercise = true
                                }
                            }

                        LoggedSetRows(viewModel: viewModel, exercise: exercise)

                        LogSetView(viewModel: viewModel, exerciseID: exercise.id)
                    }
                }

                Section {
                    Button("Add exercise") {
                        isShowingExercisePicker = true
                    }
                    Button("End workout", role: .destructive) {
                        isConfirmingEndWorkout = true
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
        .confirmationDialog("End this workout?", isPresented: $isConfirmingEndWorkout, titleVisibility: .visible) {
            Button("End workout", role: .destructive) {
                viewModel.endWorkout()
                dismiss()
            }
        } message: {
            if viewModel.isActiveWorkoutEmpty {
                Text("This workout has no sets, so it won't be saved.")
            } else if viewModel.isSetInProgress {
                Text("The set in progress hasn't been saved and will be discarded.")
            }
        }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: $isConfirmingDeleteExercise,
            titleVisibility: .visible,
            presenting: exerciseToDelete
        ) { exercise in
            Button("Delete \(exercise.exercise.name)", role: .destructive) {
                viewModel.deleteExercise(id: exercise.id)
            }
        } message: { _ in
            Text("Its sets will be deleted too.")
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
        ActiveWorkoutView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter(), restAlert: SilentRestAlert()))
    }
}
