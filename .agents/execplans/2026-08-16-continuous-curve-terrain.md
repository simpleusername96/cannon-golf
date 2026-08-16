---
type: plan
status: done
created: 2026-08-16
scope: Replace Cannon Golf's sampled blob-and-terrace terrain source with a constrained continuous curve field and smooth course-only rendering
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/research/cannon-golf/RESEARCH.md
  - .agents/execplans/2026-08-16-constrained-mountain-terrain.md
  - .agents/execplans/2026-08-16-broader-ridge-goal-terrain.md
---

# Continuous Curve Terrain - Execution Contract

Cannon Golf currently samples a pointwise terrain recipe that merges broad blobs with `max()`, quantizes the result into global terrace bands, adds grid-scale trigonometric roughness, and renders one normal and random tone per triangle. This contract replaces that source with a deterministic graph of continuous ridge, valley, shelf, and peak curves. The continuous field compiles to the existing regular collision/query grid, while Cannon Golf's render mesh uses continuous vertex normals and macro-scale color variation. Existing ballistic, camera, basin, artifact, and triangle-address contracts remain authoritative.

## Purpose

- Objective: produce broad, continuous mountain forms without the current faceted surface or small-scale height noise, while preserving the accepted terrain extent, relief, goal, ballistic, and overview constraints.
- Deliverable: a curve-feature model, a continuous terrain-field compiler, Cannon Golf-only smooth render output, focused contracts, regenerated prepared catalog resources, and early/middle/late rendered evidence.
- Completion state: all ten prepared courses are generated from the new field, pass their existing intrinsic constraints, and show visually continuous slopes with readable terrain-owned goal basins.

## Scope and Boundaries

In scope:

- Continuous terrain feature and field owners; deterministic course feature-graph construction; generator integration; Cannon Golf render normals and macro surface tone; directly corresponding tests; prepared course artifacts; three representative planning captures.

Out of scope:

- Adaptive or non-heightfield collision topology; changes to triangle identity, ball physics, camera code, HUD, input, persistence, goal state, devices, route counts, or hand-authored course positions.

Constraints and invariants:

- The feature graph, not the regular grid, is the terrain source of truth. The regular grid is a compiled compatibility artifact for current collision, height queries, ballistic clearance, camera admission, goal placement, and prepared resources.
- Keep one connected heightfield without caves or overhangs. Preserve decisions D-045 through D-047, including terrain-owned circular goal basins, summit-or-ridge goals, the `1.35` terrain envelope, minimum active area, and maximum active internal edge angle.
- Preserve route-first analytic ballistic setup and deterministic camera/terrain admission. Do not add random shot campaigns or continuous aim searches.
- Smooth shading applies only when Cannon Golf asks the shared geometry factory for it. Inherited Paint Mountain callers retain their existing flat-shaded default.
- Add no production dependency and do not change the prepared-course schema or public triangle-address contract.
- Preserve unrelated HUD changes and untracked experimental/prepared directories already in the worktree.

Destructive or irreversible actions:

- The canonical ten files under `resources/cannon_golf/prepared/` are replaced only after one representative course passes source, geometry, and intrinsic admission checks. They remain reproducible through the repository bake script.

Exact actions requiring owner or user approval:

- None. The user authorized the plan and implementation; no dependency, external publication, schema migration, or destructive cleanup is included.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Terrain source | `CannonGolfTrajectoryCourseGenerator._semantic_height()` combines route scaffolds and ellipse landmarks with `max()`, global terrace quantization, and short-wavelength sine roughness before sampling the regular grid | `src/cannon_golf/trajectory_course_generator.gd`; accepted curve-network and feature-diffusion sources recorded in `.agents/research/cannon-golf/RESEARCH.md` | Move semantic construction into a typed curve graph and continuous field; remove global terrace quantization and grid-scale roughness from the live generation path | 1.1, 1.2 |
| Runtime compatibility | `GeneratedStageLayout`, `TerrainTopTopology`, prepared artifact identity, surface queries, and impact addresses depend on the regular `cell_count`, height array, footprint, and triangle IDs | `src/stage_generation/generated_stage_layout.gd`; `src/terrain/terrain_top_topology.gd`; artifact and build tests | Compile the continuous field into the current grid and keep topology/collision/query ownership unchanged | 1.2, 2.1 |
| Visual faceting | `TerrainGeometryBuildJob._step_top()` writes one face normal and one per-triangle pseudo-random green-channel tone to all three corners | `src/terrain/terrain_geometry_build_job.gd`; `src/terrain/terrain_geometry_factory.gd`; `src/cannon_golf/cannon_golf_terrain.gdshader` | Add an opt-in smooth-top mode that accumulates area-weighted source-vertex normals and uses deterministic macro vertex tone; Cannon Golf enables it and all existing callers default to flat | 2.1, 2.2 |
| Goal, ballistics, and camera | Goal fitting and final projection/admission passes already enforce circular basins, summit/ridge roles, flight clearance, boom clearance, and flag sightlines | Generator contract functions and `tests/cannon_golf_terrain_slope_test.gd` | Keep these as hard compilation and admission stages after the field is sampled; do not move them into visual-only code | 1.2, 3.1 |
| Validation cost | The user rejected large shot campaigns; the repository has a bounded wrapper, one-course bake argument, focused source tests, and a deterministic catalog bake | `scripts/invoke-cannon-golf-validation.ps1`; `scripts/bake_cannon_golf_courses.gd`; Godot 4.7.1 CLI verified locally | Use one new focused field/geometry test, one `first_ridge` bake, one catalog constraint pass, one catalog bake, and three final captures; do not run solution stress tests | 1.1, 2.2, 3.1, 4.1 |
| Existing worktree | HUD resources/tests and multiple experimental prepared directories are modified or untracked before this task | `git status --short` on 2026-08-16 | Do not stage, edit, delete, or claim those files; commit only task-owned terrain files and canonical prepared artifacts | 4.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot `4.7.1.stable`, the bounded validation wrapper, one-course/full-catalog bake entrypoint, and rendered capture script are available and their invocations are verified.
- Remaining unknowns are implementation-local numerical tuning inside the locked continuous-field model and cannot change scope, ownership, architecture, or acceptance.

## Tasks

### Phase 1: Replace the terrain source

Goal: Make a continuous semantic curve field the sole source sampled by the trajectory-first generator.

Preconditions:

- Current generator responsibilities, accepted constraints, and installed Godot version are verified.

Source owners: `src/cannon_golf/continuous_terrain_feature.gd`, `src/cannon_golf/continuous_terrain_field.gd`, `src/cannon_golf/terrain_feature_graph_builder.gd`, `src/cannon_golf/trajectory_course_generator.gd`

- [x] **1.1** Add the typed curve-feature and continuous-field owners.
  - Change: represent compact ridge, valley, shelf, and peak features with bounded widths and smooth cross-sections; evaluate a deterministic continuous scalar height with only macro-scale variation.
  - Accept: `tests/cannon_golf_continuous_terrain_test.gd` proves feature validation, deterministic repeat sampling, continuous values at feature boundaries, and distinct ridge/valley/shelf effects.
- [x] **1.2** Compile catalog terrain from the feature graph.
  - Change: build route ridges, branching landmark ridges, broad valleys, local shelves, and peaks from course tier, route plan, authored landforms, and camera direction; sample this field in `_build_heights()` before applying existing goal, flight, slope, and camera constraints.
  - Accept: an in-memory `first_ridge` build is non-empty, identifies algorithm version 12, and passes all existing intrinsic height contracts.
  - Guard: `_semantic_height()` no longer contains global terrace quantization or grid-scale roughness and is not the live source path.

### Phase 2: Compile a smooth Cannon Golf render surface

