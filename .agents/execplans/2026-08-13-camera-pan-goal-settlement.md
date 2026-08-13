---
type: plan
status: done
created: 2026-08-13
scope: Restore direct terrain panning and let late active-goal arrivals complete settlement
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-13-longitudinal-relay-course.md
---

# Camera Pan and Goal Settlement - Execution Contract

Restore player-controlled camera focus movement and correct the relay goal race
without changing launch physics, settlement thresholds, course resources, or
the accepted bounce-out failure rule.

## Purpose

- Objective: make left drag translate the terrain view across the bounded course
  and prevent the general flight timeout from deleting a ball already settling
  inside the active goal.
- Deliverable: camera/input/session fixes, truthful shortcut copy, and regression
  coverage for the deep relay course.
- Completion state: direct input, camera framing, relay state, real-physics
  witnesses, performance, source verification, rendered UI, and Windows smoke
  pass; changes are committed and this plan is `done`.

## Scope and Boundaries

In scope:

- Left-drag direct-grab panning, right-drag orbit, arrow-key pan, bounded focus,
  panned local framing, and matching compact control copy.
- Timeout deferral only while a live ball is contained by the active goal's
  settlement/rebound region.

Out of scope:

- Terrain, course, launcher, ballistics, thresholds, result UI, and inactive-goal
  behavior changes.

Constraints and invariants:

- Contact alone is not success. A ball must remain contained and meet the
  existing safe-motion dwell threshold; leaving the goal still fails.
- Fire, retry, Tab, Home, zoom, confirmed balls, and both legacy courses retain
  their current contracts.
- No dependency, destructive action, or user-approval-gated action is required.

## Discovery Closure

| Concern | Verified owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Fixed camera center | `CannonGolfGame` routes left drag to `CourseCameraRig.orbit`; the rig frames unshifted bounds | Source trace and failing user report | Left drag pans by ray/plane direct grab; right drag preserves orbit | 1.1 |
| Pan neutralized by framing | `_zoom_adjusted_frame_bounds` retains the authored bounds | Camera test fails when true pan crops the old whole-course assertion | Translate the local frame with bounded pan; full overview remains the zoom-out contract | 1.1, 2.1 |
| Goal timeout race | `CannonGolfBall` emits timeout at 10 seconds and `CannonGolfGame` removes it even after goal entry | Session source and focused relay regression | Active-goal containment/settlement outranks timeout; bounce-out remains failure | 1.2 |

Readiness statement: product behavior, owners, interaction mapping, failure rules,
and validation commands are fixed. Remaining work is implementation-local.

## Tasks

### Phase 1: Restore both user-visible behaviors

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`,
`tests/cannon_golf_input_test.gd`, `tests/cannon_golf_relay_test.gd`

- [x] **1.1** Make terrain drag move the planning focus.
  - Change: use left drag for bounded direct-grab pan, right drag for orbit, move
    the local framing window with pan, and update the existing control hint.
  - Accept: physical input moves the deep-relay focus by more than 20 metres,
    stays inside content bounds, preserves setup, and keeps right-drag orbit.
  - Evidence: `cannon_golf_input_test.gd` and
    `cannon_golf_camera_test.gd` passed with direct-grab pan, bounded focus,
    translated local framing, and full-course maximum zoom-out.
- [x] **1.2** Let a late ball finish active-goal settlement.
  - Change: defer timeout while the ball is contained by the active goal; retain
    the existing settlement and rebound-out checks.
  - Accept: the relay regression confirms goal 1 after a timeout during safe
    containment. Evidence: `cannon_golf_relay_test.gd` passed.

### Phase 2: Align guards and complete delivery

Preconditions: Phase 1 task checks pass.

Source owners: `tests/cannon_golf_camera_test.gd`,
`tests/capture_cannon_golf_frame.gd`, affected focused tests,
`scripts/verify.ps1`, this contract

- [x] **2.1** Replace the obsolete whole-course-after-pan assertion.
  - Change: assert the translated local frame after pan and preserve the full
    route assertion at maximum overview zoom.
  - Accept: camera, input, relay, solution, and performance tests pass.
  - Evidence: all five named headless tests passed after the final camera input
    change; real-physics relay witnesses and planning-camera performance remain
    valid.
- [x] **2.2** Complete rendered, source, audit, and package gates.
  - Accept: shortcut copy fits; source verification, `git diff --check`, scoped
    quality audit, Windows export/smoke, and task commit pass.
  - Evidence: Korean shortcut and panned gameplay captures passed at 1280x720
    without clipping; `scripts/verify.ps1`, `git diff --check`, responsibility
    and failure-path audit, Windows release export, and built-app smoke passed.
    Implementation commit: `240fdc5`.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Godot headless `cannon_golf_input_test.gd` and `cannon_golf_relay_test.gd` | Input/session source changes | Their inputs change |
| Phase gate | Godot headless camera, solution, and performance tests | Phase 1 passes | Camera/session inputs change |
| Final gate | `scripts/verify.ps1`, `git diff --check`, rendered capture, release export, built-app smoke | All targeted tests and audit pass | A final-gate input changes |

## Predetermined Contingencies and Change Control

- If direct-grab ray intersection fails in side view, use a camera-facing plane
  through the current focus; do not restore fixed-center left-drag orbit.
- If a timed-out contained ball later exits, retain `bounced_out`; do not confirm
  on contact or weaken the safe-motion dwell threshold.
- If any material requirement needs terrain, physics constants, or course data
  changes, stop and revise this contract before expanding scope.

## Progress and Next Steps

- Canonical progress: task checkboxes above.
- Current phase: complete.
- Next task: none.
- Last completed gate: source verification, rendered UI and panned-view checks,
  Windows release export, built-app smoke, and implementation commit passed.
- Update rule: record evidence and advance this pointer with each checkpoint.

## Completion and Stop Conditions

Complete when every task and named gate passes, the task-owned changes are
committed, and this file is marked `done`. Replan only if the locked interaction
or settlement contract becomes invalid; do not rerun passing gates without a
relevant input change.
