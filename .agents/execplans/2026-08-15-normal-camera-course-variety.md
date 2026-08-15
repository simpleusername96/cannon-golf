---
type: plan
status: done
created: 2026-08-15
scope: Normal overview and shot-follow camera behavior plus visible macro variety across the ten prepared connected-heightfield courses
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-15-camera-navigation-world-readability.md
---

# Normal Camera and Distinct Course Shapes - Execution Contract

The current build has a reproducible ordinary-play camera failure: close-zoom panning can leave the view pressed into terrain, panning changes the overview framing distance, and shot follow shows too little course context. The catalog also repeats one alternating route layout and five macro height styles across ten courses. This contract repairs those existing owners with conventional pivot, boom, interpolation, and deterministic heightfield techniques; it does not add a new camera system or a new gameplay mechanic.

## Purpose

- Objective: make camera control and the current ten maps behave as a player would normally expect in a 3D golf or ballistic puzzle.
- Deliverable: a stable high-oblique overview, readable shot follow, terrain-safe camera movement, and ten prepared courses with distinct route silhouettes and macro landforms.
- Completion state: focused behavior tests, prepared-artifact contracts, production-style game captures, and the final quality audit all pass; representative before/after frames show the confirmed defects are gone.

## Scope and Boundaries

In scope:

- Keep overview panning translational: moving the focus must not silently refit or zoom the whole course.
- Smooth the camera position and look target together, and collision-check the camera position actually rendered on each update.
- Shorten the overview and follow boom along its normal line when terrain blocks it; never jump upward to escape an obstruction.
- Initialize each shot follow from the newest ball's direction and use a conventional trailing distance that retains terrain context.
- Replace the catalog-wide alternating zigzag with a small deterministic set of course-specific route station motifs.
- Replace the modulo-five macro terrain reuse with ten deterministic macro profiles while preserving the existing detail, landform, corridor, support, relief, and slope passes.
- Rebake all ten immutable prepared course artifacts.

Out of scope:

- New camera modes, free-flight controls, lock-on logic, cinematic rails, camera shake, a minimap, or HUD redesign.
- Bounce pads, damping pads, airflow devices, gravity zones, or changes to ball physics, shot limits, rapid fire, goals, course count, materials, or topology.
- Caves, overhangs, disconnected islands, erosion simulation, candidate search, machine-learned terrain, or a new dependency.
- Reworking user-authored interface/theme changes already present in the worktree.

Constraints and invariants:

- PRD FR-8 and AC-5 remain authoritative: overview is the exploration owner, cannon view is exact first-person, ten zoom-in actions reach `28 m`, six zoom-out actions reach full-course fit, `Home` resets, and `Tab` restores the stored planning state.
- PRD FR-15, Q-19, and D-042 remain authoritative: every course stays one connected heightfield with no preinstalled route-changing device; devices remain deferred until the terrain and camera foundation is sound.
- Retain frame-rate-independent exponential camera damping and the current swept sphere collision primitive, consistent with Godot 4.7 guidance.
- Preserve the existing generator's ballistics admission, goal support, relief, slope, topology, triangle-count, and runtime prepared-artifact contracts.
- Add no production dependency and change no public product title or UI language.
- Preserve unrelated dirty files and untracked Godot UID files; stage only task-owned changes.

Destructive or irreversible actions:

- None. Prepared `.res` files are reproducible from the checked-in authoring data and bake script.

Exact actions requiring owner or user approval:

