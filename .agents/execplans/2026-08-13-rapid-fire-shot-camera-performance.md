---
type: plan
status: done
created: 2026-08-13
scope: Paint Mountain-style shot-follow return, two concurrent Cannon Golf shots, and removal of deterministic terrain-generation frame hitches
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-13-large-free-aim-course.md
---

# Rapid Fire, Shot Camera, and Performance - Execution Contract

Keep automatic Shot Follow after Fire, but let the player return immediately to
the stored planning camera, edit all three launch values, and fire a second ball
while the first remains live. Remove the measured synchronous terrain rebuilds
and follow-camera sampling jitter without reducing the established visual
quality.

## Purpose

- Objective: make shot observation optional instead of a lock on the next shot,
  and remove the transition hitches reported as frame lag.
- Deliverable: independent live-ball state, a planning/follow camera toggle,
  non-blocking aim controls, deterministic terrain reuse, stable interpolated
  follow motion, focused regression coverage, rendered evidence, and a refreshed
  Windows build.
- Completion state: Fire enters Shot Follow; `Tab` or the follow icon returns to
  the prior overview/side pose; aim and Fire remain available for a second live
  ball; two live balls are bounded; cached transitions no longer regenerate the
  same terrain; normal foreground play continues to meet the 60 Hz VSync ceiling
  on the measured machine.

## Scope and Boundaries

In scope:

- The current two-course Cannon Golf prototype.
- At most two simultaneously active, unconfirmed balls.
- Automatic follow of the newest shot, explicit return to planning, and optional
  return to the newest live ball.
- Per-ball settlement/failure bookkeeping and current-ball quick retry.
- Reuse of immutable deterministic terrain products and cached planning-camera
  framing.
- Existing medium-quality visuals, shadows, resolution, and physics tick rate.

Out of scope:

- Device placement, additional courses, trajectory preview, time controls,
  unlimited simultaneous physics bodies, or a camera redesign.
- Lower default resolution, disabled shadows, reduced terrain scale, or altered
  goal/ball physics as a performance substitute.

Constraints and invariants:

- A successful ball still clears the one-goal course and becomes irreversible;
  other live balls are removed when that result is confirmed.
- Each ball owns its own entered-goal and settling timers. One ball cannot fail
  or confirm another ball's attempt state.
- Quick retry replaces only the newest active unconfirmed ball and preserves the
  three-value setup, planning pose, and impact history.
- Overview/side selection always returns to planning. `Tab` toggles between the
  stored planning pose and the newest live ball when one exists.
- Terrain cache entries contain only deterministic immutable generation output;
  scene nodes and course resources remain per builder.

Destructive or irreversible actions:

- None. The existing ignored Windows artifact is refreshed only after all source
  gates pass.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Adjust and fire after a launch | `CannonGolfGame` gates setup and Fire on one global `LaunchState` and `current_ball` | `cannon_golf_game.gd`; Paint Mountain `StageController.request_fire()` retains cannon input and admits two roots | Replace the singleton attempt gate with per-ball state and a two-live-ball cap | 1.1, 1.2 |
| Shot camera switching | Cannon Golf always follows `current_ball`; Paint Mountain enters `FOLLOW` and `Tab` calls `return_to_aim_view()` | `course_camera_rig.gd`, `camera_director.gd`, `aim_input_controller.gd`; accepted D-018 | Preserve auto follow, add planning/follow mode and `Tab`/icon toggle, restore stored overview/side/pan/zoom | 2.1, 2.2 |
| Reported frame lag | Foreground probe reaches 60.0 FPS, but cold menu setup is about 4.0 s and gameplay transition about 1.29 s; off-screen 31 FPS is Windows background throttling | Compatibility renderer probe on Intel Iris Xe, 1280x720, 60 Hz VSync | Remove repeated deterministic terrain builds and per-frame planning framing; use interpolated ball transforms; do not lower visuals | 3.1 |
| Goal and retry correctness | Goal timers and retry currently belong to the singleton `current_ball` | `cannon_golf_session_test.gd`, `cannon_golf_goal_test.gd` | Track timers by ball identity; current ball means newest active ball; confirmation ends the course | 1.1, 1.2 |
| UI availability | `CannonGolfHUD.set_busy()` disables every slider and Fire while a ball is live | HUD script/scene and UI contract test | Replace busy state with live-shot capacity; add one 44 px accessible follow icon | 2.2 |

Readiness statement:

- Every material behavior, ownership, UX, performance, and validation decision is
  closed. No dependency or schema change is required.
- Godot 4.7.1, the focused runner, capture runner, Windows export preset, and
  PowerShell commands are available and already exercised in this repository.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Independent live shots

Goal: aiming and a second Fire remain available while the first ball moves.

Preconditions:

- Current focused Cannon Golf suite passes at commit `35a44ed`.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/golf_ball.gd`, `tests/cannon_golf_session_test.gd`

- [x] **1.1** Each live ball resolves its own settlement and failure state.
  - Change: store per-ball timers and goal-entry state, keep the newest active
    ball as the current retry/follow target, and clear all other live balls only
    after one ball confirms the goal.
  - Accept: a focused multi-ball session test proves that one ball's failure does
    not remove the other and either ball can confirm independently.
- [x] **1.2** The player can adjust and fire again immediately.
  - Change: allow setup edits whenever the course is not cleared; admit Fire
    while fewer than two balls are live; make quick retry replace only the newest
    ball without changing setup, camera context, or marks.
  - Accept: the session test fires two distinct balls with different launch
    values while the first remains valid, rejects only a third live ball, and
    proves quick-retry preservation.

### Phase 2: Paint Mountain-style camera return

Goal: Shot Follow is temporary and never prevents planning interaction.

Preconditions:

- Phase 1 acceptance passes.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`,
`tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_ui_contract_test.gd`

- [x] **2.1** Planning and Shot Follow are explicit camera modes.
  - Change: follow the newest shot through its interpolated physics transform;
    let `Tab` toggle follow/planning; make overview/side restore the stored
    planning view, pan, and zoom.
  - Accept: the camera test proves automatic follow, exact planning-context
    retention, return during live flight, and fallback when the followed ball
    ends.
- [x] **2.2** Mouse and keyboard users can reach the camera return and next shot.
  - Change: replace HUD busy locking with capacity state and add one follow icon
    with tooltip, accessibility name, selected state, and explicit focus order.
  - Accept: UI/session tests prove editable controls, Fire availability for shot
    two, disabled capacity at two, `Tab`, icon operation, target size, focus, and
    Korean/English fit.

### Phase 3: Remove measured hitches and validate delivery

Goal: deterministic course reuse removes repeated generation work while visuals
and live gameplay stay stable.

Preconditions:

- Phases 1-2 acceptance passes.

Source owners: `src/cannon_golf/course_terrain_factory.gd`,
`src/cannon_golf/app/cannon_golf_preview_world.gd`,
`src/cannon_golf/course_camera_rig.gd`, `tests/cannon_golf_performance_test.gd`,
`tests/capture_cannon_golf_frame.gd`, `scripts/test-cannon-golf.ps1`, `README.md`

- [x] **3.1** Repeated transitions reuse deterministic terrain and camera work.
  - Change: cache immutable terrain products by every generation-affecting course
    value, skip rebuilding an already displayed preview, and recompute planning
    framing only after view/pan/zoom/viewport changes.
  - Accept: a performance contract test proves cache identity without shared
    scene nodes, no duplicate same-preview rebuild, and no repeated planning-pose
    solve across unchanged frames. The same foreground probe remains at the 60 Hz
    VSync ceiling and shows a material reduction from the measured 4.0 s menu /
    1.29 s gameplay transition baseline.
  - Guard: course resources, scene nodes, and active balls remain builder/game
    local; only immutable generated layout, geometry, graphs, metrics, and bounds
    are shared.
