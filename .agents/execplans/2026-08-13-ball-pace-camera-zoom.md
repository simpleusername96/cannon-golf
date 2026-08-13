---
type: plan
status: done
created: 2026-08-13
scope: Success/failure evidence, stronger planning zoom, larger ball, and doubled launch speed
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Ball Pace and Camera Zoom - Execution Contract

The two-course Cannon Golf prototype will retain its existing safe-settlement success and per-shot failure rules, make planning zoom visibly useful per input, enlarge the physical and rendered ball, and double the canonical launch-speed range while preserving certified direct solutions through recalibrated power witnesses.

## Purpose

- Objective: make outcome judgment trustworthy and the course/ball easier and faster to read.
- Deliverable: stronger bounded zoom, a `0.75 m` ball radius, a doubled `28..120 m/s` launch-speed range with temporally scaled ball physics, preserved course solutions, focused regressions, rendered evidence, current product records, and a refreshed Windows build.
- Completion state: zoom buttons and wheel have an obvious bidirectional effect, the ball is larger without physics/render drift, both courses still distinguish default misses from certified clears, and all named source/release gates pass.

## Scope and Boundaries

In scope:

- Cannon Golf camera rig/input tests, ballistic and ball constants, two prototype solution witnesses, outcome/physics/camera tests, gameplay capture, PRD/design/decision records, and Windows prototype output.

Out of scope:

- New success/failure HUD copy, goal tolerance changes, time scaling, terrain resizing, cannon geometry, or later device stages.

Constraints and invariants:

- Success remains continuous safe settlement inside the goal; its velocity thresholds double and confirmation time halves to preserve equivalent spatial safety under `2x` temporal motion. Failure remains bounced-out, stopped-outside, out-of-bounds, or timeout. A miss does not fail the stage.
- Ball collision and visible mesh share one `0.75 m` radius, and ballistics uses the same radius for muzzle clearance and range admission.
- Canonical speed endpoints double from `14..60` to `28..120 m/s`; power remains `10..100` and visible defaults remain `50`.
- Existing direct-solution direction, elevation, and power are retained and live replay remains authoritative.
- Doubling launch velocity alone invalidates the original course envelope. Preserve approximate spatial trajectories at half real duration by pairing `2x` launch speed with `4x` per-ball gravity and `2x` linear/angular damping. Double velocity thresholds and halve dwell thresholds used by outcome judgment. Use a `10 s` live/admission horizon to absorb rigid-body and larger-radius settling variance. Whole-terrain range, yaw, and height margins remain `8 m`, `8°`, and `8 m`.
- Planning zoom uses the existing multiplicative owner with `0.78` per step and a `0.38..2.0` bounded range. Positive input remains zoom-in and negative input remains zoom-out.
- No dependency is added.

Destructive or irreversible actions:

- None. Ignored build output is refreshed after validation.

Exact actions requiring owner or user approval:

- Further changes to goal tolerances, physics time scale, terrain size, or speed beyond the requested exact doubling require separate direction.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Success/failure judgment | `CannonGolfGame._update_live_ball`, `CannonGolfSettlementGoal`, and `CannonGolfBall` already confirm safe settlement and reject four miss outcomes | Source plus goal/session/solution tests | Preserve equivalent safe motion under temporal scaling: double velocity thresholds, halve dwell thresholds, retain the same four outcomes | 1.2, 2.2 |
| Weak zoom feel | Wheel and compact buttons reach `zoom_by_steps`, but each step changes distance only 10% and planning motion is smoothed | Input/camera tests and camera constants | Increase per-step effect and range while retaining direction, bounds, reset, follow escape, and one camera owner | 1.1 |
| Ball readability | `CannonGolfBall.RADIUS` controls both collision and mesh at `0.55`; `CannonGolfBallistics.BALL_RADIUS` separately mirrors it | Ball/ballistics source | Raise both to `0.75` and add parity/mesh/collider guards | 2.1 |
| Double speed | `CannonGolfBallistics.MINIMUM_SPEED/MAXIMUM_SPEED` are `14/60`; launcher and admission both call this owner | Ballistics/launcher/range source | Set canonical endpoints to `28/120`, not global time scale or a second multiplier | 2.1 |
| Course solvability | Both resources stored direct witnesses at power `72`; live solution replay is the final authority | Course resources and bounded live replay | Preserve First Ridge at power `72`; Rising Bend recertifies at the adjacent power `71`, retaining horizontal aim and elevation | 2.2 |
| Course envelope after doubling | Velocity-only doubling made low terrain and support-shell points unreachable and broke the certified solution | Failed live range/goal/solution replay | Apply local temporal scaling (`2x` speed, `4x` gravity, `2x` damping, half horizon) and keep all `8`-unit admission margins | 2.1, 2.2, 3.1 |
| Validation | Godot 4.7.1, focused suite, capture runner, verify script, export preset, and build path passed commit `c33fa16` | Repository commands and prior production gate | Use targeted camera/physics/solution checks, one rendered follow/zoom pass, then full source and release gates once | 3.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Required tools and dependencies are available and the named Godot 4.7.1 repository commands are verified.
- Remaining unknowns are implementation-local numeric replay results; the predetermined response is limited to recertifying solution power without changing the locked physics contract.

## Tasks

### Phase 1: Outcome and camera behavior

Goal: retain truthful result judgment and make every zoom input visibly meaningful.

Preconditions:

- Existing camera input routing and settlement owners remain authoritative.

Source owners: `src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/cannon_golf_game.gd`, `tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_input_test.gd`

