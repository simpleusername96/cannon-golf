---
type: plan
status: done
created: 2026-08-18
scope: Replace model-viewer mouse mapping with one shared map-style planning-camera mapping
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Map-Style Camera Input - Execution Contract

Every planning coordinate will use map-style mouse navigation: left-drag moves
the terrain, right-drag or Shift+left-drag orbits, and the wheel changes
distance. The existing common camera rig, drag threshold, bounds, collision,
reset, and Shot Follow return behavior remain intact.

## Purpose

- Objective: make the primary terrain-navigation gesture discoverable without
  requiring right-click.
- Deliverable: remapped input dispatch, truthful control help and canonical
  specifications, physical-input regression coverage, and rendered evidence.
- Completion state: focused input/camera checks, one controls-panel render, the
  full suite, diff audit, and a scoped commit pass.

## Scope and Boundaries

In scope:

- Mouse-button-to-navigation-action mapping for every planning preset.
- Drag-action latching, help copy, specifications, and tests.

Out of scope:

- Camera pose mathematics, sensitivities, bounds, zoom endpoints, touch input,
  controller input, aiming, ballistics, HUD structure, and terrain.

Constraints and invariants:

- Left-drag pans; right-drag and Shift+left-drag orbit; wheel zooms.
- The action is latched at mouse-down so modifier changes cannot mix pan and
  orbit inside one gesture.
- Sub-threshold clicks do not move the camera.
- Cannon and Overview use the same mapping and common navigation owner.

## Discovery Closure

| Requirement | Verified owner and behavior | Evidence | Locked decision | Tasks |
| --- | --- | --- | --- | --- |
| Current mapping | `CannonGolfGame._unhandled_input` routes left to orbit and right to pan | Source and physical-input test | Swap the primary actions in the dispatcher | 1.1, 2.1 |
| Genre fit | Three.js MapControls uses left pan, right or modified-left orbit; Mapbox uses drag pan and right/Ctrl drag rotate | Official Three.js and Mapbox documentation reviewed on 2026-08-18 | Adopt the map-control pattern without a new camera system | 1.1 |
| One-button access | Current drag state records only the button | `_begin_planning_drag` and threshold owner | Latch a `PAN` or `ORBIT` action at mouse-down; Shift+left selects orbit | 2.1, 2.2 |
| Discoverability | HUD currently says only `L / R Drag` and `Orbit / move view` | `cannon_golf_hud.gd`, HUD scene | Show the new action order; keep the panel compact | 2.3 |

Rejected alternatives:

- Infer pan versus orbit from drag direction: diagonal movement is ambiguous.
- Switch behavior based on terrain versus sky under the cursor: the result
  changes unexpectedly near silhouettes and is harder to test.
- Add a new camera controller: the common rig already owns both operations.

External evidence and applicability:

- [Three.js MapControls](https://threejs.org/docs/pages/MapControls.html) is the
  closest interaction analogue: it maps left-drag to pan, right or
  modifier+left to orbit, and the wheel to dolly for map-like surfaces.
- [Mapbox interaction handlers](https://docs.mapbox.com/mapbox-gl-js/api/handlers/)
  independently use ordinary drag for pan and right or modified drag for
  rotation. Its geographic projection details are not imported.
- [Three.js OrbitControls](https://threejs.org/docs/pages/OrbitControls.html)
  documents the current left-orbit/right-pan mapping, but targets object
  inspection and is rejected for this terrain-navigation task.

Readiness statement:

- Product behavior, ownership, scope, and validation are fixed.
- Godot 4.7.1 and repository validation/capture wrappers are available.
- Remaining details are implementation-local.

## Tasks

### Phase 1: Canonicalize the map-style mapping

- [x] **1.1** Update PRD, design rules, and the decision record to define left
  pan, right or Shift+left orbit, wheel zoom, and unchanged click behavior.

### Phase 2: Remap and guard physical input

- [x] **2.1** Latch one planning drag action at mouse-down and dispatch both
  buttons through it.
- [x] **2.2** Update physical-input and camera-contract tests for primary pan,
  primary orbit, modified-left orbit, follow return, and bounded travel.
- [x] **2.3** Make the controls panel state the new mapping without expanding
  its structure.

### Phase 3: Validate and finalize

- [x] **3.1** Run focused input, camera, and UI-contract checks.
- [x] **3.2** Render and inspect the controls panel, then run the full suite and
  diff-scoped quality audit.
- [x] **3.3** Mark this contract done and commit only task-owned files.

## Validation and Rework Controls

- Inner loop: run `cannon_golf_input_test.gd`, `cannon_golf_camera_test.gd`, and
  `cannon_golf_ui_contract_test.gd` through the bounded wrapper after their
  relevant inputs change.
- Render gate: capture the `shortcuts` state at 1280 by 720 after focused checks
  pass and inspect it at native size.
- Final gate: run `scripts/test-cannon-golf.ps1`, `git diff --check`, and the
  diff-scoped quality audit once after rendered acceptance.
- Rerun a passing check only after a relevant input changes.

## Predetermined Contingencies and Change Control

- If modifier metadata is unavailable on mouse-down, use right-drag orbit and
  omit the alias rather than infer intent from motion.
- If the compact help row clips, shorten the key copy; do not restructure the
  panel for this mapping change.
- A request for one unmodified gesture to heuristically perform both operations
  requires a new interaction decision before implementation.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: full suite, diff check, rendered inspection, and
  diff-scoped quality audit.
- Rendered evidence:
  `.agents/evidence/cannon-golf/2026-08-18-map-style-camera-input/shortcuts-1280x720-final.png`.
- The physical-input check passed again after the final readability-only code
  correction.

## Completion and Stop Conditions

Complete when every checkbox and named gate passes, the plan is marked `done`,
and no model-viewer mapping remains in active specs, help copy, or physical
input tests.