- [x] **3.2** Documentation, focused behavior, rendered states, and Windows output agree.
  - Change: record the rapid-fire/camera contract in PRD, design rules, decisions,
    and README; add focused tests to the runner; capture planning, follow, two-live-
    shot planning, pause, and both course views; refresh the Windows export.
  - Accept: focused suite, `scripts/verify.ps1`, `git diff --check`, Level 3
    rendered evidence, export, and bounded hidden built-executable smoke all pass.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit` | A script signature, scene, or resource changes | A relevant parse/import input changes |
| Phase 1 | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_session_test.gd` | Tasks 1.1-1.2 pass locally | A live-ball/session input changes |
| Phase 2 | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; foreach ($test in @('cannon_golf_camera_test.gd','cannon_golf_ui_contract_test.gd','cannon_golf_session_test.gd')) { & $godot --headless --path . --quit-after 7200 --script "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Tasks 2.1-2.2 pass locally | A camera/HUD/session input changes |
| Final source gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `git diff --check` | All tasks and rendered UI evidence pass | A source/final-gate input changes |
| Release gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/CannonGolfPrototype.exe'`; then `$process = Start-Process -FilePath (Resolve-Path 'builds/windows/CannonGolfPrototype.exe') -ArgumentList '--headless','--quit-after','3' -PassThru -Wait -WindowStyle Hidden; if ($process.ExitCode -ne 0) { exit $process.ExitCode }` | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Do not rerun a passing check merely to regain confidence.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update this contract, and obtain any required approval before resuming | Do not choose a new product, architecture, dependency, UX, or validation contract during implementation |
| Two balls make one-goal confirmation ambiguous | The first physically confirmed safe settlement wins and removes other live balls | Do not require simultaneous settlement or let a later ball displace the winner |
| Shared cached data is mutated by a builder | Split mutable data from the cache and keep only proven immutable products | Do not share course resources, scene nodes, balls, goal state, or camera state |
| Performance remains below foreground VSync after hitch removal | Record foreground frame time, draw calls, primitives, and the changed-path timings, then revise this contract | Do not lower resolution, terrain size, shadows, or physics quality without owner approval |
| Follow mode hides the controls or causes clipping | Keep the established edge HUD and adjust only the compact action dock | Do not add a status card, tutorial panel, or persistent shortcut legend |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Windows export and built-executable smoke.
- Baseline evidence: foreground Compatibility rendering at 1280x720 reaches
  60.0 FPS planning and follow on a 60 Hz display; cold menu preparation is
  approximately 4.0 seconds and gameplay transition approximately 1.29 seconds.
  Disabling shadows reduced primitives but did not affect the background-limited
  probe, so visual-quality reduction was rejected.
- Phase 1 evidence: `cannon_golf_session_test.gd` passed two simultaneous
  distinct launch velocities, live setup controls, a two-ball capacity guard,
  per-ball failure isolation, first-winner confirmation, current-ball quick
  retry, pause, five retained marks, unlimited sequential retries, and full
  reset. The first ball remained valid when the second launched.
- Phase 2 evidence: camera, UI contract, and session tests passed automatic
  interpolated Shot Follow, `Tab`/explicit return, exact overview/side/pan/zoom
  retention, ended-target fallback, cached unchanged planning frames, a 44-pixel
  accessible follow icon, explicit focus order, editable live-flight sliders,
  enabled second Fire, and disabled two-ball capacity.
- Task 3.1 evidence: `cannon_golf_performance_test.gd` passed immutable terrain
  reuse with builder-local course/scene ownership, same-preview node reuse, and
  planning framing invalidation only after a real input change. The repeated
  foreground probe remained at 60.0 FPS planning/follow; menu readiness improved
  from about 4,001 ms to 1,433 ms (64 percent), and gameplay entry from about
  1,292 ms to 24 ms (98 percent), with visuals and physics settings unchanged.
- Task 3.2 evidence: the 14-test focused Cannon Golf suite, project import,
  script parse, main-scene startup, `git diff --check`, Windows release export,
  and the hidden built-executable smoke all passed. Level 3 rendered evidence
  covered planning, side, Shot Follow, two-live planning, and pause at 1280x720,
  both courses, plus a 1600x900 planning view. A foreground course-two follow
  capture confirmed complete Korean glyph rendering after the off-screen
  Compatibility renderer intermittently delayed individual font-atlas glyphs.
- Delivery artifact: `builds/windows/CannonGolfPrototype.exe`, 127,455,080
  bytes, SHA-256
  `AFE429E239C89E246D0C47576C480B7C17E66807F1C1D861BCFEF45C0158CCAC`.
- Quality audit: per-ball state remains isolated from course orchestration,
  camera state remains owned by the rig, immutable terrain reuse remains owned
  by the factory, and unexpected early ball deletion now purges every live-shot
  owner and restores both camera and HUD to planning.
- Update rule: after a checkpoint passes, record concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every phase, UI, source, and release gate named by this contract passes.
- A player can observe shot one, return to planning, change aim, and launch shot
  two without removing shot one or resetting planning context.
- The measured duplicate-generation hitches are removed without visual-quality
  reduction and foreground play remains at the display's VSync ceiling.
- Durable behavior and run knowledge are recorded in their owning records and
  README.
- Frontmatter status changes to `done` only after implementation and release
  validation complete.

Replan when:

- A material discovery invalidates the two-live-ball, camera-toggle, immutable-
  cache, visual-quality, or validation contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
