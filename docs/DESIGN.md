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
@MainActor
protocol RepCountingService: AnyObject {
    var count: Int { get }       // current count, never negative
    var repEvents: AsyncStream<RepEvent> { get }
    var sourceType: RepCountSource { get }
    func startCounting()
    func stopCounting()
    func reset()
    func correctCount(to reps: Int)   // user correction after the set, for any source
}
```

- `correctCount(to:)` is part of the protocol because sensors can miscount. Users can correct any source, and the ViewModel never casts to a concrete counter.
- `completeSet` takes no rep count. It reads the count from the active counter.
- `count` lets `completeSet` read the count directly instead of tracking the last event. `correctCount(to:)` treats negative numbers as 0.
- The protocol is `@MainActor`, like the ViewModel, so counters need no locks. Sources that get data on other threads (the Watch) switch to the main actor before updating.
- Every change to `count` (a rep, a correction, a reset) sends a `RepEvent`.
- Reps are entered or corrected only after the set, in a number box, so the user never touches the phone mid-set. `correctCount(to:)` takes the typed number rather than a +/- difference, so a late sensor event can't shift the saved count away from what the user typed. Corrections are meant for after `stopCounting()`.
- `ManualRepCounter` is the no-sensor source: used without a Watch, for exercises the wrist can't count, or when the Watch disconnects.

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

`RepMetrics` is an empty placeholder until motion sources add its fields in V0.2.

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

### ADR-008: Workout storage protocol with a JSON file

**Context:** The first version stored workouts as JSON in `UserDefaults`, which is intended for small settings. Workout history grows without limit.

**Decision:** A `WorkoutStorage` protocol with two implementations: `FileWorkoutStorage`, a JSON file in the app's Documents folder, and `InMemoryWorkoutStorage` for tests and previews.

**Rules:**
- The saved file includes a `formatVersion` so older formats can be migrated.
- New model fields are optional so older files still decode.
- Decode failures are logged. Saved history is never replaced with an empty list.
- Raw sensor recordings are separate files referenced by ID, not stored in the workout JSON.
- The storage code lives in `WorkoutCore`, so its tests run on the Mac with `swift test` and the Watch can reuse it.
- The API is synchronous (`loadWorkouts() throws`, `saveWorkouts(_:) throws`) and saves the whole history at once. The file is small, so this is fast enough on the main thread. If the history grows large, the protocol becomes `async`.
- A missing file loads as an empty list. A corrupt file, or one with a newer `formatVersion`, throws and is left untouched.
- Saves are atomic: the file is written in full to a temporary location, then swapped in.

**Consequences:** A later move to SwiftData is a new implementation of the same protocol.

### ADR-009: `@Observable`, Swift 6 and `AsyncStream`

**Decision:**
- `@Observable` instead of `ObservableObject`. Views update only when the properties they read change, which matters when sensor data arrives several times a second. Nested observable objects also work correctly.
- Swift 6 language mode with strict concurrency from the start. Sensor callbacks, Watch messages and UI updates run on different threads, and the compiler catches data races. Enabling it later in a larger codebase is costly.
- `AsyncStream` for rep events instead of Combine. It fits Swift concurrency and wraps callback-based APIs easily.

### ADR-010: Stable exercise IDs and units

**Decision:**
- Built-in exercises are defined in `ExerciseType.defaults` with fixed string IDs such as `"bench-press"`. IDs generated at launch would break history grouping and per-exercise ML templates.
- Weights are stored in pounds, exactly as entered (`weightLb`). Local gyms use pound plates, and storing kilograms would turn entered values like 225 lb into 102.058… kg, with rounding errors when converted back for display.
- Physics and ML code that needs kilograms converts with a single `weightKg` property (`weightLb × 0.45359237`), added when first needed in V0.3. Rep detection does not use weight.
- Time and sensor data use SI units (seconds, m/s²).

**Alternatives:** Store kilograms and convert to pounds for input and display (the original version of this decision). Rejected because every input and display would need conversion and rounding.

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

### ADR-013: iPhone only, iOS 17 minimum

**Context:** The Xcode template targets iPhone, iPad, Mac and Vision Pro. Each extra platform adds layouts to test and APIs to check, and the motion features depend on an iPhone paired with an Apple Watch.

**Decision:**
- The app runs on iPhone only.
- Minimum iOS 17.0, the earliest version that supports `@Observable` (ADR-009).
- `WorkoutCore` supports iOS 17 and watchOS 10 (the matching Watch release). It also lists macOS 14 so its tests can run on a Mac without a simulator.

**Alternatives:**
- iPhone and iPad: little extra work for manual logging, but every screen needs a second layout. Can be added later.
- iOS 18 or later: newer APIs without availability checks, but it excludes devices still on iOS 17.

**Consequences:** APIs newer than iOS 17 need `if #available` checks. Adding iPad later means changing the target's device family and testing layouts; no architecture changes.

