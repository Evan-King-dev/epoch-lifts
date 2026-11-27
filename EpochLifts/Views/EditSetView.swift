import SwiftUI
import WorkoutCore

/// The sheet for changing a saved set's weight and reps, in the workout in progress or a past one.
/// A successful save or a cancel closes it, because the presenting view shows it only while an edit is open.
struct EditSetView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Weight (lb)") {
                    TextField("0", text: $viewModel.editWeightText)
                        .keyboardType(.decimalPad)
                }
                LabeledContent("Reps") {
                    TextField("0", text: $viewModel.editRepsText)
                        .keyboardType(.numberPad)
                }
                if let message = viewModel.editErrorMessage {
                    Text(message)
                }
                Button("Save changes") {
                    viewModel.saveEdit()
                }
                Button("Cancel") {
                    viewModel.cancelEdit()
                }
            }
            .navigationTitle("Edit set")
        }
    }
}

#Preview {
    let set = LoggedSet(reps: 8, weightLb: 135, completedAt: .now, repSource: .manual)
    let bench = LoggedExercise(exercise: ExerciseType.defaults[0], sets: [set])
    let storage = InMemoryWorkoutStorage(workouts: [Workout(startedAt: .now, exercises: [bench])])
    let viewModel = WorkoutViewModel(storage: storage, repCounter: ManualRepCounter(), restAlert: SilentRestAlert())
    viewModel.beginEdit(setID: set.id)
    return EditSetView(viewModel: viewModel)
}
