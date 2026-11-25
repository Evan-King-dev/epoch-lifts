# Epoch Lifts

[![CI](https://github.com/Evan-King-dev/epoch-lifts/actions/workflows/ci.yml/badge.svg)](https://github.com/Evan-King-dev/epoch-lifts/actions/workflows/ci.yml)

**A workout tracker for iPhone and Apple Watch that counts reps from wrist motion and analyzes lift quality with on-device machine learning.**

---

## Why this project

Most workout loggers make you type in every rep, which gets tedious, so many people stop tracking their workouts. But tracking your lifts is the best way to ensure progressive overload and see results from your hard work. Epoch Lifts aims to count reps automatically with an Apple Watch and use ML to give feedback that helps you get more out of your gym sessions.

Epoch Lifts is mainly a learning project covering: a thorough exploration of SwiftUI architecture, multi-device iOS/watchOS development, motion signal processing and on-device ML.

---

## Features

| Feature | Status |
|---|---|
| Manual workout logging: exercises, sets, reps, weight, history | In progress (V0.1) |
| Edit a saved set's weight and reps | Done (V0.1) |
| Rest timer that starts when a set is saved | Planned (after V0.1) |
| Custom exercises | Planned (after V0.1) |
| Workout templates | Planned (after V0.1) |
| Exercise history: past sessions, "last time" while logging, PRs and estimated 1RM | Planned (after V0.1) |
| CSV/JSON export | Planned (after V0.1) |
| Apple Watch rep counting from wrist motion (CoreMotion) | Planned (V0.2) |
| Range-of-motion validation (partial reps don't count) | Planned (V0.2) |
| Raw motion recording + replay for testing and ML datasets | Planned (V0.2) |
| Per-rep feedback: tempo, consistency, velocity loss / fatigue | Planned (V0.3) |
| Personal ML rep-quality models trained on my own motion data (may expand to more lifters later) | Planned (V0.3) |

---

## Architecture at a glance

The core design goal: **rep data can come from manual input, the Watch, or a replayed recording without changing any UI code.**

```
Views  →  ViewModels  →  Services / Persistence  →  Models
```

- **MVVM**, with dependencies pointing one way only. ViewModels never import SwiftUI.
- **Every rep source implements one protocol**, `RepCountingService`, and emits `RepEvent`s:
  `ManualRepCounter` · test fakes; `WatchRepCounter` and `ReplayRepCounter` planned (V0.2)
- **Composition root:** all real implementations are wired together in one place, so a new rep source or storage backend needs no changes to views or ViewModels.
- **Shared Swift package (`WorkoutCore`)** holds the models, persistence, rep counting and input parsing, and later the rep-detection code, for both the iOS and watchOS apps.
- **Edge processing on the Watch (planned, V0.2):** rep detection runs on the Watch and sends small `RepEvent`s to the phone live. The raw ~100 Hz motion recording transfers after each set.

```
Watch                                            iPhone
CoreMotion ~100 Hz
  → rep detection (WorkoutCore)
  → RepEvent ─────── live, tiny messages ───────▶ WatchRepCounter → ViewModel → UI
  → raw recording ── file transfer after set ───▶ saved for replay tests + ML
```

Full reasoning for each design choice: **[docs/DESIGN.md](docs/DESIGN.md)**

---

## Tech stack

- **Swift 6**, **SwiftUI**, Swift Concurrency (`async`/`await`, `AsyncStream`)
- **watchOS**, **CoreMotion**, **HealthKit** (`HKWorkoutSession`), **WatchConnectivity**: *planned*
- **Core ML**, **Create ML**; Python + scikit-learn for model prototyping: *planned*
- **Swift Testing** unit tests; GitHub Actions CI on pull requests and pushes to main
- Persistence: Codable JSON file store behind a repository protocol

---

## Getting started

**Requirements**
- Xcode 27.2 or later (the project uses Xcode's JSON `.xcproj` project format)
- iOS device or simulator, minimum iOS version 17.0
- Apple Watch: required for motion features once V0.2 lands; the simulators don't provide real motion data

**Run**
```bash
git clone https://github.com/Evan-King-dev/epoch-lifts.git
cd epoch-lifts
open EpochLifts.xcodeproj
```
Then build and run with **⌘R**. Run the app tests with **⌘U**. The `WorkoutCore` package tests run separately on the Mac:
```bash
cd WorkoutCore && swift test
```

---

## Roadmap

Versions, planned features and proposed design decisions: **[docs/ROADMAP.md](docs/ROADMAP.md)**. Current feature status is in the [Features](#features) table above.

---

## Project structure

```
EpochLifts/            iOS app: views and ViewModels
EpochLiftsTests/       App tests: ViewModel, wiring and formatting (run in the iOS simulator)
EpochLiftsWatch/       watchOS app (planned)
WorkoutCore/           Shared Swift package: models, persistence, rep counting, input parsing; rep detection (planned)
docs/                  Design notes and decision records
```

---

## License

© 2026 Evan King. All rights reserved. Code shared for portfolio viewing.
