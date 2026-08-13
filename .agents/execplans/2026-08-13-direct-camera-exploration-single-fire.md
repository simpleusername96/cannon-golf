---
type: plan
status: done
created: 2026-08-13
scope: Direct terrain camera exploration and single-owner Fire input for Cannon Golf gameplay
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Direct Camera Exploration and Single Fire Input - Execution Contract

The playable course will gain direct, stable terrain navigation while the reproduced Space-key duplication is removed at its input boundary. The work adapts Paint Mountain's fixed-focus orbit lessons to Cannon Golf's stored planning camera, keeps the normal HUD compact, and validates source, rendered desktop states, and the exported Windows build.

## Purpose

- Objective: make terrain inspection usable with left-drag orbit, meaningful wheel zoom, keyboard pan, and a compact reset/zoom affordance, while guaranteeing one Space press can create at most one ball.
- Deliverable: updated camera rig, gameplay input owner, HUD, focused regression coverage, capture state, product records, README, and refreshed Windows prototype.
- Completion state: direct camera interactions preserve aim and planning state, UI controls are accessible and unclipped, real Space events do not double-fire, and all named final gates pass.

## Scope and Boundaries

In scope:

- Cannon Golf gameplay camera input, planning-pose state, compact camera controls, tests, capture tooling, current product records, and player controls documentation.
- Both introductory courses at supported desktop sizes of 1280x720 and 1600x900.

Out of scope:

- A separate map-inspection mode, click-to-refocus, free-fly camera, touch controls, new course content, physics tuning, or changes to the two-live-ball rule.
- Reworking retained Paint Mountain runtime owners; they remain reference evidence only.

Constraints and invariants:

- Left-drag orbits around the stored planning focus; an un-dragged click does not pan or refocus.
- Wheel zoom is multiplicative and bounded, with enough inward and outward range to be visible while the camera remains usable.
- Arrow-key pan, view choice, orbit, pan, zoom, all three launch values, and impact history survive Shot Follow and quick retry.
- Direct camera interaction during Shot Follow first returns to planning, then applies the requested exploration input.
- Space has one authoritative gameplay path. A focused non-Fire button retains native keyboard activation and does not fire.
- Normal play gains only one restrained three-button camera dock (`+`, reset, `-`); no help panel, shortcut legend, camera-state label, or instructional copy is added.
- No new dependency is permitted.

Destructive or irreversible actions:

- None. The existing Windows prototype output is refreshed by the existing export preset after source validation.

Exact actions requiring owner or user approval:

- None within this contract. Any dependency, camera mode, or course-rule expansion requires contract revision and user approval.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Duplicate launch | `CannonGolfGame._unhandled_input` calls `fire()` for Space while the focused `FireButton` also performs its native Space press | Real `Input.parse_input_event` probe produced two active balls from one Space press | Move Space to one handled `_input` route modeled on the retained Paint Mountain controller; remove Space from `_unhandled_input` | 1.1, 1.2 |
| Terrain drag | `CannonGolfCourseCameraRig` owns stored planning pose but exposes only key pan and narrow linear zoom | Runtime source and retained `CameraDirector` fixed-focus inspection behavior | Add spherical yaw/pitch orbit around the current stored planning focus; do not refocus on click | 2.1, 2.2 |
| Zoom usefulness | `adjust_zoom` clamps `1.0..1.45` from `1.05`, so inward range is almost absent | Camera rig and camera test | Use bounded multiplicative wheel steps over `0.58..1.65`; expose the same owner to compact HUD actions | 2.1, 2.3 |
| Follow continuity | Planning view/pan/zoom are cached and restored after follow | PRD FR-8/AC-5, D-018, current camera/session tests | Orbit joins the stored planning state; any direct planning-camera input exits follow before it mutates state | 2.1, 2.2 |
| Minimal UI | HUD currently has one aim panel and one action dock; persistent help/shortcut panels are prohibited | UI scene/test, FR-9, design rules | Add a 44 px icon-only vertical camera dock at the safe upper-right edge with tooltips and accessible names | 2.3 |
| Performance | Planning pose caching prevents unchanged-frame rebuilds | `cannon_golf_performance_test.gd` and camera rig | Invalidate only on camera-state mutation or viewport change; mouse motion performs one pose update path and adds no physics work | 2.1, 3.1 |
| Validation | Godot 4.7.1, focused runner, capture script, verify script, export preset, and build output exist | Direct path/version/command inspection and prior completed execution evidence | Add the input regression to the focused runner; capture explored states; run source gates once, then release export and bounded hidden smoke | 3.1, 3.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot 4.7.1 and all repository validation paths are available; the named commands match the active PowerShell environment.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: One physical Space press creates one ball

