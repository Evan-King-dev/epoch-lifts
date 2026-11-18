# Epoch Lifts: Design and Decisions

How Epoch Lifts is built and why. Each decision is recorded as an Architecture Decision Record (ADR) with its context, decision, alternatives and consequences.

## 1. Goals and constraints

### Goals

1. A usable manual workout log from the first release.
2. Automatic rep counting and rep-quality feedback from motion data, added without reworking the app.
3. A codebase that is easy to test and read.

### Constraints

- One developer, about 8–10 hours a week.
- Hardware is limited to an iPhone and an Apple Watch.
- The iOS and watchOS simulators provide no real motion data, so sensor code must be testable without a device.

### Core requirement

Rep data can come from manual input, the Watch or a recording without changes to the UI. Most of the decisions below follow from this.

## 2. Architecture

```
Views → ViewModels → Services / Persistence → Models
```

| Layer | Responsibility |
|---|---|
| Models | `Codable` data and pure logic on it (`Workout.duration`, `totalSets`) |
| Services | Rep counting, exercise library |
| Persistence | Saving and loading workouts behind a protocol |
| ViewModels | Screen state, input parsing and validation, business rules, service calls |
| Views | Layout and display; forward user actions to the ViewModel |

Dependencies point one way. Models do not know about services, services do not know about views, and ViewModels do not import SwiftUI.

## 3. Decision records

### ADR-001: MVVM

**Context:** SwiftUI needs a place for state and logic that survives view updates and can be unit tested. Swappable rep sources also need a layer between views and services.

**Decision:** MVVM where it is useful. Screens with state and logic get a ViewModel; simple display views (such as a history row) take a model directly.

**Alternatives:**
- MV (no ViewModels): simpler for CRUD apps, but swappable rep sources push logic back into a middle layer.
- The Composable Architecture: highly testable, but a large third-party dependency with a steep learning curve.
- VIPER or full Clean Architecture: too much structure for one developer.

**Consequences:** ViewModels are plain classes and straightforward to test. `WorkoutViewModel` may grow too large; it will be split when sensor state is added.

### ADR-002: One protocol for all rep sources

**Context:** Reps can come from manual input, the Watch or a recording. The UI should not depend on which.

**Decision:** Every source implements `RepCountingService`:

```swift
protocol RepCountingService: AnyObject {
    var repEvents: AsyncStream<RepEvent> { get }
    var sourceType: RepCountSource { get }
    func startCounting()
    func stopCounting()
    func reset()
    func adjust(by delta: Int)   // user correction, for any source
}
```

- `adjust(by:)` is part of the protocol because sensors can miscount. Users can correct any source, and the ViewModel never casts to a concrete counter.
- `completeSet` takes no rep count. It reads the count from the active counter.

**Consequences:** Adding a source means writing one class and changing one line in the composition root.

### ADR-003: Rep events carry metrics

**Context:** A plain count is enough for manual input. Motion sources need to attach per-rep data (duration, range of motion, velocity) for feedback and ML.

**Decision:**

```swift
struct RepEvent: Sendable {
    let count: Int
    let metrics: RepMetrics?   // nil for manual input
}
```

**Consequences:** The protocol is the most expensive part of the design to change, since every source and the ViewModel depend on it. Including metrics now avoids a later breaking change.

### ADR-004: Apple Watch as the motion sensor

**Context:** Options for the motion source:

| | Bluetooth bar sensor | iPhone mounted on body | Apple Watch |
|---|---|---|---|
| Cost | ~$50–200+ | None | None (already owned) |
| Measures | The bar | Mount location | The wrist |
| Attachment | Included | Needs a mount; risk to phone | Already worn |
| Raw data access | Depends on vendor | Full | Full |
| Phone free during a set | Yes | No | Yes |

**Decision:** Apple Watch.

**Consequences:**
- Requires a watchOS target, `HKWorkoutSession` (keeps sensors running when the wrist is lowered) and WatchConnectivity.
- Measures the wrist, not the bar. Works for lifts held in the hands, less well for leg machines. Velocity is less precise than with a bar sensor.
- Several existing apps already count reps from Watch motion.

### ADR-005: Rep detection on the Watch

**Context:** WatchConnectivity is not built for continuous streaming at ~100 Hz. Messages can be delayed, batched or dropped.

**Decision:**
- Detect reps on the Watch and send only `RepEvent`s to the phone during a set.
- Record raw motion to a file on the Watch and transfer it after each set.
- The Watch is the source of truth for a set. If the phone is unreachable, the Watch keeps counting and syncs later.

**Consequences:** The phone shows reps within about a second, and complete raw data still reaches the phone for testing and ML. Detection code must run on both platforms (see ADR-006).

