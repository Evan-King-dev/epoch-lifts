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

    /// The folder that holds `workouts.json` on the device: Application Support, which the
    /// Files app never shows (ADR-008). Changing it would hide existing history.
    static let defaultStorageFolder: URL = .applicationSupportDirectory

    /// Builds the ViewModel with file storage and manual rep counting (ADR-009, ADR-008).
    ///
    /// - Parameter storageFolder: The folder that holds `workouts.json`. Tests pass a
    ///   temporary folder. Changing the folder or the file name would hide existing history.
    static func makeWorkoutViewModel(
        storageFolder: URL = EpochLiftsApp.defaultStorageFolder
    ) -> WorkoutViewModel {
        let storage = FileWorkoutStorage(fileURL: storageFolder.appending(path: "workouts.json"))
        return WorkoutViewModel(storage: storage, repCounter: ManualRepCounter())
    }
}
