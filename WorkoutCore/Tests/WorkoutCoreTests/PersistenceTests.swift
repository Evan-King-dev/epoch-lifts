import Foundation
import Testing
import WorkoutCore

private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let oneHourLater = start.addingTimeInterval(3600)

/// One finished workout with sets from two sources, and one active workout.
private func sampleWorkouts() -> [Workout] {
    let bench = LoggedExercise(
        exercise: ExerciseType.defaults[0],
        sets: [
            LoggedSet(reps: 8, weightLb: 135, completedAt: start, repSource: .manual),
            LoggedSet(reps: 6, weightLb: 22.5, completedAt: oneHourLater, repSource: .watch),
        ]
    )
    return [
        Workout(startedAt: start, endedAt: oneHourLater, exercises: [bench]),
        Workout(startedAt: oneHourLater),
    ]
}

/// A file URL inside a new, empty temporary folder. The folder is not created.
private func makeTemporaryFileURL() -> (folder: URL, file: URL) {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    return (folder, folder.appending(path: "workouts.json"))
}

struct InMemoryWorkoutStorageTests {

    @Test func startsEmptyByDefault() {
        #expect(InMemoryWorkoutStorage().loadWorkouts().isEmpty)
    }

    @Test func saveThenLoadReturnsSameWorkouts() {
        let workouts = sampleWorkouts()
        let storage = InMemoryWorkoutStorage()
        storage.saveWorkouts(workouts)
        #expect(storage.loadWorkouts() == workouts)
    }
}

struct FileWorkoutStorageTests {

    @Test func missingFileLoadsEmpty() throws {
        let (_, file) = makeTemporaryFileURL()
        let storage = FileWorkoutStorage(fileURL: file)
        #expect(try storage.loadWorkouts().isEmpty)
    }

    @Test func saveThenLoadReturnsSameWorkouts() throws {
        let (folder, file) = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: folder) }

        let workouts = sampleWorkouts()
        try FileWorkoutStorage(fileURL: file).saveWorkouts(workouts)
        let loaded = try FileWorkoutStorage(fileURL: file).loadWorkouts()

        #expect(loaded == workouts)
    }

    @Test func secondSaveReplacesFirst() throws {
        let (folder, file) = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = FileWorkoutStorage(fileURL: file)

        try storage.saveWorkouts(sampleWorkouts())
        try storage.saveWorkouts([])

        #expect(try storage.loadWorkouts().isEmpty)
    }

    @Test func savedFileHasCurrentFormatVersion() throws {
        let (folder, file) = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: folder) }

        try FileWorkoutStorage(fileURL: file).saveWorkouts(sampleWorkouts())

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(json?["formatVersion"] as? Int == 1)
    }

    @Test func corruptFileThrowsAndIsLeftUnchanged() throws {
        let (folder, file) = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: file)

        #expect(throws: (any Error).self) {
            try FileWorkoutStorage(fileURL: file).loadWorkouts()
        }
        #expect(try Data(contentsOf: file) == corrupt)
    }

    @Test func newerFormatVersionThrows() throws {
        let (folder, file) = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"formatVersion": 2, "workouts": []}"#.utf8).write(to: file)

        #expect(throws: WorkoutStorageError.unsupportedFormatVersion(2)) {
            try FileWorkoutStorage(fileURL: file).loadWorkouts()
        }
    }
}
