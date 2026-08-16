---
type: plan
status: done
created: 2026-08-16
scope: Broader Cannon Golf terrain with preserved relief, bounded internal slopes, and ridge-or-summit goal placement
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-16-constrained-mountain-terrain.md
---

# Broader Ridge-Goal Terrain - Execution Contract

The current deterministic generator preserves relief and ballistic/camera
clearance, but its active terrain remains too compact, internal heightfield
slopes reach 76–88 degrees, and most goal neighborhoods rise above the goal rim
in every direction. This refinement makes terrain extent, interior slope, and
goal landform placement intrinsic generator contracts rather than manual map
edits. Camera, ballistics, goal state, UI, and unrelated gameplay remain fixed.

## Purpose

- Objective: generate a visibly broader mountain while retaining the accepted
  relief schedule, limiting internal surface angle, and seating every goal in a
  local summit or the middle of a ridge crest.
- Deliverable: generator constraints, durable product rules, focused contracts,
  regenerated prepared resources, and early/middle/late rendered evidence.
- Completion state: every course passes the same deterministic construction
  path with at least 1.08 times its authored rectangular area active, no active
  adjacent heightfield edge above 50 degrees, unchanged relief admission, and a
  verified summit-or-ridge role for every goal.

## Scope and Boundaries

In scope:

- Generated terrain bounds and footprint, semantic height synthesis, local
  goal landforms, internal-slope admission, prepared resources, and directly
  corresponding tests/specification text.

Out of scope:

- Hand-authored per-course height edits, camera code, cannon/ball physics,
  scoring behavior, UI, menus, aim arc, devices, and dependencies.

Constraints and invariants:

- Expand generated terrain around the unchanged authored route domain by 1.35
  on both horizontal axes; do not lengthen the ballistic legs.
- Keep the existing catalog relief targets and upper tolerance. Expansion and
  broad landforms absorb the vertical difference; relief must not be flattened
  to satisfy the angle contract.
- Limit only adjacent samples whose shared cells belong to the active terrain.
  The vertical outside skirt is not an internal landform slope.
- The final goal of each course is a local summit. Earlier relay goals must
  resolve as either a local summit or a ridge; ridge orientation may follow or
  cross the route when flight and overview clearance require it.
- Preserve basin geometry, flight clearance, overview boom clearance, and
  camera-to-flag visibility after slope limiting.
- Use deterministic construction and intrinsic sampling; do not tune individual
  course height samples or run repeated shot simulations.
- Preserve unrelated working-tree changes.

Destructive or irreversible actions:

- Replace the ten generated prepared resources only after courses 1 and 10
  pass the new intrinsic contracts.

Exact actions requiring owner or user approval:

- None. The user explicitly selected these generation constraints and no
  dependency, schema, or external publication changes are involved.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| More terrain | `trajectory_course_generator.gd` uses the authored bounds directly; active area is only 0.41–0.82 of that rectangle | One metadata scan over the ten prepared resources | Keep route planning in authored bounds, expand only terrain bounds by 1.35, and require active area >= 1.08 authored areas | 1.1, 2.1 |
| Preserve relief without extreme angle | Existing relief is 92–265 m while internal maxima are 76–88 degrees | `measure_slope_metrics` on prepared height arrays | Retain the relief schedule and apply a deterministic active-cell Lipschitz projection with a 50-degree limit | 1.2, 2.1 |
| Goal on summit or ridge | At 52 m from almost every current goal, zero of eight samples are at least 4 m below its rim | Focused radial metadata scan | Last goal gets an eight-direction summit contract; earlier goals get longitudinal crest and transverse 6 m prominence contracts | 1.3, 2.1 |
| Reachability and camera | Existing generator already owns analytic flight, overview boom, and flag line-of-sight admission | Current source and passing prepared contracts | Re-run these checks on the final projected grid; do not edit camera or ballistics | 1.2, 2.1 |
| Validation cost | Generator and prepared-resource checks are deterministic and non-physics | Repository validation wrapper and prior bake | Use courses 1/10 as implementation gates, one catalog materialization, and three rendered frames | 2.1, 2.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership,
  safety, and validation decision is closed.
- Godot 4.7.1 and the repository validation, bake, and capture scripts are
  available and already verified in PowerShell.
- Remaining unknowns are implementation-local numeric convergence details and
  cannot change this contract.

## Tasks

### Phase 1: Add the three intrinsic terrain constraints

Goal: Make broader extent, bounded internal angle, and ridge/summit goal context
part of one deterministic generator result.

Preconditions:

- The current prepared metrics and source owners are recorded above.

Source owners: `src/cannon_golf/trajectory_course_generator.gd`

