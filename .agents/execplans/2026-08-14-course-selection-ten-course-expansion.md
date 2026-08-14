---
type: plan
status: active
created: 2026-08-14
scope: Responsive course selection backed by prepared artifacts and a ten-course connected-terrain catalog
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-13-terrain-device-evolution.md
  - project-specs/cannon-golf/assets/course-select-double-state-evidence.png
  - project-specs/cannon-golf/assets/terrain-progression-early.png
  - project-specs/cannon-golf/assets/terrain-progression-mid.png
  - project-specs/cannon-golf/assets/terrain-progression-late.png
---

# Responsive Ten-Course Catalog - Execution Contract

Deliver ten selectable connected-mountain courses without blocking the selection
frame. The app loads an identity-checked prepared course artifact asynchronously,
uses it for both preview and gameplay, and presents one unambiguous selected card.
The catalog progresses through `1, 1, 2, 2, 3, 3, 4, 4, 5, 6` ordered goals;
goal order does not imply continuously increasing elevation.

## Purpose

- Objective: remove the apparent double selection and multi-second selection
  stall, then ship the approved first batch of ten varied terrain/goal courses.
- Deliverable: prepared-course schema and bake command, asynchronous three-entry
  repository, ready/loading/error selection states, ten course resources, generic
  ordered-leg terrain generation, tests, and rendered evidence.
- Completion state: every task and final gate below passes, the active plan is
  marked `done`, and the scoped implementation is committed.

## Scope and Boundaries

In scope:

- One selection truth, distinct focus styling, immediate selection feedback,
  latest-request-wins loading, Start readiness, and ten-card scrolling.
- One immutable prepared artifact per catalog course containing identity,
  canonical render mesh, collision shapes, sampled surface data, generated leg
  data, bounds, dressing placements, and validation metrics.
- A repository-owned offline bake command and a runtime loader with an LRU of
  three prepared courses.
- Generic one-to-six ordered goals, route-index/placement/elevation-band inputs,
  non-monotonic rim sequences, connected semantic landforms, and checkpoint
  launchers centered on the previous confirmed goal.
- Ten playable terrain/goal courses. Courses 5-10 include usable broad placement
  surfaces but do not require an unapproved device.

Out of scope:

- Final bounce-pad response, editing rules, inventory, placement legality, or
  pad-dependent solution certification.
- Damping, airflow, gravity zones, caves, bridges, overhangs, disconnected
  islands, a custom Godot editor plugin, public-title changes, and save migration.
- Reworking retained Paint Mountain stages or generated-stage catalogs.

Constraints and invariants:

- `selected_course_index` owns selection; keyboard focus is not selection.
- A selection callback performs no terrain generation or geometry build and
  returns within `16,667 us` in the target 60 Hz contract test.
- Start is disabled until the latest requested course artifact passes identity
  and payload validation. Obsolete completions cannot change preview or gameplay.
- Production selection has no synchronous procedural-generation fallback.
- Preview and gameplay consume the same prepared artifact identity and geometry.
- Confirmed goals persist; each later launcher is centered horizontally on the
  previous goal and aligned to its prepared surface.
- Goal order is checkpoint order. Elevation bands may rise, fall, or alternate.
- Default setup remains `50 / 50 / 50` and must not equal a certified solution.
- Terrain remains one connected heightfield-like body and preserves the current
  pale faceted mountain, sky, ground, cyan marker, and restrained UI direction.
- Headless tests, bakes, tuners, and capture runs must not write persistent
  Godot logs under `user://logs`. Diagnostic output is bounded and retained only
  when it proves a failure.
- Only one heavyweight Cannon Golf authoring or physics process may run at a
  time. Every such process has a wall-clock deadline independent of Godot's
  frame-based `--quit-after` limit.
- The validation wrapper stops on the first `SCRIPT ERROR`/`ERROR`, an output
  cap breach, a wall-clock deadline, or an unexpected child-process exit. It
  must terminate its exact owned process tree and leave no orphan Godot process.

