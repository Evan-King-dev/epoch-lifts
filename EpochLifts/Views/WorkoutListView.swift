import SwiftUI
import WorkoutCore

/// The start screen: start or resume a workout, and browse and delete past workouts.
struct WorkoutListView: View {
    var viewModel: WorkoutViewModel

    @State private var isShowingActiveWorkout = false

    var body: some View {
        NavigationStack {
            List {
                StorageErrorSection(message: viewModel.storageErrorMessage)

                Section {
                    if viewModel.canStartWorkout {
                        Button("Start workout") {
                            viewModel.startWorkout()
                            isShowingActiveWorkout = true
                        }
                    } else {
                        Button("Resume workout") {
                            isShowingActiveWorkout = true
                        }
                    }
                }

                Section("History") {
                    if viewModel.pastWorkouts.isEmpty {
                        Text("No past workouts yet.")
                    }
                    ForEach(viewModel.pastWorkouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(viewModel: viewModel, workoutID: workout.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(workoutDateText(workout.startedAt))
                                Text("\(elapsedTimeText(workout.duration())) · Exercises: \(workout.exercises.count) · Sets: \(workout.totalSets)")
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteWorkout(id: workout.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(isPresented: $isShowingActiveWorkout) {
                ActiveWorkoutView(viewModel: viewModel)
            }
        }
        .sheet(item: editingSetBinding) { _ in
            EditSetView(viewModel: viewModel)
        }
    }

    /// Shows the edit sheet while an edit is open on a set that still exists, from any
    /// screen in the stack. Swiping the sheet away cancels the edit.
    private var editingSetBinding: Binding<LoggedSet?> {
        Binding(
            get: { viewModel.editingSet },
            set: { newValue in
                if newValue == nil {
                    viewModel.cancelEdit()
                }
            }
        )
    }
}

#Preview("With history") {
    let pastWorkout = Workout(
        startedAt: .now.addingTimeInterval(-86_400),
        endedAt: .now.addingTimeInterval(-82_800),
        exercises: [
            LoggedExercise(
                exercise: ExerciseType.defaults[0],
                sets: [LoggedSet(reps: 8, weightLb: 135, completedAt: .now, repSource: .manual)]
            )
        ]
    )
    let storage = InMemoryWorkoutStorage(workouts: [pastWorkout])
    WorkoutListView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter(), restAlert: SilentRestAlert()))
}

#Preview("Workout in progress") {
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now)])
    WorkoutListView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter(), restAlert: SilentRestAlert()))
}
