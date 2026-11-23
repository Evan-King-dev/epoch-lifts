# Epoch Lifts: Roadmap

What comes next, and the design decisions proposed for it. Decisions already in effect are in [DESIGN.md](DESIGN.md). A proposed decision moves there once it is accepted, when its version starts.

## Versions

| Version | Scope |
|---|---|
| **V0.1** | Manual tracking: pick exercises, log sets/reps/weight, history. Rebuilt from scratch with tests and clean architecture. |
| **V0.2** | **Apple Watch** motion sensing: auto rep counting, basic range-of-motion (ROM) validation, raw motion recording, replay. |
| V0.2.x | Optional iPhone motion counter (CoreMotion), reusing the Watch detection code. |
| **V0.3** | Per-rep feedback and personal ML rep-quality models trained on my own recorded Watch data. |

## Planned features

### V0.1

- Edit a saved set's weight and reps (build step 8, before TestFlight).

### After V0.1

In order:

1. Rest timer: starts automatically when a set is saved, notifies when done.
2. Custom exercises: needs an ADR on IDs and storage when built.
3. Workout templates: a named list of exercises; start a workout from one on the home screen; created with "Save as template" from a past workout, with an edit screen later; the first set of each exercise pre-fills from the most recent set of that exercise in history (changes ADR-011's pre-fill rule when built).
4. Exercise history: every past session of one exercise, "last time" shown inline while logging, PRs and estimated 1RM; charts after styling starts.
5. CSV/JSON export via the share sheet.

Later: exercise search and filter, notes, plate calculator, Apple Health export with V0.2.

### V0.2: Apple Watch

- watchOS app `EpochLiftsWatch`: start and stop sets, live rep count.
- `HKWorkoutSession` keeps the app and sensors running when the wrist is lowered.
- Raw motion recording on the Watch, transferred to the phone after each set.
- Rep detection in `WorkoutCore`, with regression tests on recorded and synthetic data.
- `ReplayRepCounter` for simulator work and demos without a Watch.
- Live rep counts on the iPhone and range-of-motion validation.
- Optional: a live raw motion graph.
- The Watch starts with Start/Finish buttons; automatic set start and end is a later option, and button-marked sets become its training data.

### V0.3: Feedback and ML

- Per rep: partial reps compared with usual ROM, tempo ("slow the lowering"), bounce and pause detection, consistency score.
- Per set: velocity loss as a fatigue and reps-in-reserve estimate (velocity-based training).
- Over time: trends.
- Optional: automatic exercise detection.
- Not possible with one wrist sensor: full-body form such as knee cave or back rounding.
- An optional reps-in-reserve (RIR) field on `LoggedSet` would collect labels for the velocity-loss model; consider adding it early.

## Proposed decisions

These continue the numbering of ADR-001 to 011 in DESIGN.md.

### ADR-012: Rep detection on the Watch

**Status:** Proposed (V0.2)

**Context:** WatchConnectivity is not built for continuous streaming at ~100 Hz. Messages can be delayed, batched or dropped.

**Decision:**
- Detect reps on the Watch and send only `RepEvent`s to the phone during a set.
- Record raw motion to a file on the Watch and transfer it after each set.
- The Watch does the counting. When the phone is reachable, the Watch's count fills the phone's reps box, which has the final say (ADR-015). If the phone is unreachable, the Watch keeps counting and syncs later.

**Consequences:** The phone shows reps within about a second, and complete raw data still reaches the phone for testing and ML. Detection code must run on both platforms (see ADR-005).

### ADR-013: Replay counter

**Status:** Proposed (V0.2)

**Context:** The simulators provide no motion data, and testing at the gym is slow.

**Decision:**
- Regression tests call the detection function directly on recorded samples and check the rep count, with no counter or app involved.
- `ReplayRepCounter` is a thin wrapper that plays a recording through the same detection function and `RepCountingService`, for demos and work in the simulator.

**Consequences:**
- Detection changes that break counting fail a test that runs with `swift test`, without a simulator.
- Sensor and UI work can be done in the simulator.
- The app can be demonstrated without a Watch.

### ADR-014: Signal processing for counting, ML for quality

**Status:** Proposed (V0.3)

**Context:** Collecting labeled motion data is the most expensive part of any ML work.

**Decision:**
- Rep counting uses signal processing: smoothing, peak and valley detection, and a minimum rep duration.
- ML is used for rep quality. Each detected rep is one training sample with about 10–20 engineered features (range of motion, concentric and eccentric timing, velocity, smoothness), classified with small classical models.
- Models are personal: trained on one lifter's own recordings (the developer's), so they learn what that lifter's good and faulty reps look like. Training on several lifters may come later.
- Faults (half reps, fast lowering, bouncing) are recorded on purpose and labeled one set at a time.
- Dynamic time warping against a lifter's own good reps gives feedback without any training.

**Risks:**

| Risk | Mitigation |
|---|---|
| Model only fits one lifter | Accepted while models are personal; revisit if other lifters are added |
| Model memorizes one session instead of learning the lifter | Test on sessions from days not in the training set |
| Python and Swift feature code diverge | Run the same recording through both and compare outputs |
| Velocity drift from integrating acceleration | Reset velocity to zero at the top and bottom of each rep |
| Sensor placement varies | Prefer features that do not depend on orientation |

**Limitations:** A single wrist sensor cannot assess full-body form, such as knee position.

### ADR-015: The phone owns workout history

**Status:** Proposed (V0.2)

**Context:** The Watch counts reps (ADR-012), but the phone keeps the history and runs the set flow (ADR-011). Without rules for who stores and drives what, a set could be lost, saved twice, edited on both devices, or skip the normal set flow.

