---
type: plan
status: active
created: 2026-08-12
scope: Two-course playable Cannon Golf vertical slice
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
---

# Two-Course Cannon Golf Vertical Slice - Execution Contract

Deliver a Windows-playable Godot 4 vertical slice that replaces the inherited
Paint Mountain main path with two manually authored direct-shot courses. The
slice must prove the launch-correct-retry loop, safe goal settlement, persistent
first-impact history, and stable planning cameras without implementing devices
or a level editor.

## Purpose

- Objective: turn the accepted Cannon Golf rules into a small complete game
  loop with two introductory maps.
- Deliverable: a new main scene, isolated Cannon Golf runtime modules, two
  authored course resources, focused automated tests, a verified Windows build,
  and rendered evidence.
- Completion state: either course can be selected and cleared through physical
  angle-and-power shots; failed launches recover without a limit; every final
  gate below passes.

## Scope and Boundaries

In scope:

- Two one-goal courses with direct solutions and terrain that changes height
  and lateral shape.
- Elevation and power controls, physical launch, predictable energy-losing
  rebound, first-contact marks, safe-settlement validation, and unlimited retry.
- High-oblique and side planning views, keyboard/mouse course exploration,
  temporary shot follow, and stable return to the previous planning state.
- Korean-first edge HUD, goal progress, failure feedback, course switching,
  stage reset, and next/replay completion actions.
- Dedicated Cannon Golf tests, project identity, export path, README, and
  product-decision updates needed to describe the implemented slice.

Out of scope:

- Bounce, damping, airflow, or gravity placement; multi-goal stages; a custom
  Godot editor plugin; procedural course generation; save migration; score,
  timer, lives, finite shots, trajectory prediction, and public-title approval.
- Deleting the inherited Paint Mountain runtime or rewriting its legacy tests.

Constraints and invariants:

- The new main path must not call coverage, paint, exact-prediction, generated
  mountain, finite-shot, or fixed-mechanism owners.
- A launch may create one first-contact mark. The five most recent marks remain,
  ordered visually by recency.
- A goal confirms only after the ball stays inside its physical boundary below
  the settlement speed thresholds for the configured duration. Leaving before
  confirmation fails only that launch.
- A confirmed ball freezes visibly in the goal. A failed ball is removed before
  Fire becomes available again.
- View and exploration state must not mutate launch setup or goal state.
- Add no external dependency.

Destructive or irreversible actions:

- None. Legacy files remain available, and the new runtime is isolated under
  `src/cannon_golf/`, `scenes/cannon_golf/`, and `resources/cannon_golf/`.

Exact actions requiring owner or user approval:

- Deleting the legacy Paint Mountain runtime, adding a production dependency,
  or choosing a public title. None is required by this contract.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Main application path | `project.godot` starts `scenes/app/app.tscn`; `src/app/app_root.gd` prepares generated Paint Mountain stages | Direct file inspection and Godot 4.7.1 editor parse | Point the project to one isolated Cannon Golf scene; preserve legacy scenes as source history | 1.1, 4.1 |
| Launch geometry | `scenes/gameplay/cannon.tscn` and `src/cannon/cannon_controller.gd` couple visuals to `ProjectileData` and prediction state | Direct scene and script inspection | Adapt the visual proportions into a new launcher with only elevation, power, origin, and velocity responsibilities | 2.2 |
| Ball lifecycle | `PaintProjectile` and `ProjectileManager` own paint intervals, target-top identity, shot families, and finite admission | Direct script inspection | Build a small golf-ball body that emits only first surface contact; the game session owns launch outcomes | 2.3, 3.1 |
| Completion | `StageController` completes from coverage and shot limits | PRD conflict plus direct script inspection | A settlement goal owns its physical boundary; the session owns enter/leave, settle time, persistence, and course clear | 2.4, 3.1 |
| Terrain and stage data | Generated heightfield catalogs encode coverage targets and fixed mechanisms | `StageData`, generator, catalog, and research notes | Use two human-authored `Resource` definitions made from connected faceted blocks; keep the format editor-readable | 2.1, 2.5 |
| Camera and HUD | Inherited runtime is frontal/prediction/coverage oriented | `DESIGN_RULES.md`, scenes, and scripts | Default high-oblique; side view on demand; arrow-key pan and wheel zoom; temporary follow restores stored planning pose; no exact predictor | 3.2, 3.3 |
| Product decisions | Q-01 through Q-04 and Q-12 were open before implementation authority | User delegated the two-map game implementation on 2026-08-12 | Fixed course yaw, elevation/power input, five order-faded marks, high-oblique default, side alternate, terraced shelf terrain | 1.1 |
| Toolchain | Shared Godot 4.7.1 console executable exists and imports/parses the project after asset import | `D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe --version`, import, editor quit | Use the shared pinned executable for tests, capture, export, and built-app smoke | 1.2, 4.1, 4.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety,
  and validation decision for this two-course slice is closed.
