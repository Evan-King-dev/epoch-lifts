import Foundation
import Testing
import WorkoutCore
@testable import EpochLifts

/// Tests for the composition root in `EpochLiftsApp`.
@MainActor
struct AppWiringTests {

    @Test func defaultStorageFolderIsApplicationSupport() {
        #expect(EpochLiftsApp.defaultStorageFolder.lastPathComponent == "Application Support")
    }

    /// Starts from a folder that doesn't exist yet, like Application Support on a fresh install.
    @Test func workoutsAreSavedToWorkoutsJSONAndReloaded() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))

        let viewModel = EpochLiftsApp.makeWorkoutViewModel(storageFolder: folder)
        viewModel.startWorkout()
        let workoutID = try #require(viewModel.activeWorkout?.id)

        let fileURL = folder.appending(path: "workouts.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))

        let reloaded = EpochLiftsApp.makeWorkoutViewModel(storageFolder: folder)
        #expect(reloaded.activeWorkout?.id == workoutID)
    }
}