Goal: remove the reproduced double-dispatch without breaking keyboard activation of other buttons.

Preconditions:

- The ignored diagnostic probe has reproduced two active balls from one real Space press while `FireButton` owns focus.

Source owners: `src/cannon_golf/cannon_golf_game.gd`, `tests/cannon_golf_input_test.gd`, `scripts/test-cannon-golf.ps1`

- [x] **1.1** Space uses one authoritative input path.
  - Change: handle non-echo Space presses in `_input`, consume accepted gameplay Fire input, preserve native activation for focused non-Fire buttons, and remove the Space branch from `_unhandled_input`.
  - Accept: a real Space press with Fire focused creates exactly one ball; a second press creates exactly one additional ball; a third press is rejected at capacity.
  - Guard: Space with a secondary HUD button focused must not create a ball.
- [x] **1.2** The reproduced failure is permanently covered.
  - Change: add `cannon_golf_input_test.gd` to the focused runner using `Input.parse_input_event`, not direct method calls.
  - Accept: `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_input_test.gd` exits zero and reports no Godot script/runtime error.

### Phase 2: Direct stable course exploration

Goal: let the player inspect terrain without losing the planning context or adding a heavy help surface.

Preconditions:

- Phase 1 acceptance and guard pass.

Source owners: `src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/cannon_golf_hud.gd`, `scenes/cannon_golf/cannon_golf_hud.tscn`, `tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_input_test.gd`, `tests/cannon_golf_ui_contract_test.gd`

- [x] **2.1** The planning rig owns bounded fixed-focus orbit and useful zoom.
  - Change: add stored yaw/pitch orbit, pitch clamps, multiplicative zoom steps, a planning-view reset, and cache invalidation only on state changes.
  - Accept: the camera test proves orbit changes position without changing the planning focus, zoom changes distance in both directions, both courses remain fully framed at default/reset and zoom-out, closer zoom respects its distance clamp and a valid pose, explicit reset restores the authored view, and unchanged frames reuse the cached pose.
- [x] **2.2** Mouse interaction works directly over the world.
  - Change: left-button drag applies orbit; wheel applies zoom; release/cancel ends drag and restores the cursor; camera input during follow returns to planning first; UI-consumed pointer events do not reach the world handler.
  - Accept: the real-input test proves drag changes orbit while preserving all launch values and click-only does not move/refocus; wheel changes zoom; drag/wheel during follow restores planning.
  - Guard: pause and scene exit cannot leave the global cursor in dragging state.
- [x] **2.3** Camera controls are minimal, accessible, and unclipped.
  - Change: add a restrained upper-right camera dock with zoom-in, reset, and zoom-out actions, localized tooltips/accessibility names, and explicit keyboard focus order; `Home` invokes reset without a persistent shortcut legend.
  - Accept: the UI contract test finds 44 px targets, accessible names, an explicit focus chain, one normal primary action, no overlap with the center 70%, and no clipping at 1280x720 or 1600x900.

Batch gate:

- Run the camera, input, UI contract, session, and performance tests once after Tasks 2.1-2.3 pass; they must exit zero without `SCRIPT ERROR` or `ERROR:` output.

### Phase 3: Product record, rendered evidence, and release verification

Goal: make the implemented behavior discoverable and prove the actual desktop build follows it.

Preconditions:

- Phase 2 batch gate passes.

Source owners: `project-specs/cannon-golf/PRD.md`, `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/DECISIONS.md`, `README.md`, `tests/capture_cannon_golf_frame.gd`, this contract