- Godot 4.7.1 and all repository assets required by the slice are available.
  The first editor attempt observed transient missing imported-resource errors;
  a complete import followed by a clean editor parse resolved them.
- Remaining unknowns are local physics tuning and layout mechanics that cannot
  change scope or ownership.

## Tasks

### Phase 1: Lock the slice and executable shell

Goal: record the delegated decisions and establish a parseable Cannon Golf main
path before gameplay modules are added.

Preconditions:

- Canonical product and UI specifications have been read.
- Godot 4.7.1 import and editor commands reach this project successfully.

Source owners: `project-specs/cannon-golf/DECISIONS.md`,
`project-specs/cannon-golf/OPEN_QUESTIONS.md`, `project.godot`,
`scenes/cannon_golf/cannon_golf.tscn`

- [ ] **1.1** Product decisions and the isolated runtime entry point agree.
  - Change: resolve Q-01 through Q-04 and Q-12 for this slice, add the new main
    scene, and identify the window/export as a prototype rather than a public
    title.
  - Accept: Godot editor parse exits zero with no `ERROR:` or `SCRIPT ERROR`.
- [ ] **1.2** The two-course contract is machine-checkable.
  - Change: add a focused PowerShell test runner and a course-data test that
    verifies catalog size, identifiers, bounds, direct-solution witnesses, and
    absence of device stock.
  - Accept: `scripts/test-cannon-golf.ps1` reaches and passes the course test
    with the shared Godot executable.

### Phase 2: Build the physical course slice

Goal: produce two data-authored worlds with a launcher, rebound-capable ball,
physical settlement goal, and first-contact event.

Preconditions:

- Phase 1 acceptance checks pass.

Source owners: `src/cannon_golf/course_data.gd`,
`src/cannon_golf/course_catalog.gd`, `src/cannon_golf/course_builder.gd`,
`src/cannon_golf/cannon_golf_launcher.gd`, `src/cannon_golf/golf_ball.gd`,
`src/cannon_golf/settlement_goal.gd`, `resources/cannon_golf/courses/`

- [ ] **2.1** Course data owns only authored geometry and play metadata.
  - Change: define editor-readable blocks, cannon and goal transforms, bounds,
    camera bookmarks, defaults, and direct-solution witnesses for two courses.
  - Accept: the course-data test rejects malformed geometry and accepts exactly
    the two shipped resources.
- [ ] **2.2** The launcher exposes only the chosen launch setup.
  - Change: build a stationary cannon with fixed course yaw and adjustable
    elevation and power; expose deterministic launch origin and velocity.
  - Accept: the ballistics test proves identical setup produces identical origin
    and velocity and that power monotonically increases speed.
- [ ] **2.3** The standard ball rebounds and reports one first contact.
  - Change: build a rigid golf ball with visible restitution, energy loss,
    continuous collision detection, stage bounds, and one first-contact signal.
  - Accept: the runtime physics test observes a rebound, exactly one first
    contact, and lower post-contact vertical speed than incoming speed.
- [ ] **2.4** The goal is a physical, bounded settlement owner.
  - Change: build a recessed-looking landing zone with floor, rim, and explicit
    containment/settlement queries that do not depend on color.
  - Accept: the goal test distinguishes inside, outside, too-fast, and settled
    states using the configured tolerances.
- [ ] **2.5** Both course resources build into valid collision worlds.
  - Change: build faceted connected terrain blocks, subtle world dressing,
    launcher, goal, and collision identities from each resource.
  - Accept: the runtime test instantiates each course and finds one launcher,
    one goal, multiple surface bodies, and no route-changing mechanism.

Batch gate:

- Run `scripts/test-cannon-golf.ps1` once after Tasks 2.1-2.5 pass; it must
  complete all course, ballistics, goal, and physics checks without engine or
  script errors.

### Phase 3: Complete the playable loop and interface

Goal: make both courses playable from launch setup through retry or clear while
preserving a stable planning workspace.

Preconditions:

