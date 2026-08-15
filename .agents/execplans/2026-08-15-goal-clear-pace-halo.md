---
type: plan
status: done
created: 2026-08-15
scope: Cannon Golf goal-confirmation camera behavior, ball pace, clear overlay placement, and aim-halo readability
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Goal Confirmation, Faster Pace, Centered Clear, and Readable Halo - Execution Contract

The current runtime freezes confirmed balls correctly, but goal confirmation forcibly retargets Shot Follow to the plate, the result panel is fixed to the upper-left, the aim halo intersects the launcher and puts much of its elevation arc below terrain, exact vertical cannon aim gives Godot a colinear look-at basis, and ball motion uses a `2.0` local time scale. This contract restores the saved planning view immediately after confirmation, doubles the current ball-local pace without global time scaling, centers the existing clear panel, and makes the existing two-axis halo readable in ordinary aerial captures and stable at its legal vertical limits.

## Purpose

- Objective: make goal confirmation, ball motion, the clear state, and the launcher angle instrument behave predictably in normal play.
- Deliverable: task-scoped runtime, scene, specification, and regression-test changes with rendered Godot evidence.
- Completion state: intermediate and final confirmations do not fly the camera toward a goal plate; ball motion resolves in half the current wall-clock motion time with a comparable spatial envelope; the clear panel is centered; and both yaw and elevation are legible from the aerial planning view.

## Scope and Boundaries

In scope:

- Goal-confirmation camera transition and its obsolete delayed-return helper.
- The shared Cannon Golf ball-motion time scale and its analytic horizon.
- Existing result-panel anchors and clear-state capture assertions.
- Existing `CannonGolfAimHalo` height, color, thickness, dotted-arc placement, and marker sizing.
- Canonical product/design records that currently describe the superseded behavior.

Out of scope:

- Goal-plate collision rules, retained-live-ball policy, launcher-source rules, or unlimited firing.
- New trajectory previews, a direction wedge, a second barrel silhouette, or new art assets.
- Terrain generation, course rebakes, camera architecture, and deferred bounce/damping/wind/gravity devices.

Constraints and invariants:

- Confirmed balls remain frozen, visible, and collision-disabled; other active balls remain independent after an intermediate confirmation.
- Confirmation restores the exact saved planning pose immediately and never moves the cannon.
- Motion pacing remains ball-local; `Engine.time_scale`, real-second settlement dwell, and UI/camera timing do not change.
- The halo remains world-space, shadow-free, and trajectory-neutral. Its broad guide remains depth-tested and only compact accents bypass depth.
- Existing node paths, HUD copy, result action, theme resource, and focus behavior remain intact.
- No dependency, prepared-course artifact, or generated course resource changes are permitted.

Destructive or irreversible actions:

- None.

Exact actions requiring owner or user approval:

- None within this locked scope. Any need to change completed-goal collision or course geometry requires replanning and owner direction.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Goal-clear fly-to-plate | `CannonGolfGame._confirm_goal()` forcibly calls `follow(winning_ball)` and schedules a delayed return even though `lock_as_confirmed()` already freezes the ball | `src/cannon_golf/cannon_golf_game.gd:627`; `src/cannon_golf/golf_ball.gd:116`; commit `7f09ed0` | Remove the confirmation retarget/result hold and snap back to the stored planning pose immediately; do not change plate physics | 1.1 |
| Current-relative 2x game pace | `CannonGolfBallistics.MOTION_TIME_SCALE` consistently owns speed, gravity, damping, and velocity thresholds; it is `2.0` and no global time scale is used | `src/cannon_golf/cannon_golf_ballistics.gd:21`; `src/cannon_golf/golf_ball.gd:11`; `src/cannon_golf/settlement_goal.gd:30`; D-028 | Change the local scale to `4.0`, halve the wall-clock horizon, and normalize the analytic substep to the prepared-course authoring scale so spatial routes stay exact; keep real-time settlement and leak guards unchanged | 1.2 |
| Centered stage-clear popup | `Root/ResultOverlay/Panel` uses fixed upper-left offsets, while its full-screen parent and existing node path already support center anchors | `scenes/cannon_golf/cannon_golf_hud.tscn:665`; commit `e6f6491`; rendered clear evidence | Center the same 340 by 184 panel through center anchors; keep its path, theme, action, and focus owner | 2.1 |
| Aerial two-axis halo readability | The ring is only `0.72 m` high, cyan, thin, and much of the `-90..90` elevation arc is below terrain; ordinary 1280 by 720 evidence shows only a small partial ring. At exact vertical cannon aim, `look_at(..., Vector3.UP)` receives colinear vectors and produces repeated rotation warnings | `src/cannon_golf/cannon_golf_aim_halo.gd`; `src/cannon_golf/course_camera_rig.gd`; `.godot/capture-temp/planning-before.png` | Raise the instrument clearly above the base, place the complete dotted arc in positive local height, use deep navy guide geometry, increase only needed guide/marker thickness, and use a stable horizontal look-at reference at exact vertical aim | 2.2 |
| Clear and halo visual proof | The existing capture harness can create real rendered gameplay states but its clear guard still expects temporary follow and does not assert panel centering | `tests/capture_cannon_golf_frame.gd` | Update the capture contract for immediate planning return and centered geometry; add an aerial extreme-angle state and compare ordinary rendered frames | 2.3, 3.1 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot `4.7.1` and the bounded validation wrapper are available; the existing capture and focused-test paths were exercised before editing.
- Remaining unknowns are local halo tuning values that may be adjusted only within the locked dark, elevated, dotted two-axis instrument contract after rendered inspection.

