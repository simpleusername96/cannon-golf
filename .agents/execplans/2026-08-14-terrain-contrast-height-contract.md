---
type: plan
status: done
created: 2026-08-14
scope: Restore readable terrain materials and enforced vertical terrain constraints in the ten prepared Cannon Golf courses
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-14-course-selection-ten-course-expansion.md
---

# Readable High-Relief Terrain - Execution Contract

The ten-course trajectory-first catalog remains the active fast authoring path,
but its prepared terrain must no longer render as clipped white and must again
enforce the accepted height contracts. The fix keeps deterministic sub-second
construction, rebuilds all prepared artifacts, starts the game, and inspects
real rendered frames.

## Purpose

- Objective: restore visible faceted terrain contrast and enforce course relief
  plus the accepted `deep_relay` upward-leg constraints.
- Deliverable: corrected generator, course palette defaults, prepared artifacts,
  lightweight contract checks, and rendered evidence for representative courses.
- Completion state: all ten artifacts build below 60 seconds, load at startup,
  satisfy their numeric height contracts, and representative real frames retain
  readable facet detail without white clipping.

## Scope and Boundaries

In scope:

- Terrain material colors stored in prepared meshes.
- Deterministic natural-height scaling and fail-closed relief validation.
- Each course profile's grid, horizontal bounds, origin, vertical scale, authored
  rim bands, and semantic landform features.
- `deep_relay` goal placement that preserves at least 80 m playable relief and
  at least 25 m rise from each incoming launcher to its goal rim.
- Non-monotonic goal elevation for the other multi-goal courses.
- Rebuilding the existing ten prepared resources.

Out of scope:

- Physics certification, solution robustness search, device placement, new
  course count, camera redesign, HUD redesign, or broad gameplay test suites.
- Changing global lighting to hide a bad course palette.
- Runtime terrain generation.

Constraints and invariants:

- Keep the accepted trajectory-first, one-pass construction model and the
  60-second per-course hard limit from D-033.
- Keep one connected heightfield-like terrain mesh, ordered goals, centered
  relay launchers, and immutable prepared artifacts.
- Keep the first two courses at their profile-owned `210 x 120` extent and use
  the profile-owned `210 x 320` extent for longitudinal courses; do not replace
  either with one catalog-global rectangle.
- Use the course profile's lower accepted height bound as the minimum relief;
  require at least 80 m for `deep_relay` and catalog courses 5-10.
- Only `deep_relay` requires every leg to rise at least 25 m. Other courses may
  rise or fall and must not be forced into a monotonic staircase.
- The terrain shader remains rough and non-emissive. Palette correction happens
  in course data, not by disabling lighting.
- Generated artifacts and captures remain small; validation uses bounded logs
  and leaves no task-owned Godot process running.

Destructive or irreversible actions:

- None. Prepared `.res` files are reproducible build products committed in the
  repository.

Exact actions requiring owner or user approval:

- None within this contract.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| White terrain | Prepared meshes retain `cannon_golf_terrain.gdshader`; maps using the default `#9DA6A3/#87938F` palette render with large fully white regions under the current environment, while the darker first course remains readable | Runtime material probe plus 1280x720 captures for courses 1, 3, 5, and 10 | Darken the shared default course palette to the established first-course range; preserve explicit per-course palettes | 1.1, 3.2 |
| Missing relief | `trajectory_course_generator.gd` records relief but never uses `terrain_vertical_scale`, `accepted_height_range`, or a minimum-relief rejection | Prepared relief values range from 27.0 to 67.8 m; courses 5 and 10 are 27.0 and 29.4 m | Normalize the deterministic natural field to a required relief before corridor and bowl conditioning, then reject final output below the same threshold | 1.2, 2.1 |
| Deep Relay contract | Canonical PRD and design rules require 80 m relief and +25 m per leg; current artifact is 59.1 m with +2.2/+18.0 m rim rises | `PRD.md` FR-15/AC-4 and runtime artifact probe | Select each Deep Relay intended trajectory against a minimum +25 m rim rise; never weaken the requirement or fake the metric | 1.3, 2.1 |
| General elevation order | The product permits goals to rise or fall; current fixed delta cycle provides both but has no explicit guard | User direction, D-033, current prepared leg deltas | Preserve at least one descending leg in every non-Deep-Relay course with three or more goals | 1.3, 2.1 |
| Course-owned geometry | The fast generator hardcodes one `64 x 96`, `210 x 320` grid and ignores profile bounds, scale, and origin; this replaces the first two courses' accepted `210 x 120`, `0.45` baseline | Profile resources, PRD FR-15, generator source trace | Derive the sample grid and world bounds from each course profile and scale/origin; keep the one-pass trajectory-first build | 1.2, 2.1 |
| Rim-height bands | Recipe legs still author low/middle/high bands, but the fast generator copies them only as metadata and does not shape or validate physical rim heights | Course leg resources and retired factory band shaping | Map authored bands to deterministic physical rim targets with at least 12 m between occupied adjacent bands and reject mismatched sealed output | 1.3, 2.1 |
| Semantic landforms | Course resources author peaks, terraces, valleys, basins, and saddles, but `_natural_height()` chooses only a catalog-index style and ignores those resources | `landform_features` resources and generator source trace | Apply every authored feature as a bounded deterministic deformation after the base field is fixed and record one keyed metric per feature | 1.4, 2.1 |
| Validation cost | The prior bake completed each map in 155-253 ms; current user limit is one minute and broad certification is excluded | Completed ten-course plan and D-033 | Run one bounded bake, one startup/catalog smoke, one lightweight terrain contract check, and four representative rendered captures | 2.2, 3.1, 3.2 |