- Phase 2 batch gate passes.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`,
`scenes/cannon_golf/cannon_golf.tscn`

- [ ] **3.1** The launch state machine enforces the accepted outcomes.
  - Change: admit one active ball, retain five ordered first-contact marks,
    fail on goal escape/rest/bounds/timeout, remove failed balls before retry,
    and freeze a confirmed ball after safe settlement.
  - Accept: the session test proves Fire admission, miss recovery, mark cap and
    ordering, goal confirmation, immutable confirmed ball, and unlimited retry.
- [ ] **3.2** Planning and follow cameras preserve setup and context.
  - Change: implement high-oblique and side views, arrow pan, wheel zoom,
    temporary shot follow, and return to the stored mode/pan/zoom.
  - Accept: the session test changes view and exploration state around a launch
    and observes unchanged elevation, power, course index, and goal progress.
- [ ] **3.3** The Korean-first HUD exposes only real actions and states.
  - Change: add course identity, goal progress, concise outcome feedback,
    elevation/power controls, view controls, reset, course switch, Fire, and
    clear actions with visible focus and 40px-or-larger routine targets.
  - Accept: rendered 1280x720 captures of planning, side, and clear states have
    no coverage/paint/prediction copy, overlap, clipping, hidden goal, or fake
    control; keyboard setup, view, reset, and Fire paths work.

Batch gate:

- Capture and inspect one planning view, one side view, and one clear state from
  the actual scene at 1280x720. Fix UIUX blockers before proceeding.

### Phase 4: Package and hand off the prototype

Goal: verify source startup and the Windows artifact, then make the new runtime
truthful to future maintainers.

Preconditions:

- Phase 3 batch gate passes.

Source owners: `scripts/verify.ps1`, `export_presets.cfg`, `README.md`,
`project-specs/cannon-golf/PRD.md`, this contract

- [ ] **4.1** Source and project configuration pass final verification.
  - Change: update verification copy, export identity, README, and implemented
    product notes without presenting unbuilt devices as available.
  - Accept: `scripts/verify.ps1` and `scripts/test-cannon-golf.ps1` both pass
    with the shared Godot executable; `git diff --check` is clean.
- [ ] **4.2** The Windows prototype exports and starts.
  - Change: export the `Windows Desktop` release preset to
    `builds/windows/CannonGolfPrototype.exe`.
  - Accept: Godot export exits zero and the exported executable completes a
    headless three-frame smoke run with no engine or script errors.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit` | A scene or script signature changes | A relevant parse input changes |
| Phase gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe` | Phase 2 or 3 tasks pass | Course or gameplay inputs change |
| UI gate | `D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/capture_cannon_golf_frame.gd -- --output=.godot/capture-temp/cannon-golf.png --background` | The playable HUD and cameras are complete | A visible UI/camera input changes |
| Final gate | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe`; focused test runner; release export; built-app smoke; `git diff --check` | All phases pass | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.
- The legacy `scripts/test.ps1` suite asserts retired Paint Mountain behavior
  and is not a release gate for the isolated Cannon Golf main path.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain any required approval before resuming | Do not choose a new product, dependency, or architecture silently |
| A direct-solution witness misses under rigid-body simulation | Tune only witness, goal footprint, ball coefficients, or authored block transforms while preserving the two-course rules | Replan if success would require prediction, device placement, or a different control model |
| Imported inherited UI assets fail again after an explicit import | Replace only the new HUD's dependency with built-in theme resources | Do not fetch a package or modify supply-chain policy |
| Windows release templates are unavailable | Record the exact missing template and complete source, test, capture, and debug-start gates | Do not download or install without approval |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Phase 1.
- Next task: 1.1.
- Last completed gate: Discovery Closure Gate.
- Update rule: after a checkpoint passes, record concise evidence, check the
  task, and advance this pointer in the same edit.
- On start or resume, read this contract and inspect the worktree only enough to
  confirm checkpoint inputs, then continue from the first unchecked task whose
  prerequisites are satisfied.
- Treat checked tasks and recorded passing evidence as complete unless a
  relevant input changed, the evidence is missing, or the contract schedules a
  broader final gate.
- Run each check at its declared cadence. Do not repeat a passing check merely
  to regain confidence.
- Mark a task complete only after its acceptance check passes; run a guard only
  when that task names one.
- Update task checkboxes and this progress pointer together after a checkpoint.
- If reality contradicts a material decision, stop that branch and revise this
  contract before continuing.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named batch/final gate passes.
- Both courses are physically playable and have a verified direct solution.
- Rendered evidence passes the Level 4 UIUX blockers for the supported 1280x720
  desktop baseline and a wider desktop aspect.
- No placeholder or unresolved material decision remains in this contract.
- Durable decisions and run/verify knowledge are recorded in their owning docs.
- Frontmatter status is changed to `done` only after implementation is complete.

Replan when:

- A material discovery invalidates the locked control model, isolated-runtime
  boundary, two-course content scope, or required validation path.

Do not replan or stop for:

- Local GDScript mechanics, numeric physics tuning inside the accepted model,
  or a passing check whose relevant inputs have not changed.
