//
//  EpochLiftsTests.swift
//  EpochLiftsTests
//
//  Created by Evan King on 2026-11-18.
//

import Testing
import WorkoutCore

struct EpochLiftsTests {

    /// Checks the app target can see WorkoutCore's public types.
    @Test func workoutCoreIsLinked() {
        #expect(!ExerciseType.defaults.isEmpty)
    }

}