## Tasks

### Phase 1: Stable confirmation and doubled current pace

Goal: confirmation returns to the exact saved planning context without a plate fly-by, and the same spatial shots play in about half the current motion time.

Preconditions:

- Current confirmation, ball-lock, local time-scale, and camera-return owners remain as verified in Discovery Closure.

Source owners: `src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/cannon_golf_ballistics.gd`, `src/cannon_golf/golf_ball.gd`, `tests/cannon_golf_multi_goal_test.gd`, `tests/cannon_golf_session_test.gd`, `tests/cannon_golf_ballistics_test.gd`, `tests/cannon_golf_physics_test.gd`, `tests/cannon_golf_goal_test.gd`

- [x] **1.1** Goal confirmation never flies the camera toward the plate
  - Change: replace confirmation-only follow/hold behavior with an immediate restore of the stored planning pose and remove the now-unreachable delayed helper.
  - Accept: a customized planning transform survives Fire and intermediate confirmation exactly; the winner stays frozen and retained, other live balls survive, the cannon does not move, and Fire remains available.
  - Guard: do not disable completed-plate collision or remove other active balls.
- [x] **1.2** Ball motion is twice as fast as the current build
  - Change: increase the shared local motion scale from `2.0` to `4.0`, halve its wall-clock horizon, normalize the analytic step from `1/60` to `1/120`, and update exact physics/ballistics expectations.
  - Accept: live speed, gravity, ordinary damping, settlement damping, and safe-speed thresholds all derive once from the shared scale; the normalized 600-step analytic recurrence retains the prepared course-space routes while current prepared courses still load and solve under focused checks.
  - Guard: `Engine.time_scale`, one-second settlement dwell, two-second outside-goal rest, and the 15-second pre-contact leak guard remain unchanged.

Batch gate:

- Run the ballistics, physics, multi-goal, lifecycle, input, and solution focused tests once after both tasks pass their narrow checks.

### Phase 2: Centered clear state and readable two-axis halo

Goal: the result modal uses the viewport center and the world-space launcher instrument clearly communicates yaw and elevation from normal aerial planning distance.

Preconditions:

- Phase 1 acceptance checks pass.

Source owners: `scenes/cannon_golf/cannon_golf_hud.tscn`, `src/cannon_golf/cannon_golf_aim_halo.gd`, `src/cannon_golf/cannon_golf_launcher.gd`, `src/cannon_golf/course_camera_rig.gd`, `tests/cannon_golf_camera_test.gd`, `tests/capture_cannon_golf_frame.gd`, `tests/cannon_golf_ballistics_test.gd`

- [x] **2.1** The clear panel is centered at supported viewport sizes
  - Change: replace upper-left offsets with symmetric center anchors and preserve the current panel dimensions and node path.
  - Accept: the panel center matches the viewport center at 1280 by 720, 1600 by 900, and 1920 by 1080; the clear action retains focus and the confirmed ball remains present in the world.
- [x] **2.2** The halo makes both aim axes visible above the launcher
  - Change: raise the halo, use a deep navy unshaded guide, move the full dotted elevation arc above local ground, increase only the geometry needed for ordinary-view thickness, and give exact vertical cannon aim a non-colinear look-at up vector.
  - Accept: the horizontal ring plus perimeter tick clearly show yaw and the raised dotted arc plus bead clearly show elevation at center and extreme angles in aerial captures; exact `-90` and `+90` cannon aim retain a finite aligned camera basis; there is no center-origin line, wedge, trajectory, or second-barrel silhouette.
  - Guard: retain a depth-tested broad guide, compact no-depth active accents, world-space scaling, and disabled shadows.
- [x] **2.3** Capture assertions encode the new visible contract
  - Change: make clear capture require planning mode and centered panel geometry, and add aerial and exact-down cannon halo states.
  - Accept: bounded real-render captures fail if confirmation remains in follow, the panel is off-center, or either extreme halo state cannot be produced.