- None inside this contract. Any request to change topology, add a gameplay device, add a dependency, or replace the current camera interaction grammar requires a revised contract and owner direction.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Ordinary overview movement | `course_camera_rig.gd` smooths only position; `overview_camera_solver.gd` recomputes a full-bounds fit around the panned focus, so pan also changes distance and orientation can snap | `baseline-panned-course-4.png`; `course_camera_rig.gd::_apply_planning`; `overview_camera_solver.gd::resolve_pose` | Keep the existing pivot/orbit rig, but compute fit around the fixed reset focus and translate that pose to the panned focus; smooth rendered focus with rendered position | 1.1, 1.2 |
| Terrain collision | The current sphere sweep returns a stale fallback for short safe fractions and does not prove the final rendered step; the close-panned baseline is visibly obstructed | PRD AC-5; Godot 4.7 SpringArm documentation; current solver and capture | Keep a positive-margin sphere boom, collapse to its current safe fraction when blocked, reject invalid casts, and validate ordinary close-pan/orbit clearance | 1.2, 1.3 |
| Shot follow | The fixed `12 m`/`6 m` offset makes the `2 m` ball dominate the frame, and follow direction can begin from the previous shot | `baseline-follow-course-1.png`; `course_camera_rig.gd::_apply_follow` | Reset direction from each target, use a modestly longer/higher trailing pose, smooth the actual step, then sweep that step | 1.1, 1.3 |
| Catalog route variety | `_plan_legs` mirrors every goal across center at uniform depth, producing the same alternating zigzag | `trajectory_course_generator.gd::_plan_legs`; ten-course montage | Use deterministic course-specific lateral station motifs and the already-authored per-leg route intervals; do not add a search framework or schema | 2.1, 2.3 |
| Catalog terrain variety | `_natural_height` uses `course_index % 5`, so five macro profiles repeat across ten courses | `trajectory_course_generator.gd::_natural_height`; ten-course montage | Give every current course its own simple macro profile made from the existing smooth waves and Gaussian landform primitives | 2.2, 2.3 |
| Safe terrain implementation | External terrain work shows that heterogeneous heightfields can be built from a small set of deliberately placed macro profiles, separate from local detail | Rusnell, Mould, and Eramian (2009); Hnaidi et al. (2010) | Apply only the low-risk principle: a small explicit route/macro vocabulary before existing bounded detail; do not import their solvers | 2.1, 2.2 |
| Deferred devices | The user requires basic camera and terrain quality before bounce, damping, airflow, or gravity work | `DECISIONS.md` D-042 | Do not touch device behavior or add device-shaped terrain workarounds | all |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot `4.7.1.stable.official.a13da4feb`, the bounded validation wrapper, the all-course bake entry point, and the rendered capture harness are available. The focused camera command below was executed successfully against the current baseline.
- Remaining unknowns are numeric implementation tuning inside the locked behavior and cannot change this contract.

## Tasks

### Phase 1: Conventional camera behavior

Goal: overview movement is stable and predictable, follow keeps ball and terrain readable, and no normal camera step enters terrain.

Preconditions:

- Current PRD, design rules, decisions, camera owners, baseline captures, and Godot 4.7 primary documentation have been inspected.

Source owners: `src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/overview_camera_solver.gd`, `tests/cannon_golf_camera_test.gd`, `tests/capture_cannon_golf_frame.gd`

- [x] **1.1** Pan, orbit, planning transitions, and shot follow move without framing pumps or look-direction pops.
  - Change: separate fixed reset framing focus from the current pan focus; interpolate the rendered focus with the rendered camera position; initialize follow direction for every target and tune the existing follow offset for terrain context.
  - Accept: the focused camera test proves pan preserves requested boom distance, planning motion is finite and continuous, every follow starts from its own direction, and `Tab` still restores the exact stored planning state.
  - Evidence: the fixed reset pivot now owns framing distance, rendered focus and position share one exponential weight, follow resets from the target velocity, and the focused camera contract exits zero.
- [x] **1.2** The existing swept boom fails closed and checks the pose actually shown.
  - Change: return the current collision-safe boom point instead of a stale off-boom fallback, preserve the positive margin and exclusions, and sweep after interpolation for both planning and follow.
  - Accept: close zoom plus ordinary pan/orbit keeps every camera footprint sample above terrain and never returns a stale pose after a block.
  - Evidence: the solver collapses to the collision-safe point on its current boom; the rig validates the rendered camera footprint and focused camera boom sampling passes.