### ADR-014: Workout data model

**Context:** The first models define the saved JSON format, which every later version must still decode (ADR-008). They live in `WorkoutCore` so the Watch app can use them.

**Decision:**

```
Workout          id, startedAt, endedAt?, exercises: [LoggedExercise]
LoggedExercise   id, exercise: ExerciseType, sets: [LoggedSet]
LoggedSet        id, reps, weightLb, completedAt, repSource: RepCountSource
ExerciseType     id (stable string), name
RepCountSource   manual | watch | replay
```

How they nest:

```
Workout                              one gym visit
└─ exercises: [LoggedExercise]       each exercise you did in it
   ├─ exercise: ExerciseType         which exercise (copied from the catalogue)
   └─ sets: [LoggedSet]              the sets you did
      └─ repSource: RepCountSource   manual, watch or replay
```

- "Logged…" types are what you actually did; `ExerciseType` is the catalogue entry. `RepCountSource` says where a set's rep count came from. Per-rep data (`RepMetrics`, ADR-003) is a separate, later field on `LoggedSet`, not a replacement for it.
- Source files stay in one flat `Models/` folder; the tree above (also in the doc comment on `Workout`) shows how they relate.

- Models are structs (or enums for fixed value sets). Each protocol is added for a reason:
  - `Codable`: saved, or contained in something saved. Required all the way down, since a type only encodes if its properties do.
  - `Hashable`: needs `==` (e.g. tests), or is contained in a `Hashable` type. Also required all the way down.
  - `Sendable`: every public type in `WorkoutCore`. Swift does not infer it across module boundaries, and Swift 6 needs it to pass values between actors.
  - `Identifiable`: only types shown as their own item in a list or `ForEach`, or that need a stable identity. `Workout`, `LoggedExercise`, `LoggedSet` and `ExerciseType` have it; `RepCountSource` does not.
- A `LoggedExercise` stores a copy of its `ExerciseType`, so history keeps the name even if the catalogue changes, and views need no lookup.
- `weightLb` of 0 means bodyweight.
- `Workout.endedAt` is nil while the workout is in progress. `isActive` and `totalSets` are computed. `duration(now:)` takes the current time as a parameter so it can be tested.
- Workouts, sessions and sets use UUIDs generated once at creation. Only catalogue exercises need stable IDs (ADR-010).
- Not included yet: recording IDs, rep metrics, custom exercises. Each will be added as an optional field or a separate feature when needed.

**Alternatives:**
- Store only `exerciseID` in a session: smaller, but every view would need the catalogue to show a name.
- Optional weight with nil for bodyweight: more precise, but adds nil handling everywhere for little benefit.

**Consequences:** The saved format follows these types directly. `formatVersion` belongs to the file wrapper added with persistence (step 2), not to the models.

### ADR-015: Workout ViewModel and set input

**Decision:**
- `WorkoutViewModel` lives in the app target: it is iPhone screen state, and the Watch will have its own. Pure logic it uses, such as `SetInput` (parsing the weight and reps boxes), lives in `WorkoutCore` so it is tested with `swift test`.
- Set flow: `beginSet` → `finishSet` → `completeSet` or `cancelSet`. The reps box is plain text until Done; `completeSet` passes it to `correctCount(to:)` and saves the counter's `count` (ADR-002). No separate `correctReps`.
- Validation: weight is 0 or more (0 = bodyweight); reps are a whole number of 1 or more.
- Pre-fill from the previous set of the same exercise in this workout: weight always, reps only when the counter reads 0, so a sensor count is never replaced.
- After a failed load, saving is off for the session (ADR-008).

**Alternatives:** ViewModel in `WorkoutCore` (faster tests, but iPhone state in the shared package and `public` everywhere); no pre-fill (simpler, but most sets repeat the last one).

**Consequences:** ViewModel tests need the simulator. Reading `repEvents` live waits for the Watch counter in V0.2.

## 4. Testing

- Layers are built bottom-up. Each step ends with passing tests and a commit.
- ViewModels are tested with a fake rep counter and `InMemoryWorkoutStorage`.
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