**Decision:**
- The phone owns the workout history. The Watch stores only sets it hasn't delivered yet.
- When the phone is reachable, every set runs through the phone's ViewModel, Watch sets included. The phone tells the Watch which exercise is current; Start and Finish pressed on the Watch are forwarded to `beginSet` and `finishSet`. The count is checked in the phone's reps box and saved by `completeSet`, like any other set.
- When the phone is unreachable, the Watch runs the set itself and keeps the finished set, with its UUID, until the phone confirms it. The phone confirms a set only after it has been saved successfully: never while saving is off after a failed load, and not after a failed save. Unconfirmed sets stay on the Watch and are sent again. Offline sets are added to history as they arrive, without the correction step, and can be deleted afterwards like any set. They are added through a separate path that never changes the phone's set in progress (`setPhase`, `weightText`, `repsText`).
- An offline set carries its UUID, the workout ID, the `LoggedExercise` ID, reps and `completedAt`. If the exercise was added on the Watch, the Watch creates the `LoggedExercise` ID when the exercise is added and also sends its `ExerciseType`; the phone adds that exercise to the workout only if its ID isn't there yet. The phone fills in the weight: the previous set of that exercise in the workout, as in ADR-011's pre-fill; otherwise the most recent weight for that `ExerciseType` in history; otherwise 0. Sets that arrive together are added in `completedAt` order, so each one sees the sets before it.
- Offline sets pass the same validation as `completeSet`: reps 1 or more, weight 0 or more.
- An offline set that fails validation, or whose workout no longer exists on the phone, is dropped and logged, and its ID is still recorded so resends are ignored. The Watch can't start a workout while the phone is unreachable, so a missing workout always means one the user deleted.
- The phone keeps the IDs of every offline set it has received, and ignores any incoming set whose UUID is already in history or in that list. Resending is always safe and a deleted set never comes back.
- A set that is ignored as a duplicate or dropped is still confirmed, once the history and received IDs are saved, so the Watch stops resending it.
- If the Watch disconnects mid-set: `beginSet` creates the set's UUID and sends it to the Watch. If the Watch finishes that set offline, it keeps that UUID. When the phone receives a set whose UUID matches its own set in progress, it cancels its copy and adds the Watch's. This means `LoggedSet` IDs are created in `beginSet`, not `completeSet`.
- Only one device drives a given set.

**Alternatives:**
- The Watch always delivers finished sets: one save path, but correcting a count means editing a set that is already saved, and Watch sets skip the `RepCountingService` correction flow.
- The phone drives every set from its own buttons and the Watch only counts: simplest, but the phone must be in hand for each set, which undercuts ADR-001.
- Both devices keep full copies and merge: most flexible offline, but needs conflict rules, which is a sync engine.

**Consequences:** Watch sets made with the phone reachable use the same path as manual sets, so the core requirement holds for the main source. Offline sets are the one path that skips `completeSet`. `WorkoutStorage` changes: load and save carry the workouts and the received offline set IDs as one value, saved atomically together in the workouts file (ADR-008), so the two can never disagree. The Watch app can't show history beyond the current workout.

### ADR-016: Rep counter chosen per set

**Status:** Proposed (V0.2)

**Context:** The ViewModel takes one counter at launch, but a set may need the Watch or manual counting depending on the exercise and whether the Watch is reachable (ADR-009).

**Decision:** The ViewModel is given a function that returns the counter for a set, called in `beginSet` with the exercise. The composition root supplies the function: the Watch counter when it is reachable and the exercise can be counted from the wrist, otherwise `ManualRepCounter`. The ViewModel still sees only `RepCountingService`. This covers every set run on the phone, including Watch sets started from the Watch (ADR-015); offline Watch sets don't go through `beginSet`.

**Alternatives:**
- The ViewModel holds a Watch and a manual counter and picks: simple, but the ViewModel learns about concrete sources.
- A per-exercise "Count with Watch" setting: clear to the user, but no automatic fallback when the Watch disconnects. Can be added on top later.

**Consequences:** Fallback rules live in one place and can be tested without a Watch. A set keeps the counter it started with until it is completed or cancelled.

### ADR-017: Binary recording files with a JSON header

**Status:** Proposed (V0.2)

**Context:** Raw recordings become test fixtures and ML data, so changing their format later means converting all of them. The Watch writes about 100 samples a second and transfers each file after the set.

**Decision:**
- One file per recording, one recording per set. The file starts with the header's length as an unsigned 32-bit little-endian integer, then the JSON header, then the samples.
- The header holds the format version, the ID of the set the recording belongs to, the nominal sample rate, and the axis order and units.
- Each sample is a row of little-endian Float32 values: a timestamp in seconds since the recording started, then one value per axis. CoreMotion samples are slightly irregular and sometimes dropped, so real timing is kept per sample rather than derived from the sample rate. Float32 timestamps stay precise to under a millisecond for recordings up to an hour.
- Values are converted to SI units when written (ADR-006): CoreMotion's acceleration in g is multiplied by 9.80665 to give m/s²; rotation rates are already in rad/s.
- A CSV export is added for prototyping in Python.

**Alternatives:**
- CSV everywhere: readable and easy in Python, but about 3–4× larger and slower to write on the Watch.
- Header in a separate file: easier to read by eye, but two files per set to transfer and keep together.
- Sample rate only, no timestamps: smaller, but loses real timing that can't be recovered later.
- Int16 samples: half the size, but each axis needs a scale factor and loses precision. Can be added later as a new format version if size becomes a problem.

**Consequences:** Readers check the format version, like the workouts file (ADR-008). Reading and writing recordings is pure code in `WorkoutCore`, tested with `swift test`.