- [x] **1.3** Representative camera states render clearly.
  - Change: extend only the capture assertions needed to verify the known close-pan and follow defects.
  - Accept: 1280×720 captures for close-pan course 4, collision-edge course 7, and follow course 1 show readable terrain and no near-plane obstruction; scripted state assertions pass.
  - Evidence: `phase1-final-panned-course-4.png`, `phase1-final-collision-course-7.png`, and `phase1-final-follow-course-1.png` rendered at 1280×720 and passed native-pixel inspection.

Batch gate:

- `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_camera_test.gd -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 90`

### Phase 2: Distinct but simple course macro shapes

Goal: each prepared course reads as a distinct route and landform while remaining the same basic connected-heightfield game.

Preconditions:

- Phase 1 acceptance checks and batch gate pass.

Source owners: `src/cannon_golf/trajectory_course_generator.gd`, `src/cannon_golf/course_route_motifs.gd`, `tests/cannon_golf_course_variety_test.gd`, `tests/cannon_golf_terrain_test.gd`

- [x] **2.1** The ten routes no longer repeat one uniform mirrored zigzag.
  - Change: add conservative deterministic lateral station motifs per current course and place goal depth from each authored leg's `route_interval`.
  - Accept: a semantic route signature test proves all ten route station sequences are distinct and later multi-goal routes are not the legacy uniform mirror pattern; every ballistic setup is still constructible.
  - Evidence: reflection-canonical lateral/depth signatures are unique for all ten planned and prepared routes, every prepared route exactly matches its deterministic plan, and all ten plans retain constructible setups.
- [x] **2.2** The ten terrains no longer reuse five macro height profiles.
  - Change: select one named macro profile per catalog index using the existing wave and Gaussian primitives, then retain all current feature, smoothing, projection, corridor, and support stages.
  - Accept: a lightweight macro descriptor gate distinguishes all ten prepared heightfields without relying on payload hashes alone.
  - Evidence: ten named source profiles and coarse value-bearing 3×4 prepared heightfield descriptors are unique across the catalog.
- [x] **2.3** Every revised course still meets existing physical and authored contracts.
  - Change: increment the generator algorithm version and rebake all ten prepared artifacts through the canonical script.
  - Accept: the bake completes inside its bounded wrapper and terrain, slope, range, artifact identity, course build, and catalog smoke contracts pass.
  - Evidence: the final all-course bake exited zero with deterministic algorithm version 9 recorded in every artifact; terrain, slope, range, artifact identity, course-build, catalog-smoke, and focused variety contracts all exited zero.

Batch gate:

- `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://scripts/bake_cannon_golf_courses.gd -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 900`

### Phase 3: Rendered catalog verification

Goal: verify the result in real game pixels rather than treating distinct data as sufficient visual variety.

Preconditions:

- Phases 1 and 2 pass; prepared artifacts are current.

Source owners: `tests/capture_cannon_golf_frame.gd`, `.godot/capture-temp/` disposable evidence

- [x] **3.1** Early, middle, and late reset overviews clearly expose different route and terrain silhouettes.
  - Change: capture planning views for courses 0, 3, 6, and 9 at 1280×720 and one late course at 1600×900.
  - Accept: manual pixel inspection confirms distinct macro shapes, complete-course fit, readable goals, no clipped HUD, and no sky- or slab-dominant composition.
- [x] **3.2** The corrected camera states remain readable on the rebaked terrain.
  - Change: recapture the Phase 1 close-pan, collision-edge, and follow states after the final bake.
  - Accept: each scripted assertion passes and side-by-side inspection shows the baseline obstructions are absent.

Batch gate:

- Run `tests/capture_cannon_golf_frame.gd` with the named states, courses, sizes, `--background`, and explicit outputs under `.godot/capture-temp/normal-camera-course-variety/`; inspect every saved PNG at native resolution.

### Phase 4: Final regression and ownership audit

Goal: hand off a coherent, tested change without responsibility creep or unrelated worktree changes.

Preconditions:

- Phases 1 through 3 pass.

Source owners: task-owned changed files, focused Cannon Golf tests, project import/build path

