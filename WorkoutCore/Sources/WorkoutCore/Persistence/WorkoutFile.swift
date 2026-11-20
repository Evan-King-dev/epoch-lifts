/// The top-level structure of the saved workouts file.
struct WorkoutFile: Codable {
    /// Increase when the saved format changes in a way old code cannot read, and add a migration.
    static let currentFormatVersion = 1

    var formatVersion: Int
    var workouts: [Workout]
}

/// Decodes only `formatVersion`, so the version can be checked before decoding the rest.
struct WorkoutFileHeader: Decodable {
    var formatVersion: Int
}
