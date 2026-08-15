---
type: plan
status: done
created: 2026-08-15
scope: Floating yaw-and-elevation aim halo and gentler ten-course spatial scale
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Gentle Course Scale and Aim Halo

## Purpose

Replace the launcher-attached direction wedge with a slightly elevated base halo
that shows both yaw and elevation. Stretch every prepared course horizontally by
1.5 while preserving its authored vertical relief, then rebalance readable object
size and ballistic reach so the larger spaces remain playable.

## Scope and Boundaries

In scope:

- A dedicated aim-halo visual owner with a floating horizontal yaw ring and a
  laterally offset elevation arc.
- A 1.5 horizontal-only multiplier applied to the accepted ten-course scale
  progression, with the existing relief targets unchanged.
- Ballistic speed multiplied by `sqrt(1.5)`, launcher visual scale increased from
  1.6 to 2.0, and the already selected 2.0 m ball radius retained.
- Canonical product records, focused contract tests, all ten prepared artifacts,
  and rendered checks for early, middle, and late courses.

Out of scope:

- Changing course count, goal order, device rules, terrain relief targets, or the
  connected-heightfield requirement.
- A camera-system redesign or an exact trajectory predictor.
- Further goal or ball enlargement unless rendered evidence proves a concrete
  readability failure.

## Discovery Closure

- The accepted course progression is horizontal scale
  `1.00, 1.00, 1.05, 1.10, 1.15, 1.20, 1.28, 1.35, 1.42, 1.50`; the new explicit
  progression is `1.50, 1.50, 1.58, 1.65, 1.73, 1.80, 1.92, 2.03, 2.13, 2.25`.
- Existing relief targets remain `60, 65, 80, 90, 100, 112, 124, 136, 148, 160`
  metres. Horizontal stretch therefore reduces slope without flattening the
  authored height hierarchy.
- Projectile range at a fixed launch angle scales approximately with speed
  squared. `sqrt(1.5)` preserves the useful power-percent range after the 1.5
  horizontal stretch.
- The current center-to-forward amber prism reads as a second barrel. It is
  retired; the replacement keeps angular guidance spatially separate from the
  launcher silhouette.

## Tasks

- [x] Record the spatial-scale and aim-halo contract in canonical specs and add
  focused failing contract assertions for the locked values and responsibilities.
- [x] Implement the aim-halo component, integrate it with launcher yaw/elevation,
  and pass its focused contract tests.
- [x] Apply the horizontal and ballistic scale contract, regenerate all ten
  prepared artifacts once, and pass terrain/build/gameplay contract checks.
- [x] Capture and inspect rendered early/middle/late courses plus a close halo
  view, run the task-scoped quality audit and final gates, mark this plan done,
  and commit only task-owned changes.

## Validation and Rework Controls

- Focused script checks use
  `scripts/invoke-cannon-golf-validation.ps1 -Script <test> -TimeoutSeconds 60`.
- Regenerate once with
  `scripts/invoke-cannon-golf-validation.ps1 -Script res://scripts/bake_cannon_golf_courses.gd -TimeoutSeconds 90`.
- After regeneration, run ballistics, terrain, course-build, goal, camera, app-flow,
  and world-environment checks whose relevant inputs changed.
- Render course indices 0, 3, and 9 in planning view and at least one close view
  where yaw and elevation indicators are simultaneously visible.
- Do not rerun a passing focused check unless its relevant input changes.
- Stop a repeated visual tweak after five failed attempts and report the exact
  remaining defect and evidence.

## Predetermined Contingencies and Change Control

- If generation cannot certify a leg under the locked scale contract, adjust only
  setup sampling or power endpoints within the same horizontal, relief, and speed
  contract. Do not shrink the courses or lower their relief.
- If the elevation arc overlaps the barrel, move the arc laterally or raise the
  halo. Do not restore a center-origin line or wedge.
- If the new launcher visual clips first-person view, hide the halo in that mode
  and preserve the HUD reticle; do not move the physical muzzle.
- Any change to the 1.5 multiplier, unchanged relief policy, `sqrt(1.5)` speed
  compensation, or 2.0 m ball radius requires a revised owner decision before
  implementation continues.

## Progress and Next Steps

- Completed: canonical PRD, design rules, and D-039 lock the scale contract. A
  dedicated `CannonGolfAimHalo` now owns the floating ring, compact yaw tick,
  dotted elevation arc, and elevation bead; the old wedge is removed and the
  focused ballistics/halo contract passes.
- Completed: all ten horizontal scales and `sqrt(1.5)` ballistic compensation
  are applied. All prepared artifacts regenerated in under one second each;
  terrain, course-build, and the full 10-course physical-goal contract pass.
- Completed: rendered courses 0, 3, and 9 plus a close halo view show the longer
  terrain runs and distinct yaw/elevation instrument. Camera, app-flow,
  world-environment, import, editor-parse, and main-scene startup gates pass.
  The diff-scoped quality audit found no remaining task-owned boundary defect.
- Next: none; implementation and acceptance are complete.

## Completion and Stop Conditions

Complete only when all four tasks are checked, all ten current prepared artifacts
load and build, the named focused gates pass, rendered evidence shows a floating
yaw/elevation halo without a second-barrel silhouette, and the task-owned commit
is created without unrelated menu/theme changes.