- [x] **1.1** Wheel and compact actions apply stronger, bounded zoom in the correct direction.
  - Change: update zoom factor/range and assert one-step distance ratios through rig and real input/button paths.
  - Accept: camera and input tests prove zoom-in reduces distance by at least 20%, zoom-out reverses it, reset restores default, and extreme input remains finite and bounded.
- [x] **1.2** Existing success and miss conditions stay explicit and reachable.
  - Change: retain the authoritative state machine and extend focused assertions only where new ball/flight tuning touches it.
  - Accept: goal/session/solution tests prove safe settlement clears, bounce-out and stopped/out-of-bounds paths remain failures, and a failed launch returns to reusable planning.

### Phase 2: Larger, twice-fast ball with certified courses

Goal: improve ball readability and launch pace without splitting physics owners or losing the two playable solutions.

Preconditions:

- Phase 1 targeted camera checks pass.

Source owners: `src/cannon_golf/cannon_golf_ballistics.gd`, `src/cannon_golf/golf_ball.gd`, `resources/cannon_golf/courses/*.tres`, `tests/cannon_golf_ballistics_test.gd`, `tests/cannon_golf_goal_test.gd`, `tests/cannon_golf_solution_test.gd`

- [x] **2.1** Physical/rendered ball size and launch speed use the new canonical values.
  - Change: set both radius owners to `0.75`, both speed endpoints to exact doubles, and add collider/mesh/parity/endpoint assertions.
  - Accept: ballistics and physics tests prove `28/120`, shared `0.75` radius, matching live shape/mesh, deterministic velocity, and stable rebound.
- [x] **2.2** Both direct courses remain deliberately solvable while defaults miss.
  - Change: retain each stored solution witness under the temporally scaled doubled-speed mapping; recertify a nearby integer only if live replay disproves it.
  - Accept: live replay clears both certified solutions and rejects both defaults; whole-terrain range admission and basin containment pass.

### Phase 3: Product record and production evidence

Goal: keep guidance truthful and verify actual desktop behavior.

Preconditions:

- Phase 2 focused checks pass.

Source owners: `project-specs/cannon-golf/PRD.md`, `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/DECISIONS.md`, `tests/capture_cannon_golf_frame.gd`, this contract

- [x] **3.1** Current records state the accepted ball/pace/zoom contract.
  - Change: update the prototype speed/radius and meaningful zoom requirements without adding normal-play status copy.
  - Accept: active specs and decisions no longer claim `14..60 m/s` or tolerate weak per-input zoom.
- [x] **3.2** Rendered, source, and Windows release gates pass.
  - Change: capture default, close-zoom, far-zoom, and live-follow ball states; inspect pixels; run the focused suite, verify, diff check, export, and built executable smoke.
  - Accept: real renders show an unclipped larger ball and materially distinct bounded zoom states; every command exits zero without Godot script/runtime errors.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Phase 1 | Run `cannon_golf_camera_test.gd` and `cannon_golf_input_test.gd` with the verified Godot 4.7.1 console binary | Task 1 checks are implemented | A camera/input owner changes |
| Phase 2 | Run `cannon_golf_ballistics_test.gd`, `cannon_golf_physics_test.gd`, `cannon_golf_goal_test.gd`, `cannon_golf_range_test.gd`, and `cannon_golf_solution_test.gd` | Task 2 checks are implemented | A ball/ballistics/course owner changes |
| UI gate | Use `tests/capture_cannon_golf_frame.gd` for planning, zoom-close, zoom-far, and follow states at 1280x720 and inspect each PNG | Visible inputs are complete | A visible camera/ball input changes |
| Final source gate | Run `scripts/test-cannon-golf.ps1`, `scripts/verify.ps1`, and `git diff --check` | All tasks and rendered evidence pass | A source/final-gate input changes |
| Release gate | Export `Windows Desktop` to `builds/windows/CannonGolfPrototype.exe`, then run it hidden with `--headless --quit-after 3` and require zero exit | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest check that proves the current task and each broader gate once at its named cadence.
- Rerun a failed check only after a relevant implementation change or a new hypothesis.
- Do not repeat a passing check unless its relevant input changes.
- Update task checkboxes and the progress pointer together after each checkpoint.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch and revise this contract before continuing | Do not choose a new input, physics, goal, terrain, dependency, or UX contract during implementation |
| A retained solution does not clear under temporal scaling | Search only nearby integer power values at the existing certified horizontal/elevation, choose the lowest deterministic live clear, and record it | Do not change goal tolerances, terrain, temporal scaling, or speed endpoints to manufacture a pass |
| `0.75` radius cannot remain in the existing basin | Report the exact basin/containment failure and stop | Do not silently separate visible and physical radius or enlarge the goal |
| Stronger zoom clips HUD or produces an invalid pose | Keep the locked 22% one-step effect and tighten only the extreme bound to the closest valid value | Do not weaken one-step effect below the acceptance threshold |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: Task 3.2 production evidence. Default, close-zoom, far-zoom, and live-follow captures at 1280x720 were visually inspected without HUD clipping; the larger ball and distinct zoom range are readable. All 15 focused tests, import/parse/startup verification, `git diff --check`, Windows release export, and the built executable smoke exited zero.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named validation gate passes.
- Current product records own the durable behavior and this plan status is `done`.
- No placeholder or unresolved material decision remains.

Replan when:

- A material discovery invalidates the locked camera, physics, goal, course, ownership, or validation contract.

Do not replan or stop for:

- Implementation-local signal wiring or nearby solution-power recertification already contained by this contract.
- A passing check whose relevant inputs have not changed.