Goal: Remove triangle-by-triangle visual faceting without changing collision triangles or inherited terrain defaults.

Preconditions:

- Phase 1 acceptance passes.

Source owners: `src/terrain/terrain_geometry_factory.gd`, `src/terrain/terrain_geometry_build_job.gd`, `src/cannon_golf/trajectory_course_generator.gd`, `src/cannon_golf/cannon_golf_terrain.gdshader`

- [x] **2.1** Add opt-in smooth top-surface geometry compilation.
  - Change: accumulate area-weighted normals per canonical source vertex and emit those normals for duplicated render corners while leaving collision faces and source-triangle mappings unchanged; add a default-false factory option and enable it only from Cannon Golf's generator.
  - Accept: the focused terrain test proves shared source vertices receive matching smooth normals, at least one curved shared vertex differs from its adjacent face normals, and topology/collision counts remain unchanged.
  - Guard: a default factory build retains flat face normals for inherited callers.
- [x] **2.2** Replace per-triangle random tone with macro vertex tone in smooth mode.
  - Change: calculate slow world-space tonal variation at each source vertex and update Cannon Golf shader naming/comments to describe interpolated terrain tone rather than facets.
  - Accept: focused array inspection proves identical source positions receive identical colors and a non-flat course still contains bounded tonal variation.

Batch gate:

- Run the focused continuous-terrain test and one bounded `first_ridge` bake. Do not replace the full catalog until both pass.

### Phase 3: Materialize and validate the catalog

Goal: Replace canonical prepared resources with deterministic outputs from algorithm version 12.

Preconditions:

- Phase 2 batch gate passes.

Source owners: `scripts/bake_cannon_golf_courses.gd`, `resources/cannon_golf/prepared/*.res`, `tests/cannon_golf_terrain_slope_test.gd`, `tests/cannon_golf_terrain_test.gd`, `tests/cannon_golf_course_artifact_test.gd`, `tests/cannon_golf_course_build_test.gd`

- [x] **3.1** Run the catalog intrinsic contract once.
  - Change: make only implementation-local field tuning required for all ten deterministic builds to satisfy current relief, footprint, slope, basin, landform, ballistic, boom, and flag-visibility admission.
  - Accept: `cannon_golf_terrain_slope_test.gd` exits zero for all ten courses within the existing per-course deadline.
- [x] **3.2** Bake and verify the canonical prepared catalog.
  - Change: run the approved bake once, then run prepared terrain, artifact identity, and course-build tests.
  - Accept: ten valid distinct artifacts load with current course identities, render/collision resources, exact basin floors, algorithm version 12, and no Godot script/runtime error.

### Phase 4: Rendered evidence, audit, and handoff

Goal: Confirm that the replacement solves the visible problem and contains no task-owned structural regression.

Preconditions:

- Phase 3 passes and canonical artifacts are stable.

Source owners: `tests/capture_cannon_golf_frame.gd`, `.agents/evidence/continuous-curve-terrain/`, task-owned source and tests

- [x] **4.1** Capture and inspect early, middle, and late planning views.
  - Change: capture courses 1, 5, and 10 at 1280x720 into the named evidence directory and inspect the real pixels at native resolution.
  - Accept: broad slopes read continuously without random triangular patchwork; terrain remains progressively layered; circular blue goal regions and terrain-owned basins remain visible; no clipping or failure state appears.
