import SwiftUI
import WorkoutCore

/// The rows for logging a set of one exercise: start the set, finish it, then check weight
/// and reps and save (ADR-015). Shows nothing while another exercise's set is in progress.
struct LogSetView: View {
    @Bindable var viewModel: WorkoutViewModel
    let exerciseID: UUID

    var body: some View {
        switch viewModel.setPhase {
        case .notStarted:
            Button("Start set") {
                viewModel.beginSet(for: exerciseID)
            }

        case .lifting(let id) where id == exerciseID:
            Button("Finish set") {
                viewModel.finishSet()
            }
            Button("Cancel set") {
                viewModel.cancelSet()
            }

        case .enteringReps(let id) where id == exerciseID:
            LabeledContent("Weight (lb)") {
                TextField("0", text: $viewModel.weightText)
                    .keyboardType(.decimalPad)
            }
            LabeledContent("Reps") {
                TextField("0", text: $viewModel.repsText)
                    .keyboardType(.numberPad)
            }
            if let message = viewModel.inputErrorMessage {
                Text(message)
            }
            Button("Save set") {
                viewModel.completeSet()
            }
            Button("Cancel set") {
                viewModel.cancelSet()
            }

        default:
            EmptyView()
        }
    }
}

#Preview {
    let bench = LoggedExercise(exercise: ExerciseType.defaults[0])
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now, exercises: [bench])])
    List {
        LogSetView(
            viewModel: WorkoutViewModel(storage: storage, repCounter: ManualRepCounter()),
            exerciseID: bench.id
        )
    }
}