Destructive or irreversible actions:

- None. Prepared resources are reproducible outputs of the repository bake
  command and can be regenerated from authored course inputs.

Exact actions requiring owner or user approval:

- None inside this contract. The user's approval of the research plan locks the
  prepared-artifact architecture and treats these ten courses as the first batch
  inside the accepted longer progression. Device rules remain outside scope.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Double-looking selection | `cannon_golf_course_select.gd` keeps the default focus outline while another toggle gets the pressed fill | Rendered evidence asset and shared theme styles | ButtonGroup remains exclusive; selected card receives focus; focus style is visually neutral and distinct | 1.1, 1.2 |
| Five-second stall | selection signal calls preview, builder, terrain synthesis, geometry and dressing synchronously | traced call path; no five-second timer; cold captures are relatively slower on cache misses | selection only requests a prepared artifact; runtime generation is forbidden on this path | 1.3, 2.1, 2.2 |
| Existing reusable delivery pattern | retained `StageLayoutRepository` already implements threaded load, latest request, identity checks and LRU 3 | `src/app/stage_layout_repository.gd` | implement a Cannon Golf-owned equivalent around its smaller domain contract | 2.1 |
| Preview/game parity | current factory cache shares generated geometry but still requires first-use generation | builder/performance tests | prepared artifact is the shared source for both consumers | 2.2, 2.3 |
| Multi-goal specialization | course schema and explicit factory assume route 0, decreasing route positions, two-leg nearest selection and at least 25 m rise per leg | course data, leg data, factory and hard-coded tests | support 1-6 legs, route/placement/elevation-band inputs, N-leg admission, and non-monotonic height | 3.1, 3.2 |
| Natural terrain variety | synthesizer supplies noise/ridges/basins but lacks authored semantic feature placement | profile, synthesizer and approved concept images | add bounded peak, ridge, saddle, plateau/shelf, valley, basin/cirque and terrace recipe features with measurable acceptance | 3.1, 3.2 |
| Course count and devices | accepted progression remains longer while the approved plan defines a ten-course first batch; pad rules remain open | D-014, Q-07-Q-09/Q-14, approved research plan | catalog exposes ten now; courses 5-10 reserve surfaces but remain device-free | 4.1, 4.2 |
| Validation command | Godot 4.7.1 console binary and `scripts/test-cannon-golf.ps1` are present; direct script invocation passed baseline course test | `Godot_v4.7.1-stable_win64_console.exe --version`; baseline test output | use targeted scripts during tasks, focused suite once at final, plus one background rendered/interaction pass | all |
| Storage incident | Three concurrent `deep_relay` bake attempts left six owned Godot processes running; a skirt assertion repeated into five `user://logs` files totaling 39,820,895,712 bytes and exhausted C: | exact process command lines, five-file manifest, repeated `_step_skirts` backtrace, and 2026-08-14 free-space measurement | disable persistent file logging for this project, replace raw direct checks with a bounded fail-fast wrapper, serialize heavyweight runs, and require pre/post storage/process gates | 0.1-0.3, all validation |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety,
  and validation decision is closed for this scope.
- Godot 4.7.1 and repository test/capture scripts are available; no dependency
  installation is required.
- Remaining unknowns are implementation-local tuning of authored resource values
  and cannot expand the locked behavior or architecture.

## Tasks

### Phase 0: Storage-safe validation containment

Goal: no test, bake, tuner, or capture can silently consume unbounded disk or
continue emitting the same failure after its result is already known.

Incident baseline:

- On 2026-08-14, three duplicate `deep_relay` bake commands remained active
  concurrently as six Godot console/engine processes.
- `TerrainGeometryBuildJob._step_skirts` emitted the same failed assertion into
  five Godot log files totaling 39,820,895,712 logical bytes (37.086 GiB).
- The five approved log contents were cleared after their exact paths, owner
  processes, exclusive access and size were verified. C: free space recovered
  from 0 GiB to 37.086 GiB; the five zero-byte file shells are harmless.

