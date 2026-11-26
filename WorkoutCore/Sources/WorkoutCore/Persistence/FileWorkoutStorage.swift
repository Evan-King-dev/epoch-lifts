import Foundation

/// Keeps the workout history in a single JSON file, for example
/// `Application Support/workouts.json` (ADR-008).
public struct FileWorkoutStorage: WorkoutStorage {
    /// Location of the JSON file. The app uses its Application Support folder; tests use a
    /// temporary folder. Changing the folder or the file name would hide existing history.
    /// The folder is created on the first save, since iOS doesn't create Application Support.
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadWorkouts() throws -> [Workout] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()

        let header = try decoder.decode(WorkoutFileHeader.self, from: data)
        guard header.formatVersion <= WorkoutFile.currentFormatVersion else {
            throw WorkoutStorageError.unsupportedFormatVersion(header.formatVersion)
        }

        return try decoder.decode(WorkoutFile.self, from: data).workouts
    }

    /// Writes to a temporary file and then replaces the old one, so a failed save
    /// never leaves a partially written file.
    public func saveWorkouts(_ workouts: [Workout]) throws {
        let file = WorkoutFile(formatVersion: WorkoutFile.currentFormatVersion, workouts: workouts)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
