---
type: plan
status: done
created: 2026-08-18
scope: Reframe the authored Cannon camera preset as a medium-distance terrain-reading viewpoint
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Cannon Preset Framing - Execution Contract

The authored Cannon preset will move from the current close-up to a medium-
distance rear-upper coordinate comparable to the user-provided LV5 reference:
the selected cannon remains visible near screen center while the surrounding and
forward terrain supplies most of the frame. Cannon remains an ordinary planning-
camera preset with the shared orbit, pan, and dolly behavior accepted in D-058.

## Purpose

- Objective: make selecting Cannon move to a useful terrain-reading coordinate,
  not a close inspection shot or a separate navigation mode.
- Deliverable: updated authored pose constants, canonical framing rules,
  regression coverage, and native rendered comparisons at the affected sizes.
- Completion state: the completion criteria below, focused camera/input checks,
  rendered inspection, the full project suite, and the diff quality audit pass.

## Scope and Boundaries

In scope:

- The reset/reselection coordinate for the Cannon planning preset.
- Cannon preset framing requirements in PRD, design rules, and the decision log.
- Camera tests and capture evidence for LV5 at 1920 by 1080 and a representative
  1280 by 720 course.

Out of scope:

- Camera input mapping, exploration entitlement, Overview framing, Shot Follow,
  aim cues, terrain, ballistics, HUD layout, quick retry, and click indicators.

Constraints and invariants:

- Cannon is a coordinate preset. Selecting it changes the authored camera pose;
  it does not enter a restricted mode.
- Shared left-orbit, right-pan, wheel-dolly, arrow-pan, course-bound travel, and
  explicit preset switching remain unchanged.
- Aim, elevation, and power edits do not move the selected camera.
- Cannon reset, Cannon reselection, and launcher-source selection restore the
  same authored rear-upper framing.
- Terrain collision, exact follow restoration, and unrelated user files remain
  intact.

Destructive or irreversible actions:

- None.

Exact actions requiring owner or user approval:

- None within this contract. Any change to camera controls, terrain, or HUD
  structure requires a contract revision.

## Completion Criteria

The implementation is complete only when all of the following are true:

- The authored Cannon camera-to-interest distance is between `80 m` and `110 m`.
- At 1920 by 1080 on LV5, the selected cannon/launcher body occupies roughly
  `5%` to `10%` of viewport height rather than the current roughly `28%`.
- The cannon interest projects within the central `45%` to `55%` of viewport
  width and height; the frame is terrain-led rather than cannon-led.
- The initial camera remains rear-upper and perspective-readable: its view
  direction stays at least `45°` away from straight down.
- Nearby and forward terrain are visibly present around the cannon; authored
  terrain may occlude a distant goal, but blank ground or a cannon-only close-up
  fails.
- Cannon selection does not change shared exploration range, input mapping,
  launch setup, selected source, or Shot Follow restoration.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Reference composition | The supplied 1920 by 1080 LV5 image places the cannon near `(50%, 49%)`, at roughly `6%` viewport height, with terrain dominating the frame | User-provided `2026-08-18 07 19 15.png` inspected at native size | Treat the image as the visual target, not as a request for new controls or a mode | 1.1, 2.1 |
| Current close-up | `course_camera_rig.gd` uses `16 m` back, `5 m` side, and `8 m` high: approximately `18.7 m` from the cannon | Fresh `baseline-lv5.png` at 1920 by 1080 shows the launcher at roughly `28%` viewport height | Use `80 m` back, `12 m` side, and `45 m` high: approximately `92.8 m`, with the cannon interest kept at screen center | 1.1, 2.1 |
| Preset semantics | D-058 and current input dispatch already make all planning viewpoints coordinate presets with shared controls and course-scale reach | Commit `3b93e0a`, PRD FR-8, focused camera/input tests | Change only the authored Cannon pose and compatible zoom endpoint; preserve common navigation | 1.2, 2.1, 2.2 |
| Zoom after reframing | Current far endpoint `-12` was selected for the old `18.7 m` base and becomes excessive after a roughly fivefold base-distance increase | `CANNON_ZOOM_FACTOR = 0.72`; catalog course spans are already tested against whole-course reach | Set Cannon far endpoint to `-7`, which still exceeds current catalog course spans from the new base pose; keep close endpoint `3` | 2.1, 2.2 |
| Validation | Godot 4.7.1, bounded focused-test wrapper, capture harness, and full suite are available and were used in the preceding camera slice | Verified repository commands and baseline capture | Use focused camera/input tests, two native captures, one final full suite, then diff audit | 2.2, 3.1, 4.1 |

Rejected alternatives:

- Keep the close base and rely on wheel input: selecting a preset must produce
  the useful coordinate immediately.
- Reintroduce a Cannon-only navigation mode: contradicts D-058 and the user's
  explicit model.
- Frame the whole course like Overview: loses the cannon's role as the visible
  local reference.
- Move the interest far along the launch ray: makes the selected cannon an
  incidental edge object instead of the stable visual reference.

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership,
  safety, and validation decision is closed.