Readiness statement:

- Every material, terrain, algorithm, ownership, and validation decision needed
  for this correction is closed.
- Godot 4.7.1, the repository bake script, the storage-safe validation wrapper,
  the startup/catalog smoke, and the rendered capture harness are available.
- Remaining unknowns are implementation-local tuning inside the locked numeric
  contracts.

## Tasks

### Phase 1: Restore generator contracts

Goal: make invalid color and height output impossible to bake silently.

Preconditions:

- Discovery evidence above remains reproducible from the current prepared files.

Source owners: `src/cannon_golf/course_data.gd`,
`src/cannon_golf/trajectory_course_generator.gd`,
`tests/cannon_golf_terrain_test.gd`

- [x] **1.1** Restore a readable default terrain palette.
  - Change: replace the washed-out default rock/accent colors with the darker
    established Cannon Golf terrain palette while retaining explicit course
    overrides.
  - Accept: newly baked default-colored meshes expose the exact course colors
    through their `ShaderMaterial`; shader emission remains absent.
- [x] **1.2** Enforce deterministic minimum relief.
  - Change: derive grid/bounds from the course profile, apply horizontal scale
    and origin, scale the natural heightfield using vertical scale before
    flight-corridor and goal conditioning, calculate final playable relief, and
    fail closed below the course threshold.
  - Accept: course profile lower bounds are met; `deep_relay` and courses 5-10
    are at least 80 m; the first two artifacts retain their `210 x 120` profile
    extent; no unbounded retry or candidate search is added.
- [x] **1.3** Restore goal-height rules without forcing global monotonic ascent.
  - Change: make trajectory selection include authored low/middle/high rim bands,
    the required rim-rise target for Deep Relay, and deterministic mixed
    rise/fall targets elsewhere.
  - Accept: both Deep Relay legs rise at least 25 m; every other course with at
    least three goals contains a descending leg; occupied adjacent rim bands
    differ by at least 12 m; every chosen point is on the descending half of its
    intended trajectory.
- [x] **1.4** Restore authored landform meaning.
  - Change: apply each peak, ridge, saddle, plateau, valley, basin, or terrace
    feature as a bounded deterministic deformation around its route-relative
    anchor, then reapply flight and goal protection.
  - Accept: every authored feature has one measured keyed result in the prepared
    artifact and visibly changes its intended region without disconnecting the
    heightfield.

Batch gate:

- `git diff --check` and the lightweight prepared-terrain contract script parse.

### Phase 2: Rebuild and verify all prepared courses

Goal: replace stale artifacts with outputs from the corrected generator.

Preconditions:

- Phase 1 acceptance and batch gate pass.

Source owners: `scripts/bake_cannon_golf_courses.gd`,
`resources/cannon_golf/prepared/*.res`

- [x] **2.1** Bake all ten artifacts once.
  - Change: run the repository bake through the storage-safe wrapper.
  - Accept: ten identity-valid artifacts are written, each reported generation
    duration is below 60,000 ms, and every artifact satisfies the relief and leg
    elevation checks.
  - Guard: on any failure or overrun, stop without extending the deadline.
- [x] **2.2** Confirm runtime loading.
  - Change: run only the startup/catalog instantiation smoke required by D-033.
  - Accept: the main scene starts and all ten prepared courses load and
    instantiate with no persistent log growth or leftover task-owned process.

### Phase 3: Inspect real pixels and finish

Goal: verify that the reported visual bug is gone in the actual renderer.

Preconditions:

- Phase 2 passes.

