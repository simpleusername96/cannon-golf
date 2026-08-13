---
type: plan
status: done
created: 2026-08-13
scope: Separate Cannon Golf launch admission from every planning and Shot Follow camera transition
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-13-rapid-fire-shot-camera-performance.md
---

# Fire and Camera Independence - Execution Contract

Firing will create one admitted ball without changing the current camera mode,
planning pose, or existing follow target. Shot Follow remains available only
through its explicit HUD action, while quick retry preserves an already selected
follow context when it replaces that followed ball.

## Purpose

- Objective: remove the automatic camera transition from Fire so launch and
  camera control are independent player actions.
- Deliverable: corrected gameplay ownership, physical-input and multi-ball
  regression coverage, capture evidence, current product records, player-facing
  controls documentation, and a refreshed Windows build.
- Completion state: Fire in planning retains the exact explored pose; Fire while
  following an earlier ball retains that mode and target; explicit follow still
  works; all named final gates pass.

## Scope and Boundaries

In scope:

- `CannonGolfGame.fire`, quick retry's followed-target replacement case,
  Cannon Golf input/session tests, capture tooling, current camera behavior
  records, and README control language.

Out of scope:

- Camera geometry, follow interpolation, HUD layout, launch physics, live-ball
  capacity, course content, or a new shortcut.

Constraints and invariants:

- Ordinary Fire changes only launch/session state. It does not call follow,
  return to planning, reset, orbit, pan, zoom, view selection, or HUD camera-mode
  mutation.
- Planning Fire preserves view, focus, pan, orbit, zoom, and the resulting camera
  transform.
- Fire during explicit Shot Follow preserves the existing target even though the
  newest ball becomes `current_ball`.
- The compact follow action is the sole ordinary entry to Shot Follow. `Tab`
  remains return-only.
- Quick retry may retarget a replacement only when it removed the ball that the
  player had explicitly chosen to follow; this preserves that existing camera
  context instead of introducing a new transition.
- No new dependency or persistent UI element is permitted.

Destructive or irreversible actions:

- None. The existing ignored Windows prototype is refreshed only after source
  validation passes.

Exact actions requiring owner or user approval:

- None within this contract. Any new camera mode, shortcut, or layout change
  requires contract revision.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Fire changes the view | `CannonGolfGame.fire(follow_new_shot := true)` follows the new ball by default and writes HUD camera mode | `src/cannon_golf/cannon_golf_game.gd`; physical-input and session tests currently require automatic follow | Remove the camera parameter and every camera/HUD mutation from `fire()` | 1.1, 1.2 |
| Existing follow target | `current_ball` becomes the newest ball, while `CannonGolfCourseCameraRig` already owns a distinct follow target | `follow_target()` and `toggle_shot_camera()` | A second Fire does not retarget the rig; leaving and explicitly entering follow later selects `current_ball` | 1.1, 1.2 |
| Quick retry | Retry removes `current_ball`, records whether it was followed, then delegates the follow choice into `fire()` | `retry_attempt()` and `_remove_live_ball(..., update_camera := false)` | Keep retry-specific retargeting after launch only for the replaced followed ball; ordinary Fire remains camera-free | 1.1, 1.2 |
| Canonical behavior | PRD FR-8, Design Rules, D-026, and README currently state that Fire starts follow | Current product records and README | Update current specs and add a later accepted decision that supersedes only D-026's automatic-transition sentence | 2.1 |
| Rendered evidence | Capture state `follow` relies on Fire's old side effect | `tests/capture_cannon_golf_frame.gd` | Make follow capture invoke the explicit follow action and add an explored-fire state that validates retained planning pose | 2.2 |
| Validation | Godot 4.7.1, focused runner, capture script, verify script, export preset, and output path exist | Repository scripts and the completed camera execution contracts | Run the two owned tests first, one rendered state, then the focused suite, verify, diff check, export, and bounded built-app smoke once | 1.2, 2.2, 3.1 |

Readiness statement:

- Every material product, architecture, dependency, UX, ownership, safety, and
  validation decision is closed.
- Godot 4.7.1 and all named repository validation paths are available and their
  PowerShell invocations are already established by the completed camera plans.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Fire preserves the active camera context

Goal: make launch admission camera-neutral without breaking explicit follow or
quick retry.

Preconditions:

- The current automatic-follow implementation and its test assumptions are
  reproduced by source inspection.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`tests/cannon_golf_input_test.gd`, `tests/cannon_golf_session_test.gd`