Preconditions:

- No Cannon Golf Godot process is running.
- The storage incident manifest remains outside the repository at
  `D:\disk-inspection\2026-08-14-114444-wiztree-cannon-golf`.

Source owners: `project.godot`, new bounded validation wrapper under `scripts/`,
`scripts/test-cannon-golf.ps1`, `scripts/bake_cannon_golf_courses.gd`,
`scripts/tune_cannon_golf_solutions.gd`,
`src/terrain/terrain_geometry_build_job.gd`, and focused wrapper/failure tests

- [ ] **0.1** Disable unbounded persistent diagnostics.
  - Change: disable project file logging; route headless output through one
    repository wrapper that retains only a bounded tail, caps captured output at
    4 MiB, and keeps no success log.
  - Accept: a deliberately failing fixture exits nonzero after the first error,
    produces at most the bounded diagnostic tail, and leaves `user://logs` at a
    zero-byte delta.
- [ ] **0.2** Make geometry generation fail closed once.
  - Change: replace the repeated skirt-loop assertion with one structured job
    failure that stops geometry construction; propagate null/failure through the
    factory and bake command without retrying the same invalid input.
  - Accept: an invalid skirt fixture reports one failure, creates no artifact,
    and exits without further geometry steps; valid course bakes remain valid.
- [ ] **0.3** Serialize and supervise heavyweight Godot runs.
  - Change: give the wrapper a cross-process single-run guard, an exact owned
    process-tree cleanup path, per-command wall-clock deadlines, a 10 GiB C:
    free-space preflight floor, and post-run checks for orphan Godot processes
    and `user://logs` growth above 1 MiB.
  - Accept: a second simultaneous heavy run is refused, a timeout fixture has
    its exact child tree stopped, and pre/post probes show no persistent process
    or material log growth.

Batch gate:

- Run only the bounded wrapper's failure, timeout, concurrency and valid-smoke
  fixtures. Do not resume course tuning or the broad suite until all four pass.

### Phase 1: Immediate and unambiguous selection

Goal: a course click changes one selected state immediately, keeps focus aligned,
and exposes loading/ready/failure truth without blocking.

Preconditions:

- Current course-select scene, theme variation, app signal path and UI tests are
  unchanged from discovery.

Source owners: `src/cannon_golf/app/cannon_golf_course_select.gd`,
`scenes/cannon_golf/app/cannon_golf_course_select.tscn`,
`resources/ui/paint_mountain_theme.tres`, `tests/cannon_golf_ui_contract_test.gd`

- [ ] **1.1** Exactly one course card reads as selected.
  - Change: make ButtonGroup the only toggle owner, align focus after mouse,
    keyboard and programmatic selection, and add a distinct course-card focus
    style.
  - Accept: the UI contract asserts one pressed card, matching focus owner and
    a different focus/pressed style after selecting non-default cards.
- [ ] **1.2** Ten cards remain usable without clipping.
  - Change: put the reusable course-card list in a keyboard/mouse-wheel scroll
    owner and keep Back/Start fixed inside the 1280x720 frame.
  - Accept: the UI contract finds ten targets of at least 44 px, valid focus
    order, a scrolling list and no viewport overflow at supported desktop sizes.
- [ ] **1.3** Loading, ready and failure states are truthful.
  - Change: add `set_course_preparation_state`; disable Start and use localized
    `준비 중…`/`PREPARING…` while pending, enable only on ready, and expose one
    concise disabled failure label while a same-card selection can retry.
  - Accept: a targeted selection-state test reaches all states and never emits
    `start_requested` while not ready.

Batch gate:

- Run `cannon_golf_ui_contract_test.gd` and the new selection-state test once.

### Phase 2: Prepared artifact delivery

Goal: selection and gameplay reuse one identity-checked artifact without runtime
terrain generation.

Preconditions:

- Phase 1 state API passes its targeted checks.