- [x] **4.1** Focused and integration contracts pass once against final inputs.
  - Change: run the camera, terrain, slope, range, artifact, build, catalog, app-flow, and UI contract tests through the bounded wrapper.
  - Accept: every named test exits zero, the wrapper leaves no owned process, and no new Godot error or crash log is created.
  - Evidence: camera, input, course-variety, terrain, slope, range, artifact, course-build, catalog-smoke, solution, app-flow, and UI-contract checks all exited zero; every wrapper report recorded zero owned processes and zero user-log growth.
- [x] **4.2** The multi-file quality audit finds no competing owner, catch-all growth, broken contract, or reachable failure path.
  - Change: run the repository quality audit over task-owned diffs and apply only small safe in-scope corrections.
  - Accept: all blocking findings are resolved or reported with exact evidence; no new dependency, device system, camera mode, or UI owner appears.
  - Evidence: the final read-only audit found no ownership or serialization blocker; its camera fallback and center-line-only coverage findings were resolved with a terrain-safe nine-point boom footprint and revalidated in the focused camera test and three rendered states.
- [x] **4.3** Task-owned work is committed coherently.
  - Change: verify the staged diff excludes pre-existing theme, menu, course-select, UI-contract, and unrelated UID changes; create scoped commits with explanatory bodies; mark this plan `done` after all gates pass.
  - Accept: `git status --short` clearly separates any remaining user changes, and task commits contain only files owned by this contract.
  - Evidence: camera foundation `f58d968`, prepared course variety `939b219`, and final close-camera safety `98f2efe` contain only task-owned files; pre-existing theme, menu, course-select, UI-contract, and unrelated UID changes remain outside them.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Bounded `cannon_golf_camera_test.gd` for camera work; one-course bake for generator syntax/setup work | After the relevant implementation compiles | Relevant camera or generator input changes |
| Phase gate | Phase 1 camera test; Phase 2 all-course bake plus focused terrain contracts; Phase 3 named PNG captures | All tasks in that phase pass their local acceptance | A phase-owned source or prepared artifact changes |
| Final gate | Bounded camera, terrain, slope, range, artifact, course-build, catalog-smoke, app-flow, and UI-contract tests plus final rendered captures | All phases pass and task inputs are frozen | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Use the checked-in production game scene and prepared resources for final rendered QA; a headless-only result is insufficient for this user-facing task.
- Rerun a failed check only after a relevant implementation change or a new hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain any required approval before resuming | Do not let implementation choose a new product, architecture, dependency, topology, device system, UX contract, or validation contract |
| A route motif cannot satisfy the existing analytic setup table | Reduce only that motif's lateral excursion while preserving its shape, then rerun the one-course bake | Do not change ballistics, goals, power range, or the setup table |
| A macro profile violates slope or relief contracts | Reduce or widen only that profile's existing Gaussian primitive, then rerun the affected course and slope check | Do not weaken accepted slope, relief, corridor, or support thresholds |
| A valid boom begins in collision at a steep focus | Raise the terrain-safe focus only by the existing boom radius/margin clearance and prove composition in capture | Do not add automatic sky lift or teleport to another camera mode |
| Rendered QA shows a remaining obstruction despite numeric clearance | Treat pixels as a failed acceptance check, adjust within the existing pivot/boom/follow model, and recapture | Do not waive the failure because unit tests pass |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None; await user play feedback on the normal camera and rebaked catalog.
- Last completed gate: task-owned camera, route, terrain, artifact, test, and plan changes were committed without staging the user's pre-existing worktree changes.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every guard, phase gate, and final gate named by this contract passes.
- No placeholder or unresolved material decision remains.
- Durable product behavior remains in the canonical specs and decisions; this plan contains only execution state.
- Frontmatter status is changed to `done` only after implementation is complete.

Replan when:

- A material discovery invalidates the locked contract.

Do not replan or stop for:

- Numeric camera distance or macro-profile tuning that stays inside the locked existing behavior.
- A passing check whose relevant inputs have not changed.