- [x] **3.1** Current records and captures describe the direct camera grammar.
  - Change: update FR-8/FR-9/AC-5, camera/HUD rules, D-018, README controls, and the capture runner; collect planning and explored states for both courses at 1280x720 plus an explored state at 1600x900.
  - Accept: captures are nonblank and visually show an intact HUD, open course center, compact camera dock, and materially different stable explored framing; document wording contains no separate inspection mode or click-to-refocus claim.
- [x] **3.2** Source and exported Windows app pass the final gates.
  - Change: remove the ignored diagnostic probe, run the focused suite, verification, diff checks, export the existing Windows preset, and start the built executable in a bounded hidden smoke.
  - Accept: every final command exits zero, no stale diagnostic remains, and the built executable starts and exits normally.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Task 1 | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_input_test.gd` | Tasks 1.1-1.2 are implemented | Fire/input-owned source changes |
| Phase 2 | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; foreach ($test in @('cannon_golf_camera_test.gd','cannon_golf_input_test.gd','cannon_golf_ui_contract_test.gd','cannon_golf_session_test.gd','cannon_golf_performance_test.gd')) { & $godot --headless --path . --quit-after 7200 --script "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Tasks 2.1-2.3 pass | A camera, HUD, session, or performance input changes |
| UI gate | Use `tests/capture_cannon_golf_frame.gd` for `planning` and `explored` on both courses at 1280x720 and `explored` course 0 at 1600x900 | Task 3.1 implementation passes | A visible camera/HUD/world input changes |
| Final source gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; then `git diff --check` | All tasks and UI evidence pass | A source/final-gate input changes |
| Release gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/CannonGolfPrototype.exe'`; then start that executable with `--headless --quit-after 3` via hidden `Start-Process -Wait` and require exit code zero | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Rerun a failed check only after a relevant implementation change or a new hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.
- On start or resume, read this contract and inspect the worktree only enough to confirm checkpoint inputs, then continue from the first unchecked task whose prerequisites are satisfied.
- Treat checked tasks and passing evidence as complete unless a relevant input changed, evidence is missing, or this contract schedules the broader final gate.
- Update task checkboxes and the progress pointer together after each checkpoint; do not mirror progress elsewhere.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update this contract, and obtain any required approval before resuming | Do not choose a new product, architecture, dependency, UX, or validation contract during implementation |
| Fixed-focus orbit cannot retain both courses inside usable camera limits | Keep the fixed-focus interaction and revise only the tested numeric clamp/margin within existing camera ownership | Do not add free-fly, click-refocus, terrain regeneration, or course edits |
| The compact camera dock overlaps the course or existing HUD at a supported size | Adjust only the dock's safe-edge anchoring and spacing, then rerun UI contract and captures | Do not add explanatory panels or move core aim/Fire controls without contract revision |
| A real Space event still reaches two launch paths | Record the exact focused control and event route, stop the input branch, and revise the owner boundary before further UI work | Do not mask the defect by reducing live-ball capacity or debouncing physics |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: release gate; all 15 focused tests, project import/script parsing, main-scene startup, `git diff --check`, Windows release export, and the bounded hidden built-app smoke passed.
- Input evidence: a real Space press with Fire focused creates one ball, a second press adds one ball, a third is capacity-blocked, and Space on a secondary control keeps native activation without firing.
- Camera evidence: real drag/wheel/Home input preserves launch values and fixed focus, restores planning from Shot Follow, and leaves no unchanged-frame pose rebuilds after drag.
- UI evidence: reviewed captures for both courses at 1280x720 and course one at 1600x900 show distinct explored framing, one primary Fire action, an open course center, and unclipped 44 px accessible camera controls.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check, guard, batch gate, UI gate, final source gate, and release gate passes.
- No placeholder, unresolved material decision, or ignored diagnostic probe remains.
- Durable behavior is recorded in the product specs/decision record and player controls in README.
- Frontmatter status is changed to `done` only after implementation is complete.

Replan when:

- A material discovery invalidates the locked interaction, ownership, scope, dependency, or validation contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