Source owners: `src/cannon_golf/course_catalog.gd`, new prepared-course resources
and codec/repository, `src/cannon_golf/course_builder.gd`,
`src/cannon_golf/app/cannon_golf_preview_world.gd`,
`src/cannon_golf/app/cannon_golf_app.gd`, `src/cannon_golf/cannon_golf_game.gd`,
new `scripts/bake_cannon_golf_courses.gd`

- [ ] **2.1** Prepared resources are reproducible and fail closed.
  - Change: add a schema-versioned prepared-course/leg payload and codec; save
    mesh, collision, sampled surface, generated legs, bounds, dressing and
    validation metrics; verify course identity and payload SHA-256 on load.
  - Accept: codec round-trip and malformed/stale resource tests pass; the bake
    command produces ten resources and a second bake leaves the same semantic
    payload hashes.
- [ ] **2.2** Selection loads latest artifact asynchronously with LRU 3.
  - Change: adapt the retained repository pattern using
    `ResourceLoader.load_threaded_request`, latest-request-wins publication,
    identity checks, explicit failure and an LRU of three.
  - Accept: repository tests cover cached, selected, obsolete, failed and
    eviction paths; selection callback timing stays below `16,667 us` and does
    not increment terrain generation count.
- [ ] **2.3** Preview and gameplay share the prepared artifact.
  - Change: builder consumes a prepared course; preview prepares a replacement
    builder before atomic swap; App gates Start and injects the ready artifact
    into the game before it enters the tree; direct gameplay loads the same
    baked resource rather than generating.
  - Accept: app-flow/performance tests prove preview/gameplay identity and mesh
    parity, stale preview protection, ready-only start and no selection-path
    factory build.

Batch gate:

- Run codec/repository, `cannon_golf_course_build_test.gd`,
  `cannon_golf_performance_test.gd`, and `cannon_golf_app_flow_test.gd` once.

### Phase 3: Generic ordered legs and semantic landforms

Goal: authored data can express one-to-six ordered goals with non-monotonic
elevation on recognizably structured connected terrain.

Preconditions:

- Prepared artifact schema can serialize arbitrary leg counts and metrics.

Source owners: `src/cannon_golf/course_data.gd`,
`src/cannon_golf/course_leg_data.gd`, new landform recipe/feature resources,
`src/cannon_golf/course_terrain_factory.gd`, generated course owners, terrain,
range, relay, camera and course tests

- [ ] **3.1** Ordered-leg data is generic and explicit.
  - Change: add route index, goal placement offset/region and relative rim band;
    remove upward-only and two-leg assumptions; make nearest-leg admission work
    for N legs while retaining centered checkpoint launchers and full corridor
    guards.
  - Accept: data/factory tests cover counts 1-6, repeated rise/fall sequences,
    non-overlap, finite data, exact launcher centering and fail-closed malformed
    inputs.
- [ ] **3.2** Named landforms have authored, measurable shape.
  - Change: apply bounded semantic feature recipes before goal carving and store
    per-feature metrics for peaks/ridges/saddles/plateaus/valleys/basins/
    terraces; reject a feature that misses its metric.
  - Accept: terrain tests prove required feature kinds and their height/flatness
    measures, at least 80 m late-course relief, connected topology and goal
    recess/lip containment.
- [ ] **3.3** Runtime checkpoint behavior supports every leg count.
  - Change: replace two-leg-specific builder/game/test branches with N-leg
    iteration while keeping confirmed balls, impact history, retry state, compact
    goal tally and final-only clear.
  - Accept: relay/session tests complete synthetic 1-, 3- and 6-leg transitions,
    prove future goals cannot confirm and retain all confirmed checkpoint balls.

Batch gate:

- Run course, terrain, range, build, camera, goal, relay and session tests once.

### Phase 4: Author and bake the ten-course batch

Goal: the catalog exposes ten distinct connected courses matching the approved
goal/elevation/terrain matrix.

Preconditions:

- Phase 3 generation and Phase 2 bake path pass.

