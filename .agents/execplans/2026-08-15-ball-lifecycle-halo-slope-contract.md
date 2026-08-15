---
type: plan
status: done
created: 2026-08-15
scope: Reliable live-ball resolution, always-readable aim halo, and enforceably gentle prepared-course terrain
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-15-gentle-course-scale-aim-halo.md
---

# Ball Lifecycle, Halo Readability, and Terrain Slope Contract

## Purpose

Correct the three remaining gameplay defects as one measurable contract: a ball
must not disappear merely because it rebounds out of a goal or remains live for
ten seconds; the floating yaw-and-elevation halo must remain readable in normal
planning and cannon views; and every prepared course must preserve mountain-scale
relief without the cliff-like local slopes left by the previous horizontal-only
stretch.

## Scope and Boundaries

In scope:

- Separate goal settlement candidacy from terminal launch resolution. Goal exit
  cancels the current settlement attempt but leaves the ball live and eligible to
  enter the same or another incomplete goal.
- Resolve a live ball only after confirmed success, explicit out-of-bounds,
  manual retry/reset, or a stable two-second rest outside every incomplete goal.
  Retain a 15-second leak guard only for a projectile that never records a valid
  surface contact; no absolute timeout applies after first contact.
- Keep the floating world-space halo visible in both overview/planning and cannon
  aiming views, with unshaded high-contrast geometry, a no-depth readability
  accent, adequate screen thickness, and yaw plus elevation state.
- Correct trajectory-course generation rather than expanding the map again:
  scale semantic landform footprints with horizontal course scale, remove hard
  four- and six-metre terrace steps, cap excess macro relief, and apply bounded
  feature-preserving filtering/slope projection while protecting start and goal
  support regions.
- Regenerate all ten prepared course artifacts from the final shared height array
  and certify the same array drives visual mesh and collision.
- Update superseded product decisions, focused regression tests, capture tooling,
  and this execution record.

Out of scope:

- A new physics engine, exact deterministic trajectory assertions, hydraulic
  erosion simulation, course-count changes, or a camera-system redesign.
- Another global map-size increase, further ball/cannon enlargement, or another
  ballistic power multiplier unless final generated-course certification proves
  a specific route unreachable.
- A screen-space aiming overlay. It remains a fallback only if the world-space
  contract fails rendered acceptance after five bounded iterations.

## Discovery Closure

### Current causal paths

- `CannonGolfGame._update_live_ball()` treats leaving a goal rebound column after
  any entry as terminal `bounced_out`, then deferred-frees the ball. It also
  resolves near-still motion after only 0.625 real seconds because the timer is
  divided by the global motion scale.
- `CannonGolfBall._physics_process()` emits `timeout` at ten seconds regardless
  of valid terrain contacts. A slow multi-bounce shot can therefore disappear
  while visibly inside the course.
- `CannonGolfLauncher.set_first_person_visuals_hidden()` explicitly hides the aim
  halo in cannon view, and the existing test requires that obsolete behavior.
  The remaining dark, shaded, 0.18 m ring is sub-pixel in ordinary overview
  captures; the forced close-up capture hid this acceptance gap.
- The previous change expanded heightfield coordinates to 1.50-2.25 times the
  inherited scale, but semantic feature radii stayed at roughly 24-46 m. The
  generator rounds some heights into hard 4 m and 6 m terraces, and its relief
  normalization only raises deficient relief; it never lowers excess relief.
- A direct audit of the current ten generated arrays found p95 adjacent-sample
  slope from 43.0 to 77.8 degrees, maxima from 66.9 to 87.7 degrees, and 3.0% to
  15.1% of samples above 45 degrees. The late-course relief reaches 247.5 m
  against a nominal 160 m target. The defect is local generation and uncontrolled
  excess relief, not insufficient outer bounds.

### Candidate families considered

| Problem | Candidate | Decision |
| --- | --- | --- |
| Ball lifetime | Increase the existing timers | Rejected: leaves goal exit terminal and merely delays the same defect. |
| Ball lifetime | Add a larger goal-exit hysteresis column | Rejected as sole fix: reduces false exits but still conflates candidacy and launch resolution. |
| Ball lifetime | Explicit live/candidate/settled lifecycle | Selected: matches overlap semantics and permits continued play after rebound. |
| Halo | Only enlarge the current shaded ring | Rejected: lighting, depth, culling, and first-person hiding remain failure paths. |
| Halo | Screen-space compass | Deferred: robust but loses the requested floating base-halo relationship. |
| Halo | High-contrast unshaded world halo with no-depth accent | Selected: preserves the spatial instrument and makes readability an explicit render contract. |
| Terrain | Expand X/Z again | Rejected: fixed local radii and hard terrace steps remain steep while camera and ballistics costs grow. |
| Terrain | Global box/Gaussian blur | Rejected: indiscriminately shrinks broad relief and softens authored anchors. |
| Terrain | Full hydraulic/thermal erosion | Deferred: large semantic and performance expansion for a bounded slope defect. |
| Terrain | Generation-scale correction plus constrained filtering and slope projection | Selected: fixes the causes, preserves broad mountain form, and admits deterministic metrics. |

