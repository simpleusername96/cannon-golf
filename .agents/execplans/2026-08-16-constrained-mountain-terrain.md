---
type: plan
status: done
created: 2026-08-16
scope: Constrained Cannon Golf terrain progression, terrain-owned goal basins, and flag-color completion feedback
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - ../research/cannon-golf/RESEARCH.md
  - project-specs/cannon-golf/assets/terrain-progression-early.png
  - project-specs/cannon-golf/assets/terrain-progression-mid.png
  - project-specs/cannon-golf/assets/terrain-progression-late.png
---

# Constrained Mountain Terrain - Execution Contract

The current trajectory-first generator already selects analytically reachable launcher-to-goal legs, but it fills the map with broad Gaussian noise, globally smooths away semantic structure, and builds each goal as a separate plate and fence. This contract replaces only those responsibilities with a deterministic feature-graph heightfield, terrain-owned basins, and a fixed flag whose material color is the sole goal-world completion change. Existing camera, aiming, ball lifecycle, UI, and deferred devices remain unchanged.

## Purpose

- Objective: make the prepared catalog read like the canonical early/mid/late mountain references while making reachability and overview readability generator inputs rather than post-hoc play-test guesses.
- Deliverable: source-backed generation rules, generator and goal changes, regenerated prepared artifacts, focused contract checks, and three representative rendered captures.
- Completion state: every course uses a connected irregular mountain footprint with progressively denser ridges, shelves, valleys, and elevation tiers; every goal is carved into that heightfield; completion changes only the flag color in world geometry.

## Scope and Boundaries

In scope:

- Route/landform graph, height synthesis, terrain footprint, basin carving, ballistic-corridor admission, overview line-of-sight admission, prepared artifacts, goal mesh/collision ownership, and flag completion material.

Out of scope:

- Camera code, aim arc, ball lifecycle or speed, menus/HUD, persistence, bounce/damping/airflow/gravity devices, and new dependencies.

Constraints and invariants:

- Use the three `terrain-progression-*` images as the visual family contract, not as literal meshes.
- Keep one connected heightfield-like terrain without caves or overhangs.
- Choose each leg from legal whole-degree elevation/power settings before terrain synthesis; final shared height samples must preserve clearance below that analytic flight.
- Fit the compact active footprint into the existing overview framing and require line-of-sight from the canonical high-oblique direction to every flag top.
- Use deterministic, bounded construction. Do not search the continuous control space or run a large physics campaign.
- Preserve unrelated user-authored working-tree changes.

Destructive or irreversible actions:

- Replace the ten generated prepared-course resources only after one representative course passes the generator contract.

Exact actions requiring owner or user approval:

- None. No dependency, schema migration, destructive cleanup, or external publication is required.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Semantic mountain shape | `trajectory_course_generator.gd` uses profile-specific Gaussian bumps, then eight filters and up to 192 global slope projections | Canonical images show dominant peaks, branching ridges, terraces, valleys, and irregular silhouettes | Build a small route/landform feature graph, evaluate compact-support fields, and keep cliffs outside protected gameplay corridors | 1.1 |
| Reachability | `_plan_legs`, `_choose_setup`, and `CannonGolfBallistics` already choose a legal analytic witness before terrain exists | Exact damped recurrence and discrete legal setup grid are current product owners | Retain path-first planning and add final height-sample corridor clearance; no brute-force shot search | 1.1, 2.1 |
| Camera readability | `CannonGolfOverviewCameraSolver` fits supplied presentation bounds but does not own generated visibility | Existing solver plus grid-terrain line-of-sight research | Generate a compact active footprint, derive content bounds from it, and line-sample every flag against the final heightfield from the canonical oblique direction | 1.2, 2.1 |
| Goal geometry | `settlement_goal.gd` owns a collision disc and 13 fence segments; terrain is flattened under it | Runtime inspection and `cannon_golf_goal_test.gd` | Carve a smooth basin in the shared heightfield; keep only a non-colliding flush cue and fixed flag in the goal node | 1.3 |
| Completion feedback | `_apply_visual_state` changes flag size/height, fence density, and arrow visibility | Runtime source and user direction | All world geometry stays fixed; only the flag material changes from incomplete blue to completed gold | 1.3 |
| Validation cost | Existing goal regression simulates many balls for every course | User explicitly rejected large test campaigns | Use analytic generator checks, a small structural goal check, one representative bake before catalog bake, and early/mid/late captures | 2.1, 2.2 |

Readiness statement:

- Every material product, architecture, data, UX, ownership, safety, and validation decision is closed.
- Godot 4.7.1, the repository bake entrypoint, the existing capture script, and ImageMagick inspection are available; no bootstrap or dependency change is required.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Construct the constrained terrain and goal model

Goal: Replace noise-first terrain and separate goal plates with a deterministic feature-graph mountain and terrain basins.

Preconditions:

- Canonical references and current generator/camera/goal owners are verified.

Source owners: `src/cannon_golf/trajectory_course_generator.gd`, `src/cannon_golf/settlement_goal.gd`, `src/terrain/terrain_top_topology.gd`

- [x] **1.1** Generate early, middle, and late semantic mountain families.
  - Change: derive ridge, terrace, valley, and landmark fields from the route stations and course tier; build one connected irregular active-cell footprint; preserve a protected analytic flight corridor.
  - Accept: each catalog entry is deterministic, connected, has its tier's feature density and relief band, and passes final analytic path clearance.
- [x] **1.2** Make overview readability a generation contract.
  - Change: compute compact active content bounds and sample high-oblique line-of-sight to every flag top on the final grid.
  - Accept: every prepared course passes footprint compactness and flag visibility without changing camera code.
- [x] **1.3** Make goals terrain-owned and completion color-only.
  - Change: stamp a near-flat floor plus smooth concave shoulder into the final heightfield; remove separate collision floor/fence; keep flag transform and all other world geometry fixed across states.
  - Accept: the goal node owns no `StaticBody3D` or wall collision, basin samples rise monotonically from floor to shoulder, and only the flag material color changes on confirmation.

Batch gate:

- Parse the changed scripts and bake `first_ridge` once; do not start the catalog bake until the constructed resource passes its intrinsic contracts.

### Phase 2: Materialize and verify the catalog

Goal: Persist the constrained results and verify the three visual progression tiers with bounded evidence.

Preconditions:

- Phase 1 acceptance checks and its representative bake pass.

Source owners: `scripts/bake_cannon_golf_courses.gd`, `resources/cannon_golf/prepared/*.res`, `tests/cannon_golf_terrain_test.gd`, `tests/cannon_golf_goal_test.gd`, canonical reference assets

- [x] **2.1** Regenerate the ten prepared artifacts.
  - Change: run the existing deterministic bake once for the catalog after the representative gate.
  - Accept: all ten artifacts load against their authored identities and record no intrinsic corridor, connectivity, basin, or overview-visibility failure.
- [x] **2.2** Compare representative early, middle, and late screens.
  - Change: capture one planning frame from courses 1, 5, and 10, plus one focused completed-goal state if the flag-color change is not clear in those frames.
  - Accept: the frames show increasing feature density and vertical layering, terrain-owned basins, readable flags, and no goal fence or completion geometry mutation.

Batch gate:

- Run only the focused terrain/goal contracts, inspect the representative captures, and perform a task-owned code-quality audit.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Godot parse plus one `first_ridge` bake | Generator or goal source reaches a coherent state | Relevant source changes |
| Phase gate | Focused terrain and structural goal contracts | Phase 1 tasks pass | Generator, goal, or contract input changes |
| Final gate | One full catalog bake and three representative planning captures | Both phases pass locally | A prepared-artifact or visual input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not run a continuous aim search, multi-seed campaign, or per-course physics simulation.
- Treat the full catalog bake as materialization, not exploratory testing; run it once after the representative gate.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A final trajectory intersects generated terrain | Lower or move only the conflicting feature outside basin/support locks; do not scale ballistics or camera | Replan only if no feature-graph layout can satisfy the authored route interval |
| A flag is hidden from the canonical overview | Move or lower the occluding optional landmark within its deterministic recipe; do not lift or rewrite the camera | Replan only if the route station itself makes visibility impossible |
| An inactive-cell footprint disconnects | Expand the route capsule union and rebuild once | Do not add disconnected islands |
| A verified material fact contradicts this contract | Stop the affected branch and update the contract before resuming | Do not choose a new product, architecture, or validation contract during implementation |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: final bounded validation and rendered comparison.
- Evidence: all ten deterministic course constructions passed connectivity,
  basin, ballistic-clearance, flag-visibility, and overview-boom contracts;
  terrain-owned goal structure passed; early/middle/late planning frames were
  inspected against the canonical reference family.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named batch gate passes.
- Durable research and product decisions are recorded in their owning documents.
- The plan status is changed to `done` and no task-owned temporary probe remains.

Replan when:

- A material discovery invalidates the locked contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
