---
type: plan
status: done
created: 2026-08-14
scope: Fast trajectory-first generation and runtime delivery of the ten-course Cannon Golf catalog
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Fast Trajectory-First Ten-Course Catalog

## Purpose

Finish all ten selectable courses with a generator that completes each course
in less than 60 seconds. Remove the active dependency on large candidate
searches and repeated physics certification. Keep runtime loading immediate by
saving one prepared artifact per course.

## Scope and Boundaries

- Keep the existing ten-course order and goal counts: `1, 1, 2, 2, 3, 3, 4,
  4, 5, 6`.
- Keep one connected, pale, faceted mountain terrain per course.
- Keep ordered goals, persistent completed goals, and the next launcher centered
  on the completed goal.
- Construct each leg from a small deterministic set of intended shot setups.
  Compute the trajectory first, place the goal on its descending section, then
  build terrain below the flight corridor.
- Generate peaks, shelves, valleys, and basins only after launcher, trajectory,
  and goal constraints are fixed.
- Preserve prepared-artifact loading for preview and gameplay. Do not generate a
  course when the player clicks a course card.
- Do not run exhaustive solution, robustness, rendered-capture, or physics
  certification suites in this task.

## Discovery Closure

- The current blocker is architectural, not a missing timeout. The old active
  path can examine up to 180 candidates per leg and then run repeated live
  physics attempts. It has already taken minutes for one course and therefore
  cannot satisfy the user's one-minute course-generation limit.
- The deterministic ballistic model can cheaply calculate intended flight
  height before terrain exists. This is sufficient for constructive placement;
  terrain no longer needs to be generated and rejected repeatedly.
- Runtime already consumes identity-checked prepared resources. That boundary
  remains useful and avoids the course-selection stall.
- The accepted simplification supersedes D-032's mandatory exhaustive offline
  certification for this catalog. A prepared course instead records its
  trajectory-construction version and intended setup.

## Tasks

- [x] **1. Replace the active authoring path.** Add a trajectory-first generator
  and a prepared-artifact construction contract. Keep the old resolver and
  certifier out of the bake and runtime paths.
- [x] **2. Build terrain once.** For every course, derive ordered launcher and
  goal positions, carve retaining bowls, protect the intended flight corridors,
  add deterministic terrain relief, and create render/collision geometry once.
- [x] **3. Bake all ten courses.** Enforce a measured 60-second hard limit for
  each course. Stop immediately and save no invalid artifact if any course
  exceeds the limit.
- [x] **4. Run the narrow runtime check.** Confirm that the project starts and
  every catalog course can load and instantiate its prepared artifact. Do not
  replay solutions or run the broad suite.
- [x] **5. Audit and hand off.** Review the changed generator/artifact boundary,
  update this progress ledger, and create one scoped commit.

## Validation and Rework Controls

- All Godot commands use `scripts/invoke-cannon-golf-validation.ps1` so a crash
  cannot leave processes or persistent logs behind.
- The bake prints elapsed milliseconds for each course and fails if a value is
  `60000` or greater.
- Run the bake once. Fix and rerun only when the first run exposes a concrete
  parse, serialization, or construction error.
- The only gameplay validation is a startup/catalog instantiation smoke check.
- A passing smoke check proves loading and construction only. It does not claim
  that every intended shot is robust or that final play feel is tuned.

## Predetermined Contingencies and Change Control

- If a course cannot be constructed within 60 seconds, stop. Do not increase
  the limit, enlarge the search, or start physics certification.
- If a fixed shot choice cannot produce a valid descending goal point, try the
  next item in the generator's small fixed setup table. If all entries fail,
  reject that course.
- If an artifact is stale or malformed, regenerate it from the same course
  resource. Runtime generation remains forbidden.

## Progress

- Course selection, asynchronous prepared-resource loading, ten catalog entries,
  multi-goal progression, centered relay launchers, and the compact goal tally
  are already implemented in the current worktree.
- Storage-safe validation containment is already implemented.
- The prior resolver/certifier experiment produced only part of the catalog and
  is now retired from the active path.
- All ten current artifacts were rebuilt by the trajectory-first generator. The
  final measured per-course times were `155, 194, 212, 210, 217, 235, 229, 253,
  238, 247 ms`; the maximum was `253 ms`.
- The startup/catalog smoke loaded the configured main scene and instantiated all
  ten identity-checked course artifacts. Persistent log growth and owned process
  count were both zero.
- The post-pass made goal centers and the initial launcher support locally exact
  on the sampled heightfield and updated stale certificate-only test assumptions.

## Next Steps

No implementation work remains in this plan. Visual tuning and physical
solution certification are deliberately outside its accepted validation scope.

## Completion and Stop Conditions

Complete only when ten current prepared artifacts exist, every measured course
generation is below 60 seconds, the startup/catalog smoke check passes, and no
task-owned Godot process or persistent log remains. Stop immediately on a
60-second course overrun or an unsafe storage/process condition.