Batch gate:

- Render the planning/default halo, aerial extreme halo, ordinary and exact-down cannon views, and clear state at 1280 by 720; render clear again at 1600 by 900 and 1920 by 1080.

### Phase 3: Specification alignment, regression, and handoff

Goal: canonical records describe the accepted behavior and the complete task-owned change is verified and committed without unrelated worktree content.

Preconditions:

- Phase 2 acceptance checks and rendered batch gate pass.

Source owners: `project-specs/cannon-golf/DECISIONS.md`, `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/PRD.md`, task-owned changed files and tests

- [x] **3.1** Product records no longer prescribe the superseded hold, pace, popup placement, or low halo
  - Change: append the accepted 2026-08-15 decision and minimally align the canonical requirements/design language.
  - Accept: current documents state immediate planning restoration on confirmation, current-relative doubled ball pace, centered clear modal, and a dark fully above-ground two-axis halo; deferred devices remain deferred.
- [x] **3.2** Final regressions and quality audit pass
  - Change: run the complete Cannon Golf focused suite once, inspect final rendered frames, and apply only small safe audit corrections within scope.
  - Accept: all focused and full-suite commands exit zero, no Godot error is reported, required renders are visually legible and unclipped, and the quality audit finds no reachable task-owned failure.
- [x] **3.3** Commit only task-owned files
  - Change: mark this plan `done`, stage only the files named by this contract, and create one coherent commit with a short explanatory body.
  - Accept: unrelated modified theme/menu/UI-test files and unrelated untracked UID files remain unstaged and unchanged.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `scripts/invoke-cannon-golf-validation.ps1 -CheckOnly -Script res://src/cannon_golf/<changed-script>.gd`; then the directly owned focused test | Each script or focused-test contract is first complete | Relevant implementation input changes |
| Phase 1 gate | `cannon_golf_ballistics_test.gd`, `cannon_golf_physics_test.gd`, `cannon_golf_multi_goal_test.gd`, `cannon_golf_live_ball_lifecycle_test.gd`, `cannon_golf_input_test.gd`, and `cannon_golf_solution_test.gd` through the bounded wrapper | Phase 1 tasks pass | A Phase 1 input changes |
| Phase 2 gate | `capture_cannon_golf_frame.gd` rendered for planning, aerial extreme, ordinary cannon, exact-down cannon, and clear at 1280 by 720, plus clear at 1600 by 900 and 1920 by 1080 | Phase 2 tasks pass | A Phase 2 visual or capture input changes |
| Final gate | `scripts/test-cannon-golf.ps1`, final rendered-frame inspection, and `codebase-quality-auditor` review | All phases pass | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Run the complete focused suite only once after implementation and rendered tuning are stable.
- Rerun a failed check only after a relevant implementation change or a new evidence-producing hypothesis.
- Record known non-blocking compatibility-rendering warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain any required approval before resuming | Do not let implementation choose a new gameplay, camera, physics, or UX contract |
| The `4.0` local scale materially changes spatial reach or breaks prepared-course solvability | Keep the current-relative 2x time objective but adjust only the shared analytic horizon/derived coefficients, then rerun Phase 1 | Do not rebake courses or use global engine time scale without owner approval |
| The centered panel covers the confirmed ball in a required clear capture | Preserve panel centering and restore the saved planning pose; adjust only the clear-state camera return or panel dimensions inside existing design bounds | Do not move the panel back to an edge |
| The dark raised halo remains unreadable at 1280 by 720 | Increase only guide thickness, dot/bead size, or float height within the existing owner and rerender | Do not add a trajectory, screen-space widget, direction wedge, or new asset |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Final gate — all 24 focused-suite entries passed with zero Godot error lines. The final quality audit found no unresolved task-owned failure after adding continuous heading-derived vertical camera orientation, exact-down child-marker projection guards, direct course-authoring recurrence comparison, and final confirmation coverage from a saved cannon pose. Default and extreme aerial halo, compact ordinary and exact-down cannon halo, and centered clear renders passed at 1280 by 720; centered clear also passed at 1600 by 900 and 1920 by 1080.
- Update rule: after a checkpoint passes, record its concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every guard, phase gate, and final gate named by this contract passes.
- No placeholder or unresolved material decision remains.
- Any durable decision or new run or verify knowledge created by the work is recorded in its owning specification or decision record.
- Frontmatter status is changed to `done` only after the implementation is complete.

Replan when:

- A material discovery invalidates the locked contract.

Do not replan or stop for:

- Halo-size tuning within the locked elevated, dark, dotted world-space design.
- A passing check whose relevant inputs have not changed.
