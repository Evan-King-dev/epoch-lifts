import SwiftUI
import WorkoutCore

/// A list of the built-in exercises. Calls `onSelect` with the one the user taps.
struct ExercisePickerView: View {
    let onSelect: (ExerciseType) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ExerciseType.defaults) { exerciseType in
                Button(exerciseType.name) {
                    onSelect(exerciseType)
                }
            }
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
