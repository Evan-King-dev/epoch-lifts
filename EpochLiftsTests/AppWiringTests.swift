import Foundation
import Testing
import WorkoutCore
@testable import EpochLifts

/// Tests for the composition root in `EpochLiftsApp`.
@MainActor
struct AppWiringTests {

    @Test func workoutsAreSavedToWorkoutsJSONAndReloaded() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }

        let viewModel = EpochLiftsApp.makeWorkoutViewModel(documentsFolder: folder)
        viewModel.startWorkout()
        let workoutID = try #require(viewModel.activeWorkout?.id)

        let fileURL = folder.appending(path: "workouts.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))

        let reloaded = EpochLiftsApp.makeWorkoutViewModel(documentsFolder: folder)
        #expect(reloaded.activeWorkout?.id == workoutID)
    }
}
