---
type: plan
status: done
created: 2026-08-18
scope: Remove the Cannon center reticle and publish the completed local history
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Remove Cannon Reticle and Push - Execution Contract

The orange center dot and four surrounding chevrons will no longer appear in
Cannon view. The obsolete HUD component and its active contracts will be
removed, the affected rendered state will be verified, and the completed local
commits will be pushed from `main` to `origin/main`.

## Purpose

- Objective: remove the unwanted center-screen Cannon reticle completely.
- Deliverable: retired component, aligned specifications/tests, rendered proof,
  a scoped commit, and a successful push.
- Completion state: focused checks, Cannon render, full suite, diff audit,
  commit, and remote push pass.

## Scope and Boundaries

In scope:

- `AimReticle` scene/script ownership, HUD visibility code, active product copy,
  the exact-down capture contract, and the stale camera-reset tooltip.
- Publishing local `main` through the configured `origin` remote.

Out of scope:

- The world-space partial aim curve, barrel, cannon pose, camera controls,
  trajectory behavior, unrelated untracked files, and the user-owned Godot
  process already running.

Constraints:

- Cannon view retains the physical barrel and existing compact world-space aim
  guide; only the center HUD marker is removed.
- No replacement marker is introduced.
- Push is non-force and targets `origin/main`.

## Discovery Closure

| Concern | Verified owner and behavior | Locked decision | Tasks |
| --- | --- | --- | --- |
| Visual owner | `AimReticle` scene node runs `cannon_aim_reticle.gd` and draws the exact orange dot/four chevrons | Delete the node and tracked script, not merely hide them | 1.1 |
| Visibility owner | `CannonGolfHUD._refresh_camera_buttons` shows the node only in Cannon planning view | Remove the field and toggle | 1.1 |
| Active contracts | PRD, design rules, D-044/D-047 lineage, and capture assertions require the reticle | Add a current decision and remove active spec requirements; preserve superseded history | 1.2 |
| Publication | Current branch is `main`; push remote is `origin` | Commit only task-owned files, then `git push origin main` | 2.3 |

## Tasks

### Phase 1: Remove the reticle contract and component

- [x] **1.1** Delete the scene node, HUD toggle, and tracked drawing script.
- [x] **1.2** Remove the reticle from active PRD/design/capture expectations and
  record its retirement in the decision log.
- [x] **1.3** Correct the camera-reset tooltip to the already accepted
  left-move/right-orbit mapping.

### Phase 2: Verify and publish

- [x] **2.1** Run focused UI/camera checks and render Cannon view without the
  center marker.
- [x] **2.2** Run the full suite, diff check, and task-scoped quality audit.
- [x] **2.3** Mark this plan done, commit task-owned files, and push `main` to
  `origin/main` without force.

## Validation and Rework Controls

- Inner loop: bounded UI-contract and camera tests after implementation.
- Render gate: capture `cannon` at 1920 by 1080 and inspect the center pixels.
- Final gate: full suite, `git diff --check`, scoped audit, commit, and
  `git push origin main`.
- Do not rerun a passing gate until a relevant input changes.

## Predetermined Contingencies and Change Control

- If the exact-down capture still needs a finite-guide assertion, retain its
  world halo and camera-basis checks while deleting only the reticle clause.
- If push is rejected because remote history advanced, stop and report; do not
  force-push, merge, or rebase without a new decision.

## Progress and Next Steps

- Canonical progress: this checklist.
- Current phase: Complete.
- Next task: None.
- Last completed gate: scoped commit `df243b3` and non-force push to
  `origin/main`, after the full 24-test regression suite, 1920 by 1080 Cannon
  render inspection, diff check, and task-scoped quality audit.

## Completion and Stop Conditions

Complete when all checks pass, no runtime or active spec reference to
`AimReticle` remains, the plan is `done`, and `origin/main` contains the final
commit.
