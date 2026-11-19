# Epoch Lifts


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
| Apple Watch rep counting from wrist motion (CoreMotion) | Planned (V0.2) |
| Range-of-motion validation (partial reps don't count) | Planned (V0.2) |
| Raw motion recording + replay for testing and ML datasets | Planned (V0.2) |
| Per-rep feedback: tempo, consistency, velocity loss / fatigue | Planned (V0.3) |
| ML rep-quality models trained on recorded motion data | Planned (V0.3) |

---

## Architecture at a glance

The core design goal: **rep data can come from manual input, the Watch, or a replayed recording without changing any UI code.**

```
Views  →  ViewModels  →  Services / Persistence  →  Models
```

- **MVVM**, with dependencies pointing one way only. ViewModels never import SwiftUI.
- **Every rep source implements one protocol**, `RepCountingService`, and emits `RepEvent`s:
  `ManualRepCounter` · `WatchRepCounter` · `ReplayRepCounter` · test fakes
- **Composition root:** all real implementations are wired together in one place, so swapping a data source or storage backend is a one-line change.
- **Shared Swift package (`WorkoutCore`)** holds the models and rep-detection code used by both the iOS and watchOS apps.
- **Edge processing on the Watch:** rep detection runs on the Watch and sends small `RepEvent`s to the phone live. The raw ~100 Hz motion recording transfers after each set.

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
- **Swift Testing** unit tests; GitHub Actions CI: *planned*
- Persistence: Codable JSON file store behind a repository protocol (SwiftData migration planned)

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
Then build and run with **⌘R**. Run the tests with **⌘U**.

---

## Roadmap

- **V0.1**: Manual tracking rebuilt with tests, clean architecture, CI, TestFlight
- **V0.2**: Apple Watch app: motion recording, rep detection, live rep counts on iPhone, ROM validation
- **V0.3**: Per-rep feedback and ML rep-quality models trained on recorded motion data

---

## Project structure

```
EpochLifts/            iOS app (Views, ViewModels, Services, Persistence)
EpochLiftsTests/       Unit tests
EpochLiftsWatch/       watchOS app (planned)
WorkoutCore/           Shared Swift package: models, RepEvent, rep detection
docs/                  Design notes and decision records
```

---

## License

© 2026 Evan King. All rights reserved. Code shared for portfolio viewing.
