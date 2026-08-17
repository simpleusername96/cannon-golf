---
type: plan
status: done
created: 2026-08-18
scope: Replace Cannon Golf's constrained Cannon exploration with a subject-centered orbit viewer
related:
  - .agents/research/cannon-golf/CANNON_CAMERA_CONTROLS.md
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Cannon Orbit Camera - Execution Contract

Cannon view will become a direct, subject-centered 3D orbit viewer. The selected
cannon stays the initial interest, aim remains independent, and Overview is
entered only by explicit selection.

## Purpose

- Objective: replace the rejected limit-tuned local camera with a recognizable
  orbit/pan/dolly interaction model borrowed from 3D viewers and vehicle-camera
  conventions.
- Deliverable: updated product rules, camera/input implementation, focused
  regressions, rendered evidence, and one scoped commit.
- Completion state: focused and full automated validation pass, representative
  Cannon renders show stable direct exploration, and the task diff passes the
  repository quality audit.

## Scope and Boundaries

In scope:

- Cannon planning-camera pivot, orbit, pan, zoom, reset, follow restore, input
  mapping, help copy, specifications, tests, and capture states.
- Terrain-safe camera placement and course-bound interest clamping.

Out of scope:

- Overview camera behavior, ballistics, aim controls, Fire/Start design, quick
  retry, click-highlight diagnosis, course content, saves, and dependencies.

Constraints and invariants:

- Left-drag orbits; right-drag pans; wheel zooms; arrow keys pan.
- Cannon camera input never selects or mutates Overview.
- Camera input never changes cannon aim, elevation, power, source, goals, or
  projectiles.
- Cannon setup edits do not move the explored camera.
- Explicit Cannon/reset/source selection restores the authored pose.
- Shot Follow restores the exact explored Cannon state.
- Unrelated untracked files remain untouched.

## Discovery Closure

| Concern | Local evidence | External evidence | Locked decision |
| --- | --- | --- | --- |
| Unclear orbit | Current pivot is `12 m` along the launch ray | Vehicle cameras separate look from gun; 3D viewers orbit an interest | Orbit a stable selected-cannon interest, independent of barrel aim |
| Arbitrary restriction | Pan/yaw/pitch/zoom use unrelated local hard limits | Viewer cameras use continuous yaw, non-flipping pitch, bounded dolly | Full yaw, safe pitch/distance, pan interest within course bounds |
| Shaking/lag | Planning interpolation chases every input update | Godot documents added inertia as added latency | Snap direct Cannon manipulation; retain authored transition behavior |
| Input grammar | Current left pan/right orbit is project-specific | Common viewer schemes separate orbit, pan, and wheel zoom | Left orbit, right pan, wheel dolly; arrow pan fallback |
| Mode leakage | Earlier revisions converted exploration to Overview | Artillery/map presentation is an explicit separate mode | Overview changes only through its button or `1` shortcut |

Rejected alternatives:

- Increase current limits again: preserves the wrong forward-ray pivot model.
- First-person free-fly: conflicts with aim keys and loses the cannon as context.
- RTS edge/WASD camera: conflicts with setup controls and duplicates Overview.
- Camera inertia during drag: preserves the reported lag and shaking.

Readiness statement:

- Product semantics, interaction mapping, owners, validation paths, and recovery
  behavior are fixed. No dependency, persistence, or owner decision is open.

## Tasks

### Phase 1: Promote the accepted camera contract

- [x] **1.1** Update FR-8, design rules, and the decision log.
  - Accept: all three define a cannon-centered orbit viewer, exact mouse mapping,
    direct response, independent aim, explicit Overview, and reset behavior.

### Phase 2: Replace the camera model

- [x] **2.1** Replace the forward-ray focus and radius-limited exploration state.
  - Accept: the authored pose looks toward a stable cannon interest; yaw wraps,
    pitch cannot flip, zoom cannot cross the interest, and pan is clamped only
    by prepared course bounds.
- [x] **2.2** Make direct Cannon input immediate and terrain safe.
  - Accept: each accepted orbit, pan, arrow, or wheel input updates the rendered
    pose in the same frame without entering terrain or switching views.
- [x] **2.3** Swap the Cannon mouse grammar and update visible help.
  - Accept: left-drag orbits and right-drag pans in Cannon; Overview keeps its
    existing mapping; click without committed drag remains inert.

### Phase 3: Lock regressions and visual behavior

- [x] **3.1** Replace limit-based tests with orbit-viewer behavioral tests.
  - Accept: tests cover stable pivot, full yaw, pitch/distance clamps, course-
    bound pan, immediate response, setup independence, reset, and follow restore.
- [x] **3.2** Capture representative authored and explored Cannon states.
  - Accept: images show the cannon-centered base pose and a materially different
    nearby perspective without a top-view jump, transition shake, or clipping.

### Phase 4: Finalize

- [x] **4.1** Run focused checks and the full repository validation suite once.
  - Accept: all commands exit zero; failures caused by task-owned changes are
    corrected before another final run.
- [x] **4.2** Run the task-diff quality audit, mark this plan done, and commit.
  - Accept: no competing owner, stale contract, reachable failure, or unrelated
    staged file remains; commit body records implementation and validation.

## Validation and Rework Controls

- During implementation, run the camera and input tests through
  `scripts/invoke-cannon-golf-validation.ps1`.
- After task-owned behavior stabilizes, capture only the base Cannon and
  explored Cannon states needed for comparison.
- Run `scripts/test-cannon-golf.ps1` once as the final broad gate. Repeat only
  after a material task-owned correction.
- Stop and revise this contract if a prepared course cannot support a stable
  cannon-centered pivot without changing terrain or ballistics.

## Predetermined Contingencies and Change Control

- If a pan target leaves the prepared terrain rectangle, clamp its horizontal
  coordinates to the course content bounds and keep its height terrain-derived.
- If the collision sweep cannot admit the desired camera point, keep the last
  valid point or shorten the boom; do not raise into a top-like sky view.
- If help copy cannot express different Overview and Cannon mouse mappings in
  the current compact surface, show the Cannon mapping contextually rather than
  adding a permanent panel.
- Any change to aim keys, Overview behavior, terrain, or retry requires a plan
  revision because it is outside this contract.

## Progress and Next Steps

- All phases are complete. There is no remaining task in this execution
  contract.
- The quality audit kept camera math in `course_camera_rig.gd`, input dispatch
  in `cannon_golf_game.gd`, and contextual control copy in the HUD owner. It
  found and corrected one misleading shared reset tooltip; no competing owner,
  reachable task-owned failure path, or unrelated cleanup remains.

## Verification

- Focused camera, physical-input, and UI contract tests passed through
  `scripts/invoke-cannon-golf-validation.ps1`.
- The complete `scripts/test-cannon-golf.ps1` suite passed in 150.6 seconds.
- Native 1280 by 720 captures were inspected at
  `.agents/evidence/cannon-golf/2026-08-18-cannon-orbit-camera/cannon.png` and
  `cannon-explored.png`.
- `git diff --check` passed after the final contextual-tooltip correction.

## Completion and Stop Conditions

- Finish only after every task and final gate passes, the plan status is `done`,
  and the scoped commit contains only task-owned files.
- Stop before unrelated cleanup, retry changes, click-highlight changes, or a
  new dependency.
