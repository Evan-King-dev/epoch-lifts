import SwiftUI
import WorkoutCore

/// A past workout: its date, duration, and each exercise's sets, with swipe to delete.
/// Looks the workout up by ID so it always shows the latest data, and closes itself if the
/// workout is deleted (for example, when its last set is removed).
struct WorkoutDetailView: View {
    var viewModel: WorkoutViewModel
    let workoutID: UUID

    @State private var isConfirmingDeleteExercise = false
    @State private var exerciseToDelete: LoggedExercise?
    @Environment(\.dismiss) private var dismiss

    private var workout: Workout? {
        viewModel.workout(id: workoutID)
    }

    var body: some View {
        List {
            StorageErrorSection(message: viewModel.storageErrorMessage)

            if let workout {
                Section {
                    LabeledContent("Date", value: workoutDateText(workout.startedAt))
                    LabeledContent("Duration", value: elapsedTimeText(workout.duration()))
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
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .onChange(of: workout == nil) { _, isDeleted in
            if isDeleted {
                dismiss()
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
    let past = Workout(
        startedAt: .now.addingTimeInterval(-3_600),
        endedAt: .now,
        exercises: [
            LoggedExercise(
                exercise: ExerciseType.defaults[0],
                sets: [
                    LoggedSet(reps: 8, weightLb: 135, completedAt: .now, repSource: .manual),
                    LoggedSet(reps: 6, weightLb: 145, completedAt: .now, repSource: .manual),
                ]
            )
        ]
    )
    let storage = InMemoryWorkoutStorage(workouts: [past])
    NavigationStack {
        WorkoutDetailView(
            viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()),
            workoutID: past.id
        )
    }
}