### ADR-006: Shared Swift package `WorkoutCore`

**Context:** The iOS and watchOS apps both need the models, `RepEvent` and the detection code.

**Decision:** A local Swift package, created during project setup.

**Consequences:** Detection is implemented and tested once. Creating the package now is cheap; moving code into one later is not.

### ADR-007: Replay counter

**Context:** The simulators provide no motion data, and testing at the gym is slow.

**Decision:** `ReplayRepCounter` plays recorded motion files through `RepCountingService`.

**Consequences:**
- Sensor work can be done in the simulator.
- Regression tests check that a given recording produces the expected rep count, so detection changes that break counting fail a test.
- The app can be demonstrated without a Watch.

### ADR-008: Repository protocol with JSON file storage

**Context:** The first version stored workouts as JSON in `UserDefaults`, which is intended for small settings. Workout history grows without limit.

**Decision:** A `WorkoutRepository` protocol with two implementations: a JSON file in the app's Documents folder, and an in-memory store for tests and previews.

**Rules:**
- The saved file includes a `schemaVersion` so older formats can be migrated.
- New model fields are optional so older files still decode.
- Decode failures are logged. Saved history is never replaced with an empty list.
- Raw sensor recordings are separate files referenced by ID, not stored in the workout JSON.

**Consequences:** A later move to SwiftData is a new implementation of the same protocol.

### ADR-009: `@Observable`, Swift 6 and `AsyncStream`

**Decision:**
- `@Observable` instead of `ObservableObject`. Views update only when the properties they read change, which matters when sensor data arrives several times a second. Nested observable objects also work correctly.
- Swift 6 language mode with strict concurrency from the start. Sensor callbacks, Watch messages and UI updates run on different threads, and the compiler catches data races. Enabling it later in a larger codebase is costly.
- `AsyncStream` for rep events instead of Combine. It fits Swift concurrency and wraps callback-based APIs easily.

### ADR-010: Stable exercise IDs and SI units

**Decision:**
- Built-in exercises are defined in `Exercise.defaults` with fixed string IDs such as `"bench-press"`. IDs generated at launch would break history grouping and per-exercise ML templates.
- Stored values use SI units (kg, seconds, m/s²). Values are converted to pounds only for display.

### ADR-011: Signal processing for counting, ML for quality

**Context:** Collecting labeled motion data is the most expensive part of any ML work.

**Decision:**
- Rep counting uses signal processing: smoothing, peak and valley detection, and a minimum rep duration.
- ML is used for rep quality. Each detected rep is one training sample with about 10–20 engineered features (range of motion, concentric and eccentric timing, velocity, smoothness), classified with small classical models.
- Faults (half reps, fast lowering, bouncing) are recorded on purpose and labeled one set at a time.
- Dynamic time warping against a lifter's own good reps gives feedback without any training.

**Risks:**

| Risk | Mitigation |
|---|---|
| Model only fits one lifter | Collect data from several people; test on people not in the training set |
| Python and Swift feature code diverge | Run the same recording through both and compare outputs |
| Velocity drift from integrating acceleration | Reset velocity to zero at the top and bottom of each rep |
| Sensor placement varies | Prefer features that do not depend on orientation |

**Limitations:** A single wrist sensor cannot assess full-body form, such as knee position.

## 4. Testing

- Layers are built bottom-up. Each step ends with passing tests and a commit.
- ViewModels are tested with a fake rep counter and the in-memory repository.
- Persistence is tested by saving and reloading data.
- Rep detection is tested against recorded motion files using the replay counter.
- CI runs the tests on every push.

## 5. Build order

0. Project setup, repository, documentation
1. Models and exercise catalogue
2. Persistence
3. Rep counting protocol and manual counter
4. ViewModel
5. Composition root
6. Unstyled views
7. CI
8. Device testing and TestFlight

V0.2 (Apple Watch): watchOS app, workout session and motion recording, file transfer, replay counter, rep detection, live rep events on the iPhone, range-of-motion validation.

## 6. Changelog

| Date | Change |
|---|---|
| 2026-11 | Initial design. V0.1 restarted with a test-first architecture; Apple Watch chosen as the motion sensor. |
| 2026-11 | Accepted ADR-006 (`WorkoutCore` package), ADR-008 (JSON file storage) and ADR-009 (`@Observable`, Swift 6, `AsyncStream`). |
| 2026-11 | Removed camera-based tracking (former ADR-012) and AI coaching from scope. |
| 2026-11 | Reformatted: statuses written as text, wording tightened. No decisions changed. |
| 2026-11 | Accepted ADR-003 (rep events carry metrics), ADR-007 (replay counter), ADR-010 (stable exercise IDs, SI units) and ADR-011 (signal processing for counting, ML for quality). |
