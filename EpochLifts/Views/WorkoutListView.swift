import SwiftUI
import WorkoutCore

/// The start screen: start or resume a workout, and browse and delete past workouts.
struct WorkoutListView: View {
    var viewModel: WorkoutViewModel

    @State private var isShowingActiveWorkout = false

    var body: some View {
        NavigationStack {
            List {
                if let message = viewModel.storageErrorMessage {
                    Section {
                        Text(message)
                    }
                }

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
                        VStack(alignment: .leading) {
                            Text(workout.startedAt, format: .dateTime.weekday().month().day().hour().minute())
                            Text("Exercises: \(workout.exercises.count) · Sets: \(workout.totalSets)")
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
    WorkoutListView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()))
}

#Preview("Workout in progress") {
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now)])
    WorkoutListView(viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()))
}
