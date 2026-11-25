import SwiftUI
import WorkoutCore

/// The app entry point and composition root: the only place real implementations are
/// created and wired together.
@main struct EpochLiftsApp: App {
    @State private var viewModel = EpochLiftsApp.makeWorkoutViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WorkoutListView(viewModel: viewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.endForgottenWorkout()
            }
        }
    }

    /// Builds the ViewModel with file storage and manual rep counting (ADR-009, ADR-008).
    ///
    /// - Parameter documentsFolder: The folder that holds `workouts.json`. Tests pass a
    ///   temporary folder. Changing the file name would hide existing history.
    static func makeWorkoutViewModel(documentsFolder: URL = .documentsDirectory) -> WorkoutViewModel {
        let storage = FileWorkoutStorage(fileURL: documentsFolder.appending(path: "workouts.json"))
        return WorkoutViewModel(storage: storage, repCounter: ManualRepCounter())
    }
}
