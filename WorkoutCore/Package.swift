// swift-tools-version: 6.0

import PackageDescription

/// WorkoutCore: code shared by the iOS and watchOS apps (models, RepEvent, rep detection).
/// Why it's a separate package: see ADR-005 in docs/DESIGN.md.
let package = Package(
    name: "WorkoutCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
    ],
    targets: [
        .target(name: "WorkoutCore"),
        .testTarget(name: "WorkoutCoreTests", dependencies: ["WorkoutCore"]),
    ]
)