Source owners: `resources/cannon_golf/courses/`,
`resources/cannon_golf/prepared/`, `src/cannon_golf/course_catalog.gd`,
course/solution/camera/range tests

- [ ] **4.1** Ten authored course inputs match the progression.
  - Change: preserve First Ridge and Rising Bend, retain and reposition Deep
    Relay in the two-goal tier, and add resources so counts are
    `1,1,2,2,3,3,4,4,5,6`; use rim sequences `L`, `H`, `H→L`, `L→H`,
    `H→L→M`, `L→H→L`, `H→L→H→M`, `L→M→L→H`,
    `H→L→M→H→L`, and `L→H→M→H→L→H`.
  - Accept: catalog tests assert exact order, unique IDs, goal counts, rim-band
    sequences, valid default/solution metadata and distinct terrain recipes.
- [ ] **4.2** Terrain families visibly and physically match their role.
  - Change: author compact ridge, summit/saddle, descending shelves, linked
    bowls, terraced peak, U-valley/cirque, twin peaks, basin garden, three
    ridges and alpine complex recipes; include broad low-variance surfaces in
    courses 5-10 without preinstalling devices.
  - Accept: baked artifacts pass identity, feature, bounds, camera, union range
    and placement-surface metrics; the catalog has no `Mechanisms` node.
- [ ] **4.3** Every course has a real-physics completion witness.
  - Change: tune each authored leg solution while keeping `50/50/50` as a miss.
  - Accept: `cannon_golf_solution_test.gd` replays all legs sequentially and
    clears all ten; default setup does not advance any tested leg.

Batch gate:

- Run the bake command once after tuning, then course, range and solution tests.

### Phase 5: Rendered flow and production-path evidence

Goal: real pixels and interaction confirm the fixed selection flow and terrain
variety without desktop residue.

Preconditions:

- Phases 1-4 and their targeted checks pass.

Source owners: capture harness, app scenes, fastrun canonical project entry

- [ ] **5.1** Course selection renders each reachable state correctly.
  - Change: extend the background capture harness for default, non-default
    selected, preparing, ready, failure and scrolled-late-course states.
  - Accept: inspected 1280x720 captures show one selected card, distinct focus,
    no overlap/clipping, fixed actions and truthful Start state.
- [ ] **5.2** Representative terrain reads as designed.
  - Change: capture early, middle and late prepared courses from the real runtime.
  - Accept: inspected frames show connected faceted terrain and the authored
    peak/shelf/saddle, valley/cirque and alpine-complex families with correct
    goal counts/elevation variation.
- [ ] **5.3** Canonical app launch and native interaction remain responsive.
  - Change: use the registered fastrun project entry; click multiple course cards,
    scroll to course ten, start the latest ready course and return once.
  - Accept: the selected state paints immediately, animation/input continues
    during preparation, only the latest preview appears, and gameplay uses that
    course. Stop the task-owned process after evidence capture.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | bounded wrapper for `res://tests/<target>.gd`, one process, 180 s wall-clock cap, 4 MiB output cap, no persistent Godot log | After the target's implementation changes | Its owned input changes |
| Authoring bake | bounded wrapper for one course, 180 s wall-clock cap, never in parallel | After that course input or generator changes | That course or generator input changes |
| Physics tuner | bounded wrapper for one course, one process, 10 min wall-clock cap, no automatic retry | After an authored surface or witness hypothesis changes | A new hypothesis or owned input changes |
| Phase gate | The exact targeted scripts listed under that phase | All task-local checks in the phase pass | A phase-owned input changes |
| Final gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1` | All phases and rendered checks pass | A final-gate input changes |
| Text hygiene | `git diff --check` | Before each scoped commit | A touched text file changes |

Validation rules:

- Direct raw Godot invocations are forbidden for headless tests, bakes, tuners
  and captures after Phase 0. Use the bounded wrapper even for a single check.
- Check C: free space, the Cannon Golf `user://logs` byte total and owned Godot
  processes before and after every heavyweight run. Stop the task if free space
  falls below 10 GiB, logs grow by more than 1 MiB, or an owned process remains.