### Locked implementation contract

- Goal overlap is a settlement candidate, not a terminal fact. On exit, clear the
  candidate goal index, dwell time, and temporary settlement drag; do not remove
  the ball. A later overlap may select any incomplete goal.
- Outside all goals, both sleeping and near-still states must persist for 2.0
  real seconds before `stopped_outside`. Out-of-bounds remains immediate. The
  15-second timeout is valid only before the first accepted terrain/goal contact.
- The halo remains slightly above the sampled launch surface and shows yaw and
  elevation in both planning cameras. Physical launcher meshes may hide in
  cannon view; the halo may not. Its render owner must use unshaded color,
  disabled shadow casting, a high-contrast palette, and a thin no-depth-tested
  accent or equivalent proven by ordinary-view captures.
- Prepared terrain acceptance per course is: p95 adjacent-sample slope at most
  42 degrees, maximum at most 60 degrees, no more than 3% of samples above 45
  degrees, and total relief within `[target, target + 16 m]`. Protected start and
  goal support samples must remain within their existing clearance/tolerance
  contracts. If the maximum limit cannot be reached without harming anchors,
  revise feature amplitude/radius before increasing filtering iterations.
- All slope metrics use the actual X/Z sample spacing and the final shared height
  array. Tests assert ranges and invariants, not exact rigid-body trajectories.

## Tasks

- [x] Phase 1 — Record the superseding lifecycle, halo visibility, and terrain
  slope decisions in canonical specs; add focused failing tests for goal-exit
  continuation/re-entry, post-contact timeout immunity, ordinary-view halo
  visibility, and final-array slope/relief limits.
- [x] Phase 2 — Implement the live-ball settlement-candidate state machine and
  timeout/rest policy; pass focused lifecycle and existing session/goal checks.
- [x] Phase 3 — Implement the halo render/visibility contract; capture and inspect
  real planning and cannon states on early, middle, and late courses, not only a
  forced close-up.
- [x] Phase 4 — Implement the generation slope contract, regenerate all ten
  prepared artifacts once, re-certify terrain/goal/ballistics/camera behavior,
  run the task-scoped quality audit and final production-style verification,
  mark this plan done, and commit only task-owned changes.

## Subagent Execution Boundaries

- A lifecycle worker owns `golf_ball.gd`, `live_shot_state.gd`, the lifecycle
  portions of `cannon_golf_game.gd`, and focused lifecycle tests. It must not edit
  halo, terrain, prepared artifacts, canonical docs, or unrelated dirty UI files.
- A halo worker owns the launcher/halo visibility and material path plus focused
  halo assertions/capture states. It must not edit lifecycle, terrain, prepared
  artifacts, canonical docs, or unrelated dirty UI files.
- A terrain worker owns `trajectory_course_generator.gd`, its slope audit/test,
  and the bake script only if required. It must not regenerate artifacts until
  the parent reviews the generator and authorizes the single shared bake.
- The parent owns canonical documents, prepared artifact regeneration,
  integration, rendered evidence review, quality audit, final gates, plan status,
  staging, and the scoped commit. Subagents stop after focused evidence and report
  exact files and commands.

## Validation and Rework Controls

- Cheap checks use `scripts/invoke-cannon-golf-validation.ps1 -Script <test>
  -TimeoutSeconds 60`; the full ten-course physical-goal test may use 180 seconds.
- Phase 2 must exercise: goal entry then exit without removal; re-entry into the
  same and another incomplete goal; no timeout after first contact; explicit
  out-of-bounds; and two-second stable-rest failure.
- Phase 3 must capture actual `planning` and `cannon` states for course indices 0,
  3, and 9 at 1920x1080. Inspect halo presence, yaw/elevation distinction,
  terrain readability, launcher silhouette, clipping, and UI overlap.
- Before the single shared bake, run the slope audit in memory across all ten
  definitions. Bake only after every course satisfies the locked metrics.
- After the bake, run terrain preparation/build, catalog, ballistics, goal,
  camera, app-flow, world-environment, and relevant UI contracts. Use 180 seconds
  for known long suites. Do not rerun a passing check unless its relevant input
  changes.