- [x] **1.1** Expand terrain without lengthening shots.
  - Change: separate authored route bounds from terrain bounds, expand terrain
    by 1.35, and seed the footprint with one irregular compact island field.
  - Accept: active world area is at least 1.08 times the authored rectangle,
    remains irregular and connected, and all protected route points are active.
- [x] **1.2** Preserve relief under a 50-degree internal slope limit.
  - Change: project active neighboring height samples into a 50-degree
    Lipschitz envelope, then reapply only already-owned safe corridor/basin
    constraints and admit the final grid by active-slope and relief checks.
  - Accept: courses 1 and 10 retain their relief bands, every active adjacent
    sample edge is at most 50 degrees, and ballistic/camera contracts still pass.
- [x] **1.3** Put every goal on a generated summit or ridge crest.
  - Change: stamp a broad local summit for the final goal and a route-aligned
  ridge seed for earlier goals before carving the existing shallow basin;
  final admission accepts an earlier goal as either a summit or a ridge.
  - Accept: a summit drops by at least 6 m in all eight sampled directions;
    a ridge retains its longitudinal crest and drops by at least 6 m across it.

Batch gate:

- Build courses `first_ridge` and `alpine_complex` once through the real
  generator and inspect their intrinsic metrics. Do not bake the catalog until
  both pass.

### Phase 2: Materialize and verify the refined catalog

Goal: Persist and visually confirm the broadened terrain family.

Preconditions:

- Phase 1 acceptance and its two-course batch gate pass.

Source owners: `resources/cannon_golf/prepared/*.res`,
`tests/cannon_golf_terrain_slope_test.gd`,
`tests/cannon_golf_terrain_test.gd`, product specification documents

- [x] **2.1** Regenerate and validate the catalog.
  - Change: update the focused terrain contracts and run the deterministic bake
    for all ten prepared resources.
  - Accept: all ten load with current identity and pass area, relief, active
    slope, goal landform, connectivity, ballistic, basin, and camera contracts.
- [x] **2.2** Verify the visible progression.
  - Change: capture planning frames for courses 1, 5, and 10.
  - Accept: each frame is broader than the prior compact form, retains strong
    vertical layering without needle-like internal walls, and shows goals on
    visible local crests rather than at the bottom of surrounding terrain.

Batch gate:

- Run the focused prepared-terrain and artifact tests, inspect the three real
  rendered frames, and perform a diff-scoped code-quality audit.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Focused generator build for courses 1 and 10 | A coherent generator change exists | Generator or constraint constants change |
| Phase gate | Deterministic ten-course bake | Both representative builds pass | Generator or authored catalog input changes |
| Final gate | Focused terrain/artifact tests and early/middle/late capture | Catalog bake passes | Source, artifact, or visual input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not run a physics-shot campaign or random-seed search.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Treat rendered captures as visual evidence, not as a replacement for the
  numeric generator contracts.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| Slope projection reduces relief below its band | Increase the deterministic terrain/feature radius inside the fixed 1.35 bounds before changing the 50-degree contract | Do not weaken the angle limit or ballistics |
| A goal crest conflicts with a flight corridor | Lower and broaden that generated crest role uniformly for the catalog | Do not hand-edit the course or move the camera |
| Expanded terrain breaks overview readability | Use existing generator-owned boom and flag channels on the expanded final grid | Do not edit the camera controller |
| A verified material fact contradicts this contract | Stop the affected branch and revise this contract | Do not choose a new product or validation contract during implementation |

Implementation-local discoveries may be handled inside the locked contract
when they cannot change scope, visible behavior, ownership, architecture,
safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: ten-course bake, focused prepared-resource checks, and
  rendered early/middle/late inspection.
- Update rule: update the completed task checkbox and this pointer together;
  do not repeat a passing check unless its relevant input changes.

## Completion and Stop Conditions

Complete when:

- Every task acceptance and named batch gate passes.
- Durable product constraints are recorded in their owning spec/decision docs.
- No task-owned temporary probe remains.
- Frontmatter status is changed to `done` after implementation and validation.

Completion evidence:

- All ten intrinsic generator builds passed area, relief, active-slope,
  summit-or-ridge, basin, ballistic, boom, and camera admission.
- One catalog bake regenerated all ten prepared resources; focused prepared
  terrain and artifact identity tests passed.
- Real 1280 by 720 planning captures for courses 1, 5, and 10 showed a broader
  connected mountain with retained vertical layering and crest-positioned goals.
- The diff-scoped quality audit found no competing owner or reachable contract
  gap after removing the disposable diagnostic probe and one unused helper.

Replan when:

- A material discovery invalidates the fixed extent, angle, or role contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