- Required tools and dependencies are available; each named validation command
  was verified in PowerShell against Godot 4.7.1.
- Remaining unknowns are render-local fit checks governed by the locked numeric
  criteria and predetermined correction below.

## Tasks

### Phase 1: Promote the framing contract

Goal: canonical documentation defines the medium-distance Cannon coordinate and
preserves common preset semantics.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`

- [x] **1.1** Record the terrain-led medium-distance framing.
  - Change: specify visible cannon scale, central reference placement, rear-upper
    angle, and surrounding/forward terrain context.
  - Accept: all three owners reject cannon-led close-up framing and agree on the
    same reset composition.
- [x] **1.2** Preserve the ordinary-preset contract.
  - Change: state that framing changes the authored coordinate only.
  - Accept: D-058 common controls and course-scale exploration remain effective.

### Phase 2: Reframe the authored coordinate

Goal: selecting or resetting Cannon immediately produces the target composition.

Preconditions:

- Phase 1 documentation is internally consistent.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`tests/cannon_golf_camera_test.gd`

- [x] **2.1** Replace the close base offset with the locked medium-distance pose.
  - Change: set the rear/side/height offset to `80/12/45 m` and adjust the far
    zoom endpoint to `-7` for the new base scale.
  - Accept: the resolved authored distance is `80-110 m`, the camera remains at
    least `45°` from straight down, and Cannon reset/reselection are exact.
- [x] **2.2** Guard behavior across representative courses and follow return.
  - Change: assert authored distance/composition invariants, whole-course dolly,
    setup independence, and exact Shot Follow restoration.
  - Accept: bounded camera and physical-input tests exit zero.

### Phase 3: Prove the rendered composition

Goal: real pixels match the user-provided scale and terrain context.

Preconditions:

- Phase 2 focused tests pass.

Source owners: `tests/capture_cannon_golf_frame.gd`,
`.agents/evidence/cannon-golf/2026-08-18-cannon-preset-framing/`

- [x] **3.1** Capture and inspect the new authored Cannon preset.
  - Change: capture LV5 at 1920 by 1080 and a representative course at 1280 by
    720 without changing setup or applying manual camera input.
  - Accept: both captures satisfy every visual completion criterion and are not
    blank, clipped, terrain-penetrating, or stale.

### Phase 4: Finalize the slice

Goal: integrate the framing change without shared-camera regressions.

Preconditions:

- Phase 3 rendered acceptance passes.

Source owners: task-owned diff, `scripts/test-cannon-golf.ps1`, this contract

- [x] **4.1** Run the final suite and diff-scoped quality audit.
  - Change: run the complete suite once, inspect ownership and stale contracts,
    mark this contract done, and commit only task-owned files.
  - Accept: suite and `git diff --check` exit zero; the audit finds no competing
    camera owner, reachable regression, or unrelated staged file.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_camera_test.gd`; then `cannon_golf_input_test.gd` | Pose and tests are updated | Relevant pose or input-test code changes |
| Render gate | The same wrapper with `-Rendered` and `capture_cannon_golf_frame.gd` for `cannon`, course `4`, 1920 by 1080 and course `0`, 1280 by 720 | Focused checks pass | Pose, visible world, or capture input changes |
| Final gate | `scripts/test-cannon-golf.ps1 -GodotPath D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe`; `git diff --check`; diff quality audit | Render gate passes | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not rerun the passing baseline capture; it is retained comparison evidence.
- Run the full suite once after rendered acceptance, and rerun it only after a
  material task-owned correction.
- A generated image is insufficient until it is opened and inspected at native
  size.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| The new cannon body is outside the `5-10%` height target | Scale all three authored offset components proportionally while preserving the rear/side/height ratio and `80-110 m` distance criterion, then recapture | Do not change FOV, interest ownership, or controls |
| Terrain blocks or admits the camera on a prepared course | Use the existing terrain-safe boom/last-valid-position owner and adjust only within the locked distance/angle criteria | Do not modify terrain or course data |
| A verified material fact contradicts this contract | Stop the affected branch and revise the contract before resuming | Do not let implementation choose a new UX or camera model |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: full project suite, diff check, and diff-scoped quality
  audit.
- Verification: focused camera/input tests passed; native LV5 1920 by 1080 and
  LV1 1280 by 720 captures passed visual inspection; the full suite passed in
  `109.2 s`. The existing non-blocking app-flow exit warning reported one leaked
  `ObjectDB` instance and did not fail the repository wrapper.
- Audit result: framing remains owned by `course_camera_rig.gd`, canonical
  behavior remains in the three product documents, and no input, HUD, terrain,
  physics, or unrelated cleanup responsibility entered the change.
- Update rule: after a checkpoint passes, record concise evidence, check the task,
  and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named gate passes.
- Both new renders satisfy the completion criteria against the supplied reference.
- Canonical specifications and the decision log reflect the accepted framing.
- Frontmatter status is `done` and the scoped commit contains no unrelated files.

Replan when:

- A material discovery invalidates the locked framing or ordinary-preset model.

Do not replan or stop for:

- Proportional render-local correction already authorized above.
- A passing check whose relevant inputs have not changed.