Source owners: `tests/capture_cannon_golf_frame.gd`, this contract

- [x] **3.1** Capture representative course frames.
  - Change: use the normal Compatibility renderer in background mode for
    courses 1, 3, 5, and 10 at 1280x720.
  - Accept: all four captures show readable facet variation and terrain/goal
    separation; no course surface is dominated by clipped white.
- [x] **3.2** Audit, record evidence, and commit.
  - Change: run the task-scoped quality audit, update this progress ledger, mark
    the plan done only after every gate passes, and create one scoped commit.
  - Accept: no task-owned process remains, no temporary diagnostic source is
    committed, and the commit contains only this correction.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `git diff --check` plus focused source inspection | Generator or course-data source changes | A relevant source changes |
| Bake gate | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://scripts/bake_cannon_golf_courses.gd -TimeoutSeconds 60` | Phase 1 passes | Generator, recipe identity, or artifact codec changes |
| Runtime gate | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_catalog_smoke_test.gd -TimeoutSeconds 30` | Bake succeeds | Runtime loading or artifacts change |
| Numeric gate | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_terrain_test.gd -TimeoutSeconds 30` | Bake succeeds | Terrain contract or artifacts change |
| Render gate | Run `tests/capture_cannon_golf_frame.gd` for course indices `0, 2, 4, 9`, state `planning`, 1280x720, then inspect all four PNGs | Runtime and numeric gates pass | Material, terrain geometry, environment, or camera changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not run solution replay, neighbor certification, or the broad suite.
- Rerun a failed gate only after a relevant implementation change.
- A startup pass cannot prove visual correctness; the four real rendered frames
  are mandatory for this visual correction.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A deterministic Deep Relay setup cannot reach +25 m while descending | Keep legal physics unchanged; adjust only its deterministic route distance and fixed intended setup inside the existing map bounds | Do not lower 25 m or add iterative physics search |
| Final relief falls below its threshold after corridor/bowl conditioning | Increase the bounded natural-field normalization once and rebuild; reject if still below | Do not manufacture the metric or omit corridor clearance |
| Darkened defaults still clip white | Inspect shader input and environment exposure from the new capture; change the shader only if pixel evidence proves palette correction insufficient | Do not globally dim lighting before that evidence |
| A material fact contradicts this contract | Stop the affected branch and update this contract | Do not redesign course gameplay implicitly |

## Progress and Next Steps

- Canonical progress: every task in this contract is complete.
- Current phase: complete.
- Next task: none.
- Last completed gate: rendered evidence and diff-scoped quality audit.
- Baseline rendered evidence: courses 1, 3, 5, and 10 captured at 1280x720;
  course 1 is readable, while courses 3, 5, and 10 contain clipped-white terrain.
- Baseline numeric evidence: prepared relief is `52.6, 58.3, 48.0, 59.1,
  27.0, 67.8, 54.5, 48.0, 58.7, 29.4` m; Deep Relay rim rises
  are `2.2` and `18.0` m.
- Final bake evidence: all ten courses constructed in `128-427 ms`; the storage
  wrapper reported zero persistent-log growth and zero owned processes.
- Final contract evidence: `cannon_golf_terrain_test.gd` passed for all ten
  prepared courses, including profile bounds, palette, goal bowls, 80 m late
  relief, Deep Relay's 80 m/+25 m rules, rim bands, landforms, and descending
  multi-goal legs.
- Final runtime evidence: `cannon_golf_catalog_smoke_test.gd` started the main
  scene and loaded/instantiated all ten artifacts.
- Final rendered evidence: new 1280x720 captures for courses 1, 3, 5, and 10
  retained readable green-gray facet contrast with no clipped-white terrain;
  the profile-owned short and longitudinal extents and large relief were visible.
- Quality audit: the changed generator remains the single owner of the bounded
  trajectory-first construction pipeline; no competing material, terrain, or
  persistence owner was added, obsolete constants and temporary diagnostics
  were removed, and task-scoped diff checks passed.
- Update rule: check a task only after its acceptance passes and record concise
  evidence in this section.

## Completion and Stop Conditions

Complete when:

- Every task and named gate passes.
- All ten maps build under one minute and load at startup.
- Numeric relief and Deep Relay rise constraints pass.
- Representative actual frames show readable, non-white terrain.
- The plan is marked `done` and one scoped commit is created.

Replan when:

- Legal ballistics cannot satisfy the accepted Deep Relay rise inside the
  current connected map bounds without changing gameplay physics.

Do not replan or stop for:

- Local deterministic tuning that remains inside these numeric and visual
  contracts.