- [x] **4.2** Run the task-owned quality and source gates, then commit coherent terrain changes.
  - Change: apply `$codebase-quality-auditor`, correct only small safe task-owned findings, run `git diff --check`, and create scoped commits without staging unrelated HUD or experimental files.
  - Accept: no reachable task-owned failure remains, the plan records final evidence and becomes `done`, and commits contain only the plan, terrain source/render/test changes, canonical prepared resources, and retained evidence links.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_continuous_terrain_test.gd -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 120` | A coherent feature/field or smooth-geometry slice is complete | A relevant source or focused assertion changes |
| Representative gate | `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://scripts/bake_cannon_golf_courses.gd -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' -UserArgs '--course=first_ridge' -TimeoutSeconds 120` | Phase 2 task checks pass | Generator, geometry, artifact, or first-course input changes |
| Catalog construction gate | `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_terrain_slope_test.gd -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 900` | Representative gate passes | A generator constraint input changes |
| Catalog materialization | `powershell -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://scripts/bake_cannon_golf_courses.gd -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 900` | Catalog construction passes | A prepared-output input changes |
| Prepared integration | Run `cannon_golf_terrain_test.gd`, `cannon_golf_course_artifact_test.gd`, and `cannon_golf_course_build_test.gd` once through the same wrapper with `-TimeoutSeconds 180` | Canonical bake passes | A source or prepared resource used by these tests changes |
| Rendered final gate | Run `tests/capture_cannon_golf_frame.gd` through the wrapper with `-Rendered`, states `planning`, course indices `0`, `4`, and `9`, `1280x720`, `--background`, and distinct outputs under `.agents/evidence/continuous-curve-terrain/` | Prepared integration passes | A visible terrain, material, camera, or artifact input changes |
| Source final gate | `git diff --check` plus task-owned quality audit | Rendered evidence passes | A task-owned source, test, plan, or resource changes |

Validation rules:

- Run the narrowest check that proves the current task and stop at the first material failure.
- Do not run a physics solution suite, multi-seed campaign, random shot loop, or repeated full catalog bake.
- Treat the full catalog bake as final materialization, not exploratory testing.
- Rerun a failed check only after a relevant implementation change or a new hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A curve-field course misses an existing height admission | Tune only feature width, amplitude, or macro placement for the affected tier, then rerun the narrowest failing construction check | Do not restore global terraces, grid-scale roughness, random retries, or change ballistics/camera |
| Smooth render normals expose shading across an intended exterior skirt edge | Keep skirts and bottom face-normal shaded; smooth only canonical top vertices | Do not weld top and shell normals or change collision winding |
| Render/collision positions diverge | Stop and correct the compiler so both outputs use the exact same canonical vertices | Do not accept a visual mesh that misrepresents ball contact or goal height |
| The new field cannot meet the accepted constraint set within 60 seconds per course | Stop the affected branch and revise this contract with measured evidence | Do not increase the deadline or start a search campaign |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain required approval before resuming | Do not let the executor choose a new product, architecture, dependency, data, UX, safety, or validation contract |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: the diff-scoped quality audit found no task-owned responsibility creep, competing owner, contract break, or reachable failure; staged source checks passed and implementation commit `66087dc` contains only the continuous-terrain slice.
- Evidence: rendered planning captures for [early](../evidence/continuous-curve-terrain/early.png), [middle](../evidence/continuous-curve-terrain/middle.png), and [late](../evidence/continuous-curve-terrain/late.png) courses exited zero and were inspected at native resolution; continuous lighting, macro landforms, visible goal regions, and unclipped runtime states passed.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.
- Anti-rework rule: on resume, inspect the current worktree only enough to confirm checkpoint inputs and continue from the first unchecked task whose prerequisites are satisfied. Treat checked tasks and recorded passing evidence as complete unless a relevant input changed. Run each check only at its declared cadence, and rerun failures only after a relevant change or new hypothesis.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check, guard, phase gate, and final gate in this contract passes.
- The three representative real renders are inspected and linked from this plan.
- No task-owned temporary probe remains; the active plan is changed to `done`.
- Durable implementation or validation knowledge is recorded in its owning source comment, test, specification, record, or repository skill when needed.

Replan when:

- A material discovery invalidates the locked architecture, constraints, ownership, or bounded validation path.

Do not replan or stop for:

- Implementation-local numerical tuning already contained by this contract.
- A passing check whose relevant inputs have not changed.