- Never run duplicate course bakes or tuners concurrently. Parallel agent work
  must partition source inspection or lightweight tests, not Godot generation.
- Preserve only the last 200 diagnostic lines for a failed check. Do not retain
  complete repeated stdout/stderr streams or successful run logs.
- Run the narrowest check that proves the current task.
- Run each phase gate once after its tasks pass.
- Run the focused suite once at the end because catalog-wide parser, runtime and
  solution compatibility is not fully covered by any one task.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain any required approval before resuming | Do not select a different product, dependency, topology or device contract silently |
| A semantic feature cannot pass its measure without breaking admission | Reduce that feature's bounded authored amplitude or move its anchor, preserving the named family and rim sequence | Do not weaken finite, connected, range, corridor, goal or camera gates |
| A prepared artifact fails identity/payload validation | Keep Start disabled, publish local failure and regenerate from authored inputs | Never fall back to runtime generation |
| A solution is numerically fragile | Retune the authored feature/goal/witness for a wider settlement route | Do not copy the solution into default setup or weaken settlement rules |
| Full all-course solution replay exceeds the practical final budget | Keep targeted leg physics witnesses for every new course and record exact unfinished exhaustive evidence | Do not claim full completion or mark the plan done until the named gate runs or the contract is revised with user approval |
| A check emits its first script/runtime error | Stop its exact owned process tree immediately, keep only the bounded tail, fix the cause, then rerun once | Never allow an already-known failure to continue for more evidence |
| A Godot run reaches its wall-clock or output cap | Stop the exact owned process tree, classify it as a failed check, and revise the implementation or hypothesis | Never increase the cap merely to let an unchanged failure continue |
| C: free space is below 10 GiB, `user://logs` grows over 1 MiB, or an owned Godot process remains | Stop all further Godot validation, report the incident, and reclaim only explicitly authorized task-owned output | Do not start another check until preflight is healthy |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Anti-Rework Execution Rules

- On start or resume, read this contract and inspect the worktree only enough to
  confirm checkpoint inputs, then continue from the first satisfiable unchecked
  task.
- Treat checked tasks and recorded passing evidence as complete unless a relevant
  input changed, evidence is missing, or the final gate is scheduled.
- Run each check at its declared cadence; do not repeat a passing check merely to
  regain confidence.
- Mark a task complete only after its acceptance check passes, and update this
  file's checkbox and progress pointer together.
- If reality contradicts a material decision, stop that branch and revise this
  contract. Resolve implementation-local mechanics without reopening planning.

## Progress and Next Steps

- Canonical progress: task checkboxes in this contract.
- Current phase: Phase 0 incident containment. Previously implemented course
  work is preserved but no further Godot generation runs before this gate.
- Next task: 0.1, disable persistent logs and add the bounded fail-fast wrapper.
- Last completed gate: Discovery Closure Gate; baseline
  `cannon_golf_course_test.gd` passed on Godot 4.7.1 for the original three
  courses.
- Update rule: after each checkpoint passes, record concise evidence, check the
  task and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check, guard, phase gate and final gate passes.
- The final validation leaves at least 10 GiB free on C:, zero owned Godot
  processes, and no material `user://logs` growth.
- The ten catalog artifacts are reproducible and the real app renders and starts
  the selected latest ready course without a selection-frame stall.
- The plan has no unresolved placeholder and its frontmatter status is `done`.
- Durable accepted behavior is recorded in `DECISIONS.md`, resolved questions are
  moved out of the open table, and task-owned changes are committed.

Replan when:

- A material discovery invalidates the prepared-artifact, connected-terrain,
  ordered-goal or ten-course batch contract.

Do not replan or stop for:

- Local schema encoding, resource syntax, tuning values, capture parameters or a
  passing check whose relevant inputs did not change.