- Final handoff requires `scripts/verify.ps1`, a diff-scoped quality audit, no
  parser/import/runtime errors, inspected rendered evidence, and a clean
  task-owned commit. Preserve the pre-existing theme/menu/UI-test edits and UID
  files outside this task.
- Stop a repeated halo or terrain tuning loop after five evidence-backed attempts
  and report the exact remaining metric/visual defect rather than silently
  relaxing this contract.

## Predetermined Contingencies and Change Control

- If `RigidBody3D.sleeping` proves noisy, retain the same two-second contract and
  use the existing linear/angular near-still thresholds as the fallback signal;
  do not shorten the dwell.
- If a no-depth accent reads through distant mountains, restrict it to the yaw
  tick/elevation bead or use a depth-tested broad ring plus a narrower accent;
  do not hide the halo in cannon view.
- If constrained smoothing alone misses a slope limit, first widen semantic
  feature radii, then reduce local amplitude, then add bounded slope-projection
  iterations. Do not enlarge outer bounds or violate protected supports.
- If a route fails after gentling, adjust its local support/corridor within the
  same slope and relief contract before changing cannon power. Any global scale,
  ball size, launcher size, power curve, or acceptance-limit change requires a
  recorded plan revision with evidence.

## External Sources

- [Godot 4.7 RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html): sleeping state and continuous collision behavior.
- [Godot 4.7 Area3D](https://docs.godotengine.org/en/4.7/classes/class_area3d.html): body entry and exit are overlap events, not gameplay terminal events.
- [Godot 4.7 physics troubleshooting](https://docs.godotengine.org/en/4.7/tutorials/physics/troubleshooting_physics_issues.html): collision robustness options and non-deterministic physics guidance.
- [Godot StandardMaterial3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html) and [BaseMaterial3D](https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html): unshaded and no-depth-test indicator behavior.
- [Godot 4.7 HeightMapShape3D](https://docs.godotengine.org/en/4.7/classes/class_heightmapshape3d.html): regular-grid collision constraints.
- [Taubin, 1995](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Taubin95.pdf): non-shrinking low-pass surface filtering and broad-form preservation.
- [Tasdizen and Whitaker, 2003](https://www.sci.utah.edu/~tolga/pubs/Tasdizen_Terrain03.pdf): terrain-specific feature-preserving smoothing and risks of image-space stair-stepping.

## Progress and Next Steps

- Completed: code, current specifications, recent implementation history,
  generated height arrays, official Godot documentation, and primary terrain
  filtering research were inspected. Root causes and candidate families are
  decision-complete above.
- Completed: PRD, design rules, and D-040 now supersede the terminal bounce-out,
  hidden-cannon-halo, and horizontal-stretch-only assumptions. Focused lifecycle,
  halo, and terrain-slope contracts exist.
- Completed: goal exit now revokes only the settlement candidate, valid contact
  disables the no-contact leak timer, and outside rest requires exactly two real
  seconds. Lifecycle, rigid-body, physical-goal, and multi-goal checks pass.
- Completed: the halo remains visible while cannon view hides only the launcher
  body. Planning captures show the raised cyan ring, amber yaw tick, and elevation
  arc; cannon captures use a bounded 12% marker LOD so near-camera dots remain
  legible instead of becoming a second-barrel-sized obstruction.
- Completed: semantic landforms widen with the course, terrace quantization is
  removed, constrained filtering/projection enforces the final slope and relief
  bands, and a grid-spacing margin keeps every goal shoulder continuously flat.
  All ten prepared artifacts were regenerated from the final shared height array.
- Completed: whole-terrain admission now truthfully records admitted, excluded,
  and unadmitted points while authored corridors retain the full hard guards.
  The final rendered early/middle/late courses have connected open ground, no
  white patch, readable goals, and visibly gentler macro slopes.
- Completed: the focused lifecycle/halo/terrain/range/artifact/goal/camera/input/
  session/relay/solution/UI/settings/app checks pass. `scripts/verify.ps1` passes
  import, script parsing, and main-scene startup. The diff-scoped quality audit
  found no remaining task-owned responsibility or reachable failure-path defect.
- Next: none; implementation and acceptance are complete.

## Completion and Stop Conditions

Complete only when all four tasks are checked; bounce-out no longer removes a
live ball; ordinary planning and cannon captures show the floating yaw/elevation
halo; all ten final arrays meet the slope, relief, anchor, reachability, and
visual/collision identity contracts; final verification passes; and one scoped
commit contains only task-owned changes.
