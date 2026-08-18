---
type: plan
status: done
created: 2026-08-18
scope: Make Cannon an authored camera coordinate followed by ordinary shared planning navigation
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Common Planning-Preset Navigation - Execution Contract

Selecting Cannon moves the planning camera to its authored medium-distance
coordinate. After that selection, Cannon has no persistent subject lock or
separate exploration mode: all planning presets use one navigation state and
the same orbit, pan, dolly, bounds, collision, and response rules.

## Purpose

- Objective: let the player move away from the cannon as freely as from every
  other planning coordinate.
- Deliverable: canonical camera semantics, one shared exploration owner,
  regression tests, and rendered proof that the cannon can leave screen center.
- Completion state: all tasks, focused checks, rendered inspection, the full
  suite, and the diff-scoped quality audit pass.

## Scope and Boundaries

In scope:

- Planning-camera state and input after selecting Cannon or Overview.
- Cannon reset/reselection and Shot Follow return behavior.
- Camera specifications, tests, and one off-center exploration capture.

Out of scope:

- The accepted `80/12/45 m` Cannon authored coordinate, aiming, ballistics,
  terrain generation, HUD layout, and Shot Follow behavior while a ball flies.

Invariants:

- Preset selection may choose a base coordinate, focus, FOV, and presentation.
- Once selected, a preset cannot own distinct input sensitivity, travel limits,
  zoom endpoints, interpolation, collision admission, or exploration storage.
- Pan can move the active focus anywhere inside prepared course bounds; the
  cannon is not required to remain centered or visible.
- Explicit preset selection and reset restore that preset's authored coordinate.

## Discovery Closure

| Concern | Local evidence | Locked decision |
| --- | --- | --- |
| Persistent Cannon lock | `course_camera_rig.gd` owns separate `cannon_pan_offset`, `cannon_zoom`, and `cannon_orbit_degrees` plus Cannon-only sensitivities and limits | Delete the Cannon exploration state and all input branches; retain only its authored base pose |
| Different input response | `cannon_golf_game.gd` snaps direct manipulation only in Cannon | Use the same direct planning-camera response for every preset |
| Centered subject after input | Cannon focus is always `_cannon_anchor + cannon_pan_offset` | The authored anchor is only the zero-state base; shared pan is free to move focus to the course bounds |
| Follow return | Snapshots currently store two competing exploration states | Store and restore one active `pan/zoom/orbit` state |
| Initial framing | D-059 and the accepted LV5 capture validate `80/12/45 m` | Preserve the initial framing exactly |

Rejected alternatives:

- Increase Cannon-only pan distance: retains the separate mode and inconsistent
  sensitivity that caused the defect.
- Automatically switch to Overview on input: changes the selected preset and
  contradicts the requested coordinate-preset model.
- Keep a hidden cannon pivot while permitting wider pan: still makes the
  cannon semantically special after selection.

## Tasks

### Phase 1: Canonicalize the one-owner contract

- [x] **1.1** Record that Cannon is only an authored coordinate and that all
  post-selection navigation state and behavior are shared.

### Phase 2: Remove Cannon-specific navigation

- [x] **2.1** Replace separate Cannon pan, orbit, zoom, limits, snapshots, and
  terrain admission with the common planning-camera owner.
- [x] **2.2** Apply the same direct input response to every planning preset.
- [x] **2.3** Update camera, input, and capture regression coverage, including
  proof that pan can place the cannon outside the central screen region.

### Phase 3: Validate real behavior

- [x] **3.1** Run the focused camera and physical-input tests.
- [x] **3.2** Capture and inspect Cannon after meaningful pan/orbit/dolly input;
  accept only if terrain remains navigable and the cannon is not center-locked.

### Phase 4: Finalize

- [x] **4.1** Run the full suite, diff check, and task-scoped quality audit.
- [x] **4.2** Mark this contract done and commit only task-owned files.

## Validation and Rework Controls

- Inner loop: run `cannon_golf_camera_test.gd` and
  `cannon_golf_input_test.gd` through the bounded validation wrapper after the
  implementation and tests change.
- Render gate: run `capture_cannon_golf_frame.gd` for the explored Cannon state
  only after focused checks pass; inspect the resulting image at native size.
- Final gate: run `scripts/test-cannon-golf.ps1` once after rendered acceptance,
  followed by `git diff --check` and the diff-scoped quality audit.
- Do not rerun a passing gate until a relevant input changes.

## Predetermined Contingencies and Change Control

- If a common zoom formula cannot retain both authored framing and whole-course
  reach, keep the shared zoom value and endpoints but resolve distance from each
  authored base to the same close and whole-course endpoint contract.
- If shared collision admission blocks a valid authored coordinate, correct the
  common admission path; do not add a Cannon exception.
- Any requested change to the accepted initial Cannon framing requires a plan
  revision before implementation.

## Progress and Next Steps

- Current phase: complete.
- Next task: none.
- Focused camera, physical-input, session, and multi-goal checks passed.
- The complete Cannon Golf suite and `git diff --check` passed after the final
  correction.
- Rendered evidence:
  `.agents/evidence/cannon-golf/2026-08-18-common-preset-navigation/cannon-explored-off-center.png`.
- Diff-scoped quality audit found no competing navigation owner, reachable
  regression, or task-external correction.
- Stop condition: every checkbox is complete and the committed diff contains no
  Cannon-specific post-selection navigation owner.