- [x] **1.1** Ordinary Fire has no camera responsibility.
  - Change: remove `follow_new_shot` from `fire()`, remove its camera/HUD branch,
    and keep replacement-follow handling local to `retry_attempt()`.
  - Accept: direct and physical Fire preserve the complete stored planning state
    and resulting camera transform; Fire while following one ball leaves that
    exact target selected after a second ball launches.
  - Guard: the explicit follow action can still enter follow for the newest ball,
    and `Tab` remains unable to enter follow.
- [x] **1.2** Camera-neutral Fire is covered at both input and session boundaries.
  - Change: replace old automatic-follow assertions and remove obsolete
    `fire(false)` call sites in the owned tests.
  - Accept: both test scripts exit zero without `SCRIPT ERROR` or `ERROR:`.

### Phase 2: Product truth and rendered evidence match the interaction

Goal: remove every current claim and capture dependency that treats Fire as a
camera command.

Preconditions:

- Phase 1 checks pass.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`,
`project-specs/cannon-golf/OPEN_QUESTIONS.md`, `README.md`,
`tests/capture_cannon_golf_frame.gd`

- [x] **2.1** Current records state camera-neutral Fire.
  - Change: update FR-8, AC-5, camera grammar, README, and Q-02 wording; record a
    new accepted decision that supersedes D-026 only where it tied Fire to
    automatic follow.
  - Accept: current normative text says Fire preserves camera mode and state,
    while the follow icon owns follow entry.
- [x] **2.2** Capture tooling proves the behavior through the real scene.
  - Change: make the follow state call the explicit follow action, adapt the
    two-live state, and add `fired_explored` with retained orbit/pan/zoom/mode
    assertions.
  - Accept: a 1280x720 capture exits zero, is nonblank, and shows the explored
    planning frame retained after launch.

### Phase 3: Integrated and exported behavior

Goal: prove the change does not regress the wider prototype and refresh the
deliverable.

Preconditions:

- Phases 1-2 pass.

Source owners: all task-owned source, test, documentation, and this contract

- [x] **3.1** Source and Windows release pass the final gates.
  - Change: run the focused suite, verification, diff check, export, and bounded
    hidden built-app smoke; record the results and close this contract.
  - Accept: every named command exits zero and reports no Godot script/runtime
    error; the built executable starts and exits normally.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Phase 1 | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; foreach ($test in @('cannon_golf_input_test.gd','cannon_golf_session_test.gd')) { & $godot --headless --path . --quit-after 7200 --script "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Tasks 1.1-1.2 are implemented | Camera/gameplay input or these tests change |
| UI evidence | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --path . --script res://tests/capture_cannon_golf_frame.gd -- --state=fired_explored --course=0 --width=1280 --height=720 --background --output=res://.godot/capture-temp/fire-camera-independent.png` | Task 2.2 is implemented | A visible world, camera, HUD, or capture input changes |
| Final source gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `git diff --check` | Phases 1-2 pass | A source or final-gate input changes |
| Release gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/CannonGolfPrototype.exe'`; then start that executable with `--headless --quit-after 3` via hidden `Start-Process -Wait` and require exit code zero | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named gate once at its declared cadence.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- On start or resume, read this contract and inspect the worktree only enough to
  confirm checkpoint inputs, then continue from the first unchecked task whose
  prerequisites are satisfied.
- Treat checked tasks and recorded passing evidence as complete unless a
  relevant input changed, the evidence is missing, or this contract schedules a
  broader final gate.
- Update task checkboxes and this contract's progress pointer together after a
  checkpoint; do not mirror progress elsewhere.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update this contract, and obtain required approval before resuming | Do not choose a new camera mode, input grammar, dependency, or validation contract during implementation |
| Fire still changes the rendered planning transform after its direct camera calls are removed | Trace only existing camera invalidation and input propagation, then revise the owned test to identify the actual writer | Do not compensate with a delayed reset, forced snap, or alternate default view |
| A retry removes the actively followed target | Retarget only the replacement ball after successful retry so the explicitly selected follow context remains valid | Do not give ordinary Fire a follow parameter again |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: release gate; all 15 focused tests, project import/script
  parsing, main-scene startup, `git diff --check`, Windows release export, and
  the bounded hidden built-app smoke passed.
- UI evidence: `fired_explored` retained its side view, pan, orbit, zoom, and
  exact camera transform after launch; the 1280x720 capture was nonblank and
  visually intact.
- Update rule: after a checkpoint passes, record concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check, guard, UI evidence gate, final source gate, and
  release gate passes.
- Current product records and README no longer claim automatic follow on Fire.
- Frontmatter status is changed to `done` only after implementation completes.

Replan when:

- A material discovery invalidates the camera-neutral Fire contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
