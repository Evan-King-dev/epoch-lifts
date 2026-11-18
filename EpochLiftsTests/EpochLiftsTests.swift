//
//  EpochLiftsTests.swift
//  EpochLiftsTests
//
//  Created by Evan King on 2026-11-18.
//

import Testing
import WorkoutCore

struct EpochLiftsTests {

    @Test func workoutCoreIsLinked() {
        #expect(workoutCoreVersion == "0.1.0")
    }

}
