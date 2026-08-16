---
type: plan
status: superseded
superseded_by: .agents/execplans/2026-08-16-constrained-mountain-terrain.md
created: 2026-08-15
scope: Cannon Golf resolved-ball cleanup, stable goal basins, two-axis aim indication, and broad tenfold terrain relief
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-15-goal-clear-pace-halo.md
  - .agents/execplans/2026-08-15-ball-lifecycle-halo-slope-contract.md
  - .agents/execplans/2026-08-15-normal-camera-course-variety.md
---

# Ball Cleanup, Goal Basins, Partial Aim Arc, and Macro Relief — Execution Contract

The current build already removes a ball that rests outside a goal, but it retains a confirmed ball as progress state. A goal owns a raised physical floor and segmented fence whose visible segment count changes after confirmation. The current launcher halo is a large closed ring with a curved dotted tail; at ordinary overview scale it resembles another goal and does not communicate launch direction. The terrain generator limits total relief to 60–160 metres plus a small margin and flattens a broad support apron under every physical plate. This contract replaces those four behaviours without adding bounce pads, damping pads, wind, gravity devices, an exact landing prediction, or a new camera system.

## Purpose

- Objective: leave only first-contact impact marks after every resolved ball, keep completed goals spatially stable, make full yaw and pitch immediately readable, and make the ten maps broadly mountainous rather than locally carved.
- Deliverable: aligned product records, runtime and generator changes, regenerated prepared-course artifacts, focused regressions, and rendered Godot evidence.
- Completion state:
  - every failed or confirmed stationary ball is removed from the world while its existing first-contact mark remains;
  - each goal is a smooth terrain-owned basin with no physical fence, and its terrain, boundary, and floor never change on completion;
  - a large, thin, partial ballistic arc begins above the cannon and ends in a thick tangent arrow, so the combined yaw and pitch direction is readable without revealing the complete flight or landing point;
  - the generated terrain has ten times the currently contracted world-height relief, distributed through broad landforms while the accepted slope limits and gameplay route scale remain intact.

## Scope and Boundaries

In scope:

- Confirmed-ball ownership and cleanup, completed-goal progress state, launcher-source selection, and first-contact mark retention.
- Goal containment and settlement polling on terrain, terrain basin construction and metadata, goal marker state, and removal of the physical plate/fence owner.
- The existing `CannonGolfAimHalo` responsibility, its overview and cannon-view presentations, and aim-related presentation bounds.
- Macro terrain bounds, height synthesis, conditioning, slope/relief gates, course identity, prepared artifacts, and overview-camera framing/safety derived from the larger terrain.
- Canonical product and design records that currently require retained balls, a physical plate/fence, the old halo grammar, or the old relief schedule.

Out of scope:

- Bounce pads, damping or slow pads, wind, altered gravity, moving hazards, portals, or other course devices. D-042 remains in force: these stay deferred until the basic terrain and camera foundation is accepted.
- Ball power, launch-speed range, damping, the doubled local motion pace, gravity, collision size, settlement dwell duration, unlimited firing, and full-direction aim ranges.
- A complete-flight trajectory, predicted landing point, range overlay, second barrel, or full-screen aim HUD. The short launch-direction arc and its connected arrow are explicitly in scope.
- A new camera mode or a wholesale camera rewrite. Existing overview, cannon, and shot-follow responsibilities remain.
- Menu, theme, course-select, and unrelated HUD redesign work.
- New dependencies, downloaded art, or external runtime services.
- Task-pre-existing modified theme/menu/UI-contract files and Godot-generated untracked `.gd.uid` sidecars. Their ownership is unverified; implementation must neither stage nor modify them unless a later task explicitly puts them in scope.

Constraints and invariants:

- “Leave only the mark” means retain the existing first valid terrain-contact mark. Do not create a second final-rest or goal-confirmation mark.
- Multiple balls remain independent. Resolving one ball must not remove, freeze, retarget, or mutate any other live ball.
- Completed-goal progress is stored as goal identity/index data, never as a retained `Node3D` reference.
- A goal basin uses the shared render/collision height array. It has no separate floor collision, retaining wall, lip collision, or state-dependent terrain geometry.
- Completion hides the airborne arrow and updates the HUD tally only. The flag, basin geometry, basin material, apparent boundary, and collision remain unchanged.
- The aim guide is world-space geometry that starts `12 m` above the launcher and follows the current yaw, pitch, and power for only the first part of flight. The raised origin preserves readability and prevents the cue from claiming an exact muzzle-to-impact prediction. It does not become a screen-corner widget.
- The thin arc stays depth-tested. Only the connected arrowhead may bypass depth testing, so the direction remains legible without making the whole path visible through terrain.
- The current p95, absolute-maximum, and high-slope-share limits remain `42°`, `60°`, and `3%` above `45°`.
- Route positions, goal order, authored leg count, ballistic admission, route-derived out-of-bounds behaviour, and gameplay horizontal scale remain unchanged. Macro terrain may extend beyond the route and play envelopes.
- Intermediate confirmation preserves unrelated live balls. Final stage clear retains the accepted D-041 cleanup and may remove all remaining live balls.
- Tenfold relief is literal world-height relief relative to the accepted D-039 schedule: `600, 650, 800, 900, 1000, 1120, 1240, 1360, 1480, 1600 m`, with a `5%` upper tolerance. It is not produced by multiplying goal depth or local noise amplitudes.

Destructive or irreversible actions:

- Regenerating the ten prepared course artifacts replaces derived binary resources. Keep the current artifacts until all ten newly generated courses pass staged generation, geometry, route, identity, camera, and performance gates. Promote them through the rollback-safe staged process only after that gate passes.

Exact actions requiring owner or user approval:

- Explicit user authorization to execute this planning-only contract is required before any specification, runtime, test, or prepared-artifact change. That authorization covers the rollback-safe artifact replacement described here; it does not authorize unrelated dirty files.
- Stop and request a contract revision before changing ballistics, relaxing the three slope limits, reducing the literal tenfold relief target, adding a second terrain representation, or introducing an unplanned gameplay device.

## Discovery Closure

### Verified current behaviour and locked decisions

| Requirement or concern | Verified current owner and behaviour | Locked decision | Task IDs |
| --- | --- | --- | --- |
| Stationary failed balls | `CannonGolfGame` already resolves a ball after two continuous seconds of stable rest outside every goal and calls `queue_free()`; `ImpactHistory` retains the first-contact mark | Preserve this path and its timing; unify confirmed resolution with the same node-removal result | 2.1, 2.2 |
| Confirmed balls | `_confirm_goal()` freezes the winner, puts it in `confirmed_balls`, and removes only its live-ball bookkeeping; tests require the frozen node to remain | Replace node-backed progress with completed goal indices/count; after confirmation bookkeeping and mark retention are secure, remove the winning ball node | 1.2, 2.1 |
| Impact history | `ImpactHistory` stamps one mark on the first valid terrain contact and retains at most five | Keep this semantic exactly; do not stamp settlement or deletion. A mark persists until the existing five-mark FIFO limit evicts it | 2.1, 2.2 |
| Changing goal fence | `SettlementGoal` creates a static floor plus 13 wall segments; `_apply_visual_state()` deliberately displays 13 active, 7 future, and 4 confirmed rim markers | Delete the physical floor/fence and the state-dependent rim-marker grammar; completion cues never mutate the basin or its boundary | 1.1, 3.5 |
| Current goal terrain and metadata | `_fit_goal_plate_support()` flattens a large apron at `goal_y - 0.18 m`; generated/prepared legs store `goal_rim_y` and a required raised `goal_lip_y`; authored `3.5..4.5 m` recess data is not the active topology | Replace the apron and old rim/lip fields. `goal_position.y` is the basin floor, `goal_radius` is the near-flat scoring radius, `basin_shoulder_y` is the outer terrain join height, and `basin_outer_radius` is the join radius. Retain one flush non-colliding landing disc | 3.4, 4.3 |
| Current halo | `CannonGolfAimHalo` uses a `13 m` full ring at `12 m` float height plus a spatial semicircle of 17 dots; the full ring accent and all dots bypass depth | Replace every ring, dot, and bead with one continuous thin partial launch arc and one thick connected tangent arrow | 2.3 |
| Aim scale | The current halo becomes another small dark circle in full-course framing and does not show the combined launch direction | Draw the first `0.55 s` of the current damped ballistic path, capped before any predicted impact, with a minimum `32 m` visible chord and a maximum `95 m` path length; use a thick arrow that remains readable in overview | 2.3, 4.2 |
| Terrain relief | The generator accepts per-course relief of `60..160 m` plus `16 m`; later terrain is about `472.5 × 720 m` with an `861 m` diagonal | Multiply the contracted relief by ten. Preserve slopes by separating the route envelope from a larger macro-terrain envelope rather than carving local cliffs or scaling ballistics | 3.1, 3.3 |
| Mathematical feasibility | `1600 m` over the current `861 m` diagonal implies about `61.7°` average end-to-end slope. A `42°` run requires at least `1778 m` | Grow each terrain envelope, at the current aspect ratio, until its diagonal is at least `1.10 × relief / tan(38°)`; the late-course example is about `2253 m`, or `2.62×` its current diagonal. Never shrink below existing bounds. The `38°` design target gives margin below the `42°` p95 gate | 3.1 |
| Spatial-bound coupling | One `local_bounds` currently drives route placement and heightfield construction; `content_bounds` drives framing/pan/world envelope, while `play_bounds` owns ball-lifecycle space | Preserve the current pre-expansion rectangle as `route_bounds`; use `terrain_bounds` for the expanded heightfield, physical `content_bounds` for far clip/fog/safety, unchanged route-derived `play_bounds` for ball resolution, and stored `overview_frame_points` plus diagnostic bounds for point-based overview framing/pan | 3.1, 4.1, 4.2 |
| Competing terrain owner | `TrajectoryCourseGenerator` is the prepared-catalog path, but `CourseTerrainFactory` still owns an alternate raised-lip generator and several shared admission helpers used by tests and the canonical generator | Make `TrajectoryCourseGenerator` the only terrain-generation owner, extract the still-live admission helpers into `CannonGolfTerrainAdmission`, migrate their callers/tests, and retire the alternate factory and raised-lip code | 3.2, 3.4 |
| Artifact replacement | `scripts/bake_cannon_golf_courses.gd` saves each generated course directly over its canonical `.res`, so a later failure leaves a mixed batch | Add an explicit staging-output path, validate the complete staged catalog, save a task-owned rollback copy, promote all ten, then revalidate canonical paths; restore the copy immediately if any promotion/load check fails | 4.3 |
| Deferred devices | D-042 already defers bounce, damping, wind, and gravity features | Preserve this explicitly in PRD, design rules, and the superseding decision | 1.1 |

### Reference-backed visual decision

Current visual evidence:

- `.godot/capture-temp/goal-clear-pace-halo-final/course0-planning-1280.png`: the halo's closed dark circle has the same grammar and similar footprint as a goal ring.
- `.godot/capture-temp/goal-clear-pace-halo-final/course0-halo-extreme-1280.png`: the ring and dotted semicircle read as a floating target with a tail, not as two independent angle scales.
- `.godot/capture-temp/normal-camera-course-variety/course-9-planning-1280x720.png`: at complete-course scale the current terrain silhouette remains shallow and repetitive.
- `.godot/capture-temp/goal-plate-final/course-0-planning.png`: the previous localized goal treatment shows the placed-ring/crater language that must not return.

External reference families retained for terrain and rendering implementation:

| Reference | Useful principle | Accepted use here |
| --- | --- | --- |
| [Godot `ImmediateMesh`](https://docs.godotengine.org/en/4.7/classes/class_immediatemesh.html) | A generated line strip can follow a small sampled path without adding scene-node clutter | Build one deterministic sampled arc from the live ballistic setup |
| [Godot `BaseMaterial3D`](https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html) | Depth testing and unshaded rendering are independent | Keep the arc depth-tested and permit no-depth only on the arrowhead |
| [Terrain Sketching](https://pubs.cs.uct.ac.za/id/eprint/516/) | Large terrain identity comes from authored mountain silhouettes, spines, and valleys before small stochastic detail | Build broad per-course ridge/valley masks before restrained noise |
| [Red Blob Games: terrain from noise](https://www.redblobgames.com/maps/terrain-from-noise/) | Noise shaping and low-frequency components control large landforms; unstructured octave stacking alone produces weak, generic topography | Reserve most new amplitude for low-frequency masks and do not multiply local noise |
| [Taubin surface smoothing](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Taubin95.pdf) | Constrained smoothing can remove local artifacts without collapsing the intended large form | Condition local slopes after macro synthesis while protecting only small semantic anchors |

Selected aim grammar:

```text
                         thick arrow follows the end tangent
                                           ▶
                                      ____/
                                ____/
                          _____/
              CANNON   ●__/   raised guide origin

              thin, large, early-flight arc only
              no endpoint, impact marker, range ring, or full path
```

Locked presentation rules:

- Geometry: start `12 m` above the launcher and sample the current damped ballistic recurrence at fixed time intervals up to `0.55 s`. Stop earlier at `95 m` accumulated length; when terrain intersects the cue, reserve the final segment for the connected arrow so its tip meets the obstruction. Never extrapolate to a goal or landing point.
- Visibility: show at least the first `32 m` chord when it remains inside the world safety envelope. The resulting curve is intentionally large but partial. The line is `#102A43`, unshaded, shadow-free, and about `0.32 m` thick in world space.
- Arrow: connect a solid `#FFD05C` arrowhead directly to the final curve sample and align it with the final sampled tangent. Its length is `7 m`, its maximum width is `3.5 m`, and only this compact head may ignore depth.
- Full-direction behaviour: yaw rotates the whole curve around world Y; pitch changes its initial tangent from `-90°` through `+90°`. At exact vertical aim the stored yaw remains stable and the curve remains finite.
- Power: power changes curvature and sampled distance because the guide uses the live launch velocity. The guide still ends by time/length cap and never claims a landing point.
- Cannon view: hide the large world arc to prevent near-plane obstruction; retain the existing compact centre reticle and the barrel's physical direction.
- Framing: `presentation_radius()` and `presentation_top_height()` return conservative fixed bounds for the maximum partial arc and arrow. They never depend on a predicted impact.
- Rejected: any ring, dotted scale, bead, complete flight, landing marker, impact estimate, pure screen-corner direction widget, or second-barrel silhouette.

Selected goal topology:

```text
                  broad terrain shoulder
              ___/                       \___
            _/                               \_
          _/      smooth C2 transition         \_
         /                                       \
        |          near-flat goal floor          |
        |          flag + containment zone         |
         \_______________________________________/

        no fence, no raised lip, no separate collision floor
```

For radial distance `r`, central floor radius `r_flat`, outer shoulder radius `r_rim`, and authored depth `d`:

```text
u = clamp((r - r_flat) / (r_rim - r_flat), 0, 1)
s = 6u^5 - 15u^4 + 10u^3
height(r) = floor_y + d * s
```

- `goal_position.y` is the exact floor height; `goal_radius` is the flat scoring/containment radius; `basin_shoulder_y = goal_position.y + depth`; and `basin_outer_radius = goal_radius + transition_width`. Remove `goal_rim_y` and `goal_lip_y` rather than carrying false compatibility semantics.
- Depth stays in the already authored `3.5..4.5 m` band; the tenfold macro relief does not deepen goals.
- The transition width is at least seven terrain cells and `24 m`; widen it further when needed so the sampled bowl stays at or below `20°`. This covers the quintic profile's maximum derivative at the deepest accepted `4.5 m` basin.
- The floor is near-flat and wide enough for the existing `contains_ball()` polling and settlement rules; no `Area3D` trigger is introduced.
- Basin outer circles must be separated from each other and from the full `START_SUPPORT_RADIUS` disk, including its blend region, by at least two terrain cells. The ordered route/setup candidate chooser tries its next deterministic candidate when this guard fails; overlapping supports or basins are never blended.
- There is no raised lip, entry-gap wall, or state-dependent rim. The basin joins the surrounding terrain with zero first and second derivative at both endpoints.
- A thin flush visual disc identifies the scoring floor, but it has no body, collision, height offset, or completion-state geometry or material change.

Selected macro-terrain topology:

```text
       broad summit / ridge                  broad summit
                  ________               ______
              ___/        \____     ____/      \___
         ____/                  \___/               \____
        /        playable route and goal basins           \
       /___________________________________________________\

       one connected heightfield; no isolated vertical cuts
```

- Keep the existing route/play envelope and ballistic distances.
- Derive a larger terrain envelope from the tenfold target and the `38°` design slope. This extra area carries the high/low macro silhouettes and provides the required horizontal run.
- Synthesize one or more course-specific ridge, saddle, valley, tilted plateau, or broad basin masks at wavelengths of at least `35%` of the relevant terrain dimension.
- Define `legacy_local_field` as the current-amplitude natural/noise/authored-feature field before any new macro mask or semantic support. At every sample, record `macro_delta` from the new low-frequency masks and `new_local_delta` from any added shorter-wavelength contribution. Require `sum(abs(macro_delta)) / (sum(abs(macro_delta)) + sum(abs(new_local_delta))) >= 0.85`. Keep legacy local/noise amplitude at its current absolute scale.
- On the final height array, exclude goal basins, the start-support disk, and the one-cell outer boundary, sort the remaining samples with nearest-rank quantiles, and require `p90 - p10 >= 0.65 × (global_max - global_min)`.
- Build `height >= p90` and `height <= p10` masks over those eligible samples with 4-neighbour grid connectivity. The largest connected component in each mask must cover at least `3%` of eligible samples, so isolated spikes and holes fail closed.
- Complete macro normalization, global relief rebalance, and broad slope conditioning before stamping start support and goal basins. Align each reserved goal shoulder to `basin_shoulder_y`, stamp the basin, then run only a local slope projection that locks floor and shoulder anchors. No global rescale, diagonal bias, or other height modification may run afterward.
- Sample every intended ballistic path against the final heightfield at intervals no larger than half a terrain cell, including each incoming basin shoulder. Preserve the existing corridor clearance outside the accepted landing interval and fail closed before certification when any shoulder intrudes.
- Preserve the current slope gates and route-clearance guards after all basin work. Final validation proves the basin profile, total relief, and route clearance on the exact shared render/collision height array.

### Specification conflicts to supersede

- PRD Flow 2, FR-4, and AC-7, plus D-010, D-036, D-041, and D-043, currently require a confirmed ball to remain visible.
- PRD goal-plate language, `DESIGN_RULES.md` goal geometry, D-035, and D-043 currently require a shallow plate with a low physical wall and reject a basin.
- D-039 and D-040 define the current 60–160 metre relief and coupled horizontal extents.
- D-039/D-040/D-043 and the completed halo plans describe ring/scale instruments or forbid the partial direction arc that this contract supersedes.
- `OPEN_QUESTIONS.md` still carries retained-ball and older terrain assumptions as unresolved/current context.
- The implementation must append one superseding decision, minimally align PRD/design rules, and close the affected question entries before code changes. Historic entries remain truthful records and are not silently rewritten.

Readiness statement:

- Every material product, gameplay, geometry, camera, rendering, data-ownership, artifact, and validation choice is closed.
- The user has now authorized implementation. The revised partial-arc direction replaces the earlier instrument proposal; unrelated theme, menu, UI-contract, and UID files remain excluded.
- The current task-pre-existing dirty files have been identified and are outside this contract.

## Tasks

### Phase 1: Superseding product contract and data ownership

Goal: make the canonical product rules and runtime state model compatible with disposable resolved balls and terrain-owned goals before changing visible behaviour.

Preconditions:

- The user authorizes implementation of this active contract in a later turn.
- Task-pre-existing dirty files are still excluded unless their exact diff becomes required and ownership is resolved.

Source owners: `project-specs/cannon-golf/PRD.md`, `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/DECISIONS.md`, `project-specs/cannon-golf/OPEN_QUESTIONS.md`, `src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/course_builder.gd`, session and multi-goal tests

- [x] **1.1** Record the superseding product and design decision
  - Change: append one accepted decision for disposable resolved balls, terrain-owned goal basins, the partial launch arc with connected direction arrow, literal tenfold macro relief, separated route/terrain envelopes, stable completed-goal geometry, and continued device deferral; minimally align PRD/design rules and mark the retained-ball/old-terrain entries in `OPEN_QUESTIONS.md` resolved by the new decision while preserving their historical text.
  - Accept: no current canonical requirement or unresolved question still prescribes retained confirmed balls, a physical goal fence, a closed-ring halo, or the 60–160 metre relief schedule as current behaviour; D-042 remains explicitly unchanged.
  - Guard: preserve historic decision text as history and use current product terms such as `impact mark`, not inherited coverage language.
- [x] **1.2** Replace node-backed completion state
  - Change: make completed goal indices/identities and count the source of truth; remove `confirmed_ball`/`confirmed_balls` node retention and feed launcher-source selection from the completed goal's stored floor position rather than a deleted ball.
  - Accept: tally, next goal, launcher relocation/source choice, intermediate completion, final clear, save/session reset, and UI state operate after the winning ball node is gone; the selected source sits on the goal floor and passes terrain/barrel/muzzle-clearance checks.
  - Guard: do not serialize live node references or infer completion from scene children.

Phase gate:

- Run the directly owned session and multi-goal state tests after the data model changes, before altering geometry.
- Record a user checkpoint because this execution contract has more than four top-level phases.

### Phase 2: Disposable balls and legible aim

Goal: every resolved ball disappears cleanly and both aim axes read at ordinary play scale before the terrain/artifact migration begins.

Preconditions:

- Phase 1 state and canonical-record gates pass.

Source owners: `src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/golf_ball.gd`, `src/cannon_golf/impact_history.gd`, `src/cannon_golf/course_builder.gd`, `src/cannon_golf/cannon_golf_aim_halo.gd`, `src/cannon_golf/cannon_golf_launcher.gd`, `src/cannon_golf/cannon_aim_reticle.gd`, `tests/cannon_golf_session_test.gd`, `tests/cannon_golf_multi_goal_test.gd`, `tests/cannon_golf_live_ball_lifecycle_test.gd`, `tests/cannon_golf_ballistics_test.gd`, `tests/capture_cannon_golf_frame.gd`

- [x] **2.1** Remove every resolved ball while retaining only its first-contact mark
  - Change: route failed-rest, out-of-bounds, retry/reset, intermediate confirmation, and final confirmation through explicit task-owned resolution that releases the ball node after dependent bookkeeping is complete.
  - Accept: a failed stationary ball disappears after the existing two-real-second dwell; a confirmed ball disappears immediately after confirmation state commits; its first-contact mark remains subject to the existing five-mark FIFO limit; unrelated live balls persist and remain independently controllable after an intermediate confirmation; final stage clear may remove every remaining live ball as accepted by D-041.
  - Guard: do not add a global live-ball limit, absolute contacted-ball timeout, or extra settlement mark.
- [x] **2.2** Encode the resolved-ball regression contract
  - Change: replace tests that require retained frozen balls with completed-index, node-removal, five-mark-limit, intermediate-live-ball, and final-clear cleanup assertions.
  - Accept: focused tests fail on a retained confirmed node, a prematurely missing non-evicted mark, an intermediate-confirmation removal of another ball, or stale node-backed progress.
- [x] **2.3** Replace the halo with the selected partial launch arc and arrow
  - Change: keep `CannonGolfAimHalo` as the adapted data/geometry owner, but delete its ring, dotted scale, and bead. Sample only the first capped segment of the live damped launch path, draw it as one thin continuous dark curve, and connect a thick amber arrowhead to its final tangent. Hide the large guide in cannon view and keep the compact reticle.
  - Accept: yaw and pitch changes are immediately visible at default and extreme values, including exact vertical aim; the arc starts `12 m` above the launcher, ends without a landing/impact marker, never exceeds `0.55 s` or `95 m`, remains large enough for overview, and the arrow tangent clearly shows motion direction. No ring, dotted scale, bead, complete trajectory, predicted impact, or second barrel remains.
  - Guard: only the arrowhead may use no-depth; every mesh is unshaded and shadow-free.

Phase gate:

- Run focused lifecycle, multi-goal, session, goal, aim/input, camera, and capture-harness checks.
- Render planning aim at yaw `0, 90, 180, 270°` and pitch `-90, -45, 0, +45, +90°` at 1280 by 720; render overview and cannon modes at 1280 by 720 and 1920 by 1080; verify the world arc hides in cannon view and remains clear through ordinary overview zoom/orbit changes before beginning terrain work.
- Record a user checkpoint.

### Phase 3: Broad tenfold terrain and terrain-owned goal basins

Goal: create literal tenfold world-height relief through broad deterministic landforms, then integrate smooth goal basins without local cliff cuts or ballistic changes.

Preconditions:

- Phase 2 behaviour and aim captures pass.
- Current prepared artifacts remain in place; generation may use memory and a task-owned staging root but never canonical artifact paths before the phase gate passes.

Source owners: `src/cannon_golf/trajectory_course_generator.gd`, `src/cannon_golf/course_terrain_factory.gd` (retirement), new `src/cannon_golf/cannon_golf_terrain_admission.gd` (`CannonGolfTerrainAdmission`), new `src/cannon_golf/cannon_golf_macro_terrain_contract.gd` (`CannonGolfMacroTerrainContract`), `src/cannon_golf/course_data.gd`, `src/cannon_golf/course_leg_data.gd`, `src/cannon_golf/generated_course.gd`, `src/cannon_golf/generated_course_leg.gd`, `src/stage_generation/generated_stage_layout.gd`, `src/cannon_golf/prepared_course.gd`, `src/cannon_golf/prepared_course_leg.gd`, `src/cannon_golf/course_identity.gd`, `src/cannon_golf/course_artifact_codec.gd`, `src/cannon_golf/course_builder.gd`, `src/cannon_golf/settlement_goal.gd`, Cannon Golf course/profile resources, goal/course/course-build/terrain/variety/range/artifact/performance tests

- [ ] **3.1** Separate route and macro-terrain envelopes
  - Change: obtain the current pre-expansion rectangle through `CannonGolfMacroTerrainContract.route_bounds_for(course)` and freeze it as `route_bounds` before planning any launcher/goal; derive an aspect-preserving `terrain_bounds_for(route_bounds, target_relief)` whose diagonal satisfies the locked `38°` formula; derive each even terrain-cell axis as `2 × ceil(ceil(axis_size / 3.5 m) / 2)` with fail-closed cap checks. Keep generic `GeneratedStageLayout.local_bounds` as the actual heightfield's terrain domain and add Cannon-specific `route_bounds` through generated/prepared course data and the codec. Keep `play_bounds` derived from the route path/current lifecycle apron rather than the physical terrain.
  - Accept: every authored launcher/goal position and leg distance is unchanged within numeric tolerance; every terrain envelope meets the minimum run; out-of-bounds tests retain current route-relative results; stored `route_bounds` and terrain `local_bounds` are both valid and unequal on expanded courses. A change to authored bound/relief inputs changes the authored course identity; a change to generated bound values changes payload/construction hashes.
  - Guard: do not scale cannon power, ball radius, goal radius, route distances, goal count, or ball-lifecycle space to the expanded scenery.
- [ ] **3.2** Establish one versioned Cannon Golf terrain contract and one generation owner
  - Change: replace `CannonGolfLongitudinalGenerationContract` with `CannonGolfMacroTerrainContract` in the exact file/class named above. It extends `StageGenerationContract`, retains inherited `generation_version`, `profile_version`, and `layout_version` at the unchanged shared `StageGenerationContract.CONTRACT_VERSION = 10` so `GeneratedStageLayout` and profile validation remain compatible, and adds `MACRO_CONTRACT_VERSION = 1` plus `ALGORITHM_VERSION = 10`. In this subclass, inherited `local_bounds` remains the current pre-scale route template and inherited `cell_count` remains its legacy reference grid; terrain generation must call the three explicit resolver methods in task 3.1 rather than read `cell_count` as output resolution. The contract separately owns maximum `3.5 m` terrain-cell spacing, maximum `384 × 576` terrain cells, maximum `442,368` top triangles, `24 MiB` artifact size, `200 MiB` catalog size, `768 MiB` peak per-course working-set growth, and `60 s` per-course generation. Keep existing profile IDs, serialize the new macro version/caps in every Cannon Golf profile, and include them in authored identity. Extract live range/admission helpers from `CourseTerrainFactory` into `CannonGolfTerrainAdmission`, point generator/tests to it, and delete the alternate factory's geometry/raised-lip path.
  - Accept: there is one terrain-generation entry point; all Cannon Golf profiles validate both the unchanged shared version triplet and the new macro contract; no raised-lip generator remains reachable; calculated course-9 needs (`≈354 × 540` cells and `≈382,320` top triangles after even-axis rounding) fit the locked caps; shared `StageGenerationContract` behaviour and existing profile IDs remain unchanged for inherited paths.
  - Guard: do not silently reinterpret the previous longitudinal contract or leave a competing fallback generator.
- [ ] **3.3** Generate broad course-specific macro landforms and enforce distribution
  - Change: replace amplitude-only relief normalization with deterministic low-frequency masks/spines for each existing course motif, reserve at least `85%` of new amplitude for macro forms, keep local noise at current absolute scale, and condition the final array against the locked slope/distribution limits.
  - Accept: relief falls in `[target, target × 1.05]`; p10–p90 span is at least `65%` of total relief; qualifying high/low regions each cover at least `3%` of samples; slope metrics stay within `42°/60°/3%`; no terrace or isolated cut satisfies the metric.
  - Guard: no course may reuse another course's height array, silhouette signature, route/goal coordinate set, or trivial rotated/mirrored equivalent.
- [ ] **3.4** Stamp smooth terrain-owned goal basins after global conditioning
  - Change: retain `goal_recess_depth` and `bowl_recess_depth_range` as the explicit/recipe basin-depth inputs; retire authored `goal_lip_height` and `bowl_lip_height_range` from `CannonGolfCourseLegData`, `CannonGolfCourseData` legacy-leg construction, every course resource, validation, tests, and authored identity without mapping them to a new behaviour. Replace generated/prepared `goal_rim_y`/`goal_lip_y` with `basin_shoulder_y`/`basin_outer_radius`; keep `goal_position.y` as floor and `goal_radius` as scoring radius in leg validation, codec, payload/construction feeds, and builder configuration. Finish macro normalization, relief rebalance, and global slope conditioning first; align each reserved shoulder neighbourhood to `basin_shoulder_y`, stamp the locked quintic profile, then run only local slope projection with floor/shoulder anchors locked. Update the deterministic route candidate chooser to reject basin/start overlap and sample the intended flight against the final shoulder/heightfield at no more than half-cell intervals. No global height operation follows.
  - Accept: generated/prepared validation rejects false or incomplete basin metadata; `goal_position.y` is the floor; `basin_shoulder_y - goal_position.y` is `3.5..4.5 m`; `basin_outer_radius - goal_radius` is at least seven cells and `24 m`; every basin has a near-flat centre, monotonic radial rise, zero hard step, sampled slope at most `20°`, no overlap within two cells, and full incoming route clearance; post-conditioning validation matches the shared render/collision array.
  - Guard: the goal annulus contributes less than `1%` of total course relief and cannot satisfy any macro-relief gate.
- [ ] **3.5** Replace the physical goal plate/fence with stable terrain containment
  - Change: remove `SettlementGoal` floor/wall bodies and state-dependent rim visibility; keep one flush non-colliding disc and fixed flag over the terrain floor. Configure containment from `goal_position.y` and `basin_shoulder_y`: preserve the existing horizontal radius/ball inset, lower floor tolerance, and motion/dwell gates, but replace legacy `rim_height` vertical extent with `basin_shoulder_y - goal_position.y + 1.5 × ball_radius`. Keep settlement in `contains_ball()` polling; hide only the airborne arrow and update the HUD tally on confirmation. Place a selected source at the sampled goal-centre floor plus the established `0.05 m` offset and validate cannon body/barrel/muzzle clearance. Update goal, course-build, terrain, variety, and range tests that currently require a static plate, flat `0.18 m` support, `13 → 7 → 4` walls, or rim/lip metadata.
  - Accept: active/future/confirmed goals have identical flag, basin, disc, collision, material, and silhouette; no goal `StaticBody3D`, wall, lip, or floor collision exists; containment and settlement still reject high-energy pass-through and accept the certified low-energy dwell; before/after captures differ only in arrow visibility and HUD tally.
  - Guard: do not add an `Area3D`, fence, raised lip, goal-only damping, or state-dependent world material.
- [ ] **3.6** Enforce geometry, memory, and performance budgets
  - Change: derive grid dimensions from terrain bounds at no more than `3.5 m` per cell, keep the same final height array for render and collision, and record time, peak working-set delta, triangles, and serialized-size estimates in the generation result.
  - Accept: cell count stays within `384 × 576`, top triangles stay within `442,368`, one course stays below `60 s` and `768 MiB` peak working-set growth, all ten complete sequentially within the bounded catalog gate, no prepared artifact exceeds `24 MiB`, the batch does not exceed `200 MiB`, and runtime checks show no basin aliasing or terrain gap.
  - Guard: do not add a second terrain mesh, multiresolution terrain system, or new package under this contract.

Phase gate:

- Generate all ten courses to the task-owned staging area once and record relief, quantiles, extreme-region coverage, slope metrics, sample spacing, route admission, basin profile, generation time, peak working-set growth, triangle count, and projected artifact size.
- Do not write canonical prepared-artifact paths until every staged course passes.
- Record a user checkpoint.

### Phase 4: Camera integration, full artifact replacement, and rendered comparison

Goal: make the larger vertical world behave normally in overview, close inspection, cannon, and follow views, then replace the prepared catalog through a verified rollback-safe promotion.

Preconditions:

- Every staged course passes Phase 3.

Source owners: `src/cannon_golf/course_world_envelope.gd`, `src/cannon_golf/overview_camera_solver.gd`, `src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/course_builder.gd`, `src/cannon_golf/cannon_golf_game.gd`, `src/cannon_golf/app/cannon_golf_preview_world.gd`, `src/cannon_golf/prepared_course.gd`, `src/cannon_golf/course_identity.gd`, `src/cannon_golf/course_artifact_codec.gd`, `scripts/bake_cannon_golf_courses.gd`, camera/artifact/capture tests, `resources/cannon_golf/prepared/*.res`

- [ ] **4.1** Adapt safety calculations to the larger terrain envelope
  - Change: keep `content_bounds` as the physical terrain AABB for terrain clearance, safe pivot/boom resolution, ground extent, fog, far clip, and shadow coverage; keep `play_bounds` route-derived for ball resolution; add persisted `overview_frame_points` and a diagnostic `overview_frame_bounds` for ordinary focus/pan.
  - Accept: no planning, cannon, or follow pose penetrates terrain or clips the high/low macro forms; ball out-of-bounds behaviour does not expand with scenery; blocked booms shorten predictably and never escape by lifting into a sky-dominant angle; far-plane and directional-shadow captures contain every required physical and gameplay object without adding a light or shadow pass.
  - Guard: do not add camera modes or reintroduce goal fly-to behaviour.
- [ ] **4.2** Keep normal overview composition and stable cue size
  - Change: choose four deterministic landmarks—two high-region and two low-region representatives outside goal/start masks, within `route_bounds` grown by `35%` of its diagonal, and separated by non-maximum-suppression radius `20%` of the shorter terrain dimension. Generation fails if the macro masks do not supply those candidates. Store them with every goal, the launcher, and fixed logical marker-extreme points in `overview_frame_points`; use `TerrainCameraFramer.framed_pose_around_points()` rather than an AABB-corner fit for reset/full overview and pan. Reject a landmark set when its required frame distance exceeds `1.6×` the route-only frame distance.
  - Accept: the longest projected separation between any launcher/goal pair is at least `30%` of the safe viewport's shorter dimension; every incomplete-goal aerial marker is at least `12 px` tall; relief is obvious in silhouette and occlusion; the partial aim arc and connected arrow are readable at 1280 by 720 and 1920 by 1080; and no required cue is clipped.
  - Guard: the camera may not flatten relief through a near-top-down reset pose or hide it through an excessive sky view.
- [ ] **4.3** Replace all ten prepared artifacts as one verified batch
  - Change: make `CannonGolfMacroTerrainContract` the single owner of algorithm version `10`; bump `CannonGolfPreparedCourse.SCHEMA_VERSION` to `4` and `CONSTRUCTION_VERSION` to `5`. The authored `CannonGolfCourseIdentity.signature(course)` includes macro/algorithm versions, authored terrain/route inputs, `goal_recess_depth`/`bowl_recess_depth_range`, goal radii, and deterministic envelope-formula inputs only; it drops every retired lip input. Generated `route_bounds`, terrain `local_bounds`, `overview_frame_points`/diagnostic bounds, basin metadata, heights, and metrics enter payload and construction hashes only, avoiding a generated-output signature cycle. Runtime checks schema, algorithm, authored signature, and payload/construction hashes. Delete the codec's legacy dictionary fallback that synthesizes `goal_rim_y`/`goal_lip_y`.
  - Change: extend the bake script with a required sibling staging directory `resources/cannon_golf/prepared.next` and a promotion journal under `.godot/cannon-golf-bake-staging/`. Generate/save/load/validate all ten in `prepared.next`; ensure the canonical directory is closed; rename canonical `prepared` to `prepared.rollback`; rename the complete `prepared.next` directory to `prepared`; then load/validate all canonical paths. Because whole directories move, a process interruption can expose either a complete old batch, no canonical batch, or a complete new batch, never a mixed directory. On the next bake invocation, the journal deterministically completes or restores the directory swap before new work.
  - Accept: runtime rejects any old algorithm/schema/field set; staged and canonical catalogs both pass identity and payload checks; no mixed catalog state can be loaded; generated leg count, station count, route order, and authored motif identity remain correct; the promotion journal and rollback directory are removed only after canonical validation succeeds.
  - Guard: on generation or staged validation failure, never rename canonical artifacts. On promotion/canonical-load failure or recovered interruption, restore the complete canonical directory from `prepared.rollback` before further work; do not use a hard reset or per-file promotion.
- [ ] **4.4** Capture the representative visual matrix
  - Change: capture courses 0, 3, 6, and 9 in full overview and close planning views at 1280 by 720 and 1920 by 1080; capture an active and confirmed goal before/after pair; capture the aim angle matrix and ordinary/exact-vertical cannon views.
  - Accept: visual inspection shows broad multi-region relief, no localized crater/cliff used to fake the metric, smooth readable goal basins, invariant completed-goal geometry, no retained resolved balls, legible impact marks, and a non-goal-like aim instrument.
  - Guard: compare from matched camera states; do not use a hand-picked camera pose to conceal defects.

Phase gate:

- Run camera, terrain, artifact, goal, session, and visual contract gates against the prepared catalog.
- Record a user checkpoint.

### Phase 5: Final regression, quality audit, and scoped handoff

Goal: prove the complete contract, preserve unrelated worktree state, and leave one coherent implementation history.

Preconditions:

- Phase 4 artifacts and renders pass.

Source owners: all task-owned changed files, the active contract, full Cannon Golf focused suite, production-style project start path

- [ ] **5.1** Run the final automated gate once
  - Change: run the complete Cannon Golf test wrapper after all task-owned implementation and artifact inputs are stable.
  - Accept: every focused entry exits zero, no Godot error line is emitted, catalog resources load, and no stale retained-ball/fence/old-relief assertion remains.
- [ ] **5.2** Run rendered and production-style QA
  - Change: start the built/current project through its production-style path, exercise ordinary launch → impact → rest/confirmation → return flows, and inspect the Phase 4 capture matrix.
  - Accept: no clipping, occlusion error, missing input, stale ball, changing goal boundary, unreadable angle, camera collision, or out-of-bounds regression is visible.
- [ ] **5.3** Audit task-owned architecture and contracts
  - Change: use `codebase-quality-auditor` on the cross-module implementation and make only small safe task-scoped corrections.
  - Accept: completion state has one owner, aim data has one owner with view-specific presentations, route and terrain bounds are not conflated, no physical goal boundary survives, and no catch-all or reachable fail-open path was added.
- [ ] **5.4** Complete the plan and create coherent scoped commits
  - Change: mark this contract `done` only after every gate passes; commit product/state changes, geometry/terrain/artifacts, and final validation records as coherent task-owned units with explanatory bodies.
  - Accept: task-pre-existing modified theme/menu/UI-contract files and untracked `.gd.uid` sidecars remain unstaged and unchanged unless separately authorized.

## Validation and Rework Controls

| Cadence | Exact check or evidence | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Script inner loop | `scripts/invoke-cannon-golf-validation.ps1 -CheckOnly -Script res://src/cannon_golf/<changed-script>.gd`, then its directly owned focused test | A changed script or test first becomes internally complete | Its relevant input changes |
| State gate | Session, multi-goal, live-ball lifecycle, goal, input, and impact-history focused tests through the bounded wrapper | Phase 1 and Phase 2 state tasks pass | A state owner changes |
| Aim structure/render gate | Assert one continuous sampled curve and one connected tangent arrow, depth testing on for the curve, no-depth limited to the arrow, and shadows off; capture yaw `0/90/180/270°`, pitch `-90/-45/0/+45/+90°`, default/full overview, hidden-guide cannon view, and zoom/orbit changes at 1280 by 720 and 1920 by 1080; measure duration, path length, endpoint tangent, and logical presentation envelope | Aim implementation is stable | Aim geometry, material, ballistics sampling, viewport, or capture guard changes |
| Staged terrain gate | All ten staged generators; record relief, p10/p90, region coverage, slopes, sample spacing, route guards, basin samples, time, peak memory, triangles, and artifact size | Phase 3 is complete | Generator/profile/identity input changes |
| Artifact gate | Course-artifact, catalog-smoke, terrain, terrain-slope, range, variety, multi-goal, and camera focused tests | One complete prepared batch exists | Artifact or consuming code changes |
| Final render gate | Matched course `0/3/6/9` overview and close frames at 1280 by 720 and 1920 by 1080; active/confirmed goal pair; resolved-ball/mark frame | Prepared catalog and camera are stable | A visible input changes |
| Final automated gate | `scripts/test-cannon-golf.ps1` | All narrow and render gates pass | A final-gate input changes |
| Quality gate | `codebase-quality-auditor` plus production-style gameplay smoke | Final automated gate passes | A correction changes reviewed code |

Validation rules:

- Separate implementation checks from the broad final gate. Run the cheapest owner-specific check while building.
- Run the expensive all-ten generation/bake and full suite only at the named phase gates.
- Rerun a failed gate only after a relevant change or a new evidence-producing hypothesis.
- Save large numeric and rendered evidence under the existing task-owned capture/evidence area and summarize only the acceptance-relevant results in this plan.
- Treat rendered evidence as required for aim, goal, terrain, and camera acceptance; headless assertions alone cannot prove visual semantics.
- Stop a batch at the first structural failure, but do not replace any artifact until the complete staged batch passes.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| Tenfold relief cannot pass the slope gates in the derived terrain envelope | Expand only the macro-terrain envelope with the same aspect ratio and recompute sampling; preserve route bounds and relief target | Do not relax slopes, create isolated cliffs, or scale ballistics |
| Expanded sampling exceeds the 60-second/course, `24 MiB` per-course, or `200 MiB` catalog budget | Optimize bounded generator passes and data packing first; increase cell size only while it stays at or below `3.5 m` and bowls keep at least seven transition cells | Stop and replan before introducing a second/multiresolution terrain representation or weakening geometry acceptance |
| Macro extremes are numerically valid but visually irrelevant to play | Move the broad ridge/valley masks, not route coordinates, so representative silhouettes and occlusions border or cross the route envelope | Do not make one spike/pit near a goal or use camera tilt alone to fake relief |
| A goal basin does not settle a low-energy ball reliably | Widen its C2 transition and adjust floor radius within the existing goal footprint; keep depth in `3.5..4.5 m` and slope at or below `20°` | Do not add a fence, raised lip, damping pad, or goal-only gravity |
| A confirmed goal is not distinguishable after its geometry becomes invariant | Strengthen the existing HUD tally/confirmation feedback and the timing of airborne-arrow removal | Do not alter the flag, basin, disc, world material boundary, or collision |
| The aim arc passes visibly through a mountain | Stop sampling before the first terrain hit and keep the curve depth-tested; retain no-depth only on the compact arrowhead | Do not make the whole path no-depth or move it to a screen corner |
| The aim arc reads at overview but obscures cannon view | Hide the world arc in cannon mode and keep the existing compact reticle | Do not reintroduce the torus, dotted scale, or a second barrel |
| Full overview makes the route too small | Frame goals plus selected macro landmarks and preserve close zoom; use camera-projected aim/goal cue scaling | Do not shrink the terrain, lower relief, or crop required goals |
| A material fact contradicts the locked product, geometry, or architecture contract | Stop the affected branch, update this contract, and obtain required owner direction | Implementation may tune numeric values only within the explicit acceptance bands above |

Implementation-local discoveries may be handled without replanning only when they cannot change visible behaviour, gameplay semantics, architecture, dependency surface, artifact format contract, or acceptance criteria.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Phase 2 passed; Phase 3 is next. The raised partial ballistic curve, terrain-clipped connected arrow, cannon-view hiding, full-direction finite geometry, and 1280/1920 rendered checks pass alongside focused ballistics/input/camera tests.
- Next task: **3.1** Separate route and macro-terrain envelopes before increasing relief.
- Evidence completed during planning:
  - read the current PRD, design rules, decisions, relevant active/done plans, code owners, tests, recent history, and representative captures;
  - traced failed and confirmed ball resolution, impact marks, goal construction/state changes, aim geometry/materials, terrain generation/conditioning, and camera-bound coupling;
  - compared Godot geometry/material and terrain-generation references;
  - identified task-pre-existing modified/untracked files and corrected the unsupported earlier ownership description.
- Tasks 1.1 through 2.3 are complete. Focused Godot checks passed on 2026-08-16 with no log growth or owned-process leak; rendered evidence is under `.godot/capture-temp/partial-aim/`.
- Update rule: after each phase gate, record concise evidence, check completed tasks, and advance this pointer before continuing.

## Completion and Stop Conditions

Complete when:

- Every task, acceptance check, guard, phase gate, and final gate in this contract passes.
- Every resolved ball is absent from the scene after resolution and its first-contact mark remains according to impact-history limits.
- Completed-goal data remains valid without retained ball nodes.
- Goal basin geometry/collision/material is invariant across active, future, and confirmed states and no physical fence/floor body exists.
- The selected partial aim arc and connected arrow communicate every legal yaw/pitch extreme without revealing a complete trajectory or predicted impact.
- All ten prepared courses meet literal tenfold relief, macro-distribution, slope, basin, route, camera, identity, and performance contracts.
- Canonical product records describe the implemented current behaviour, this plan is marked `done`, and only task-owned files are committed.

Replan when:

- A required change would alter ballistics, the three slope limits, literal tenfold relief, terrain representation count, goal-device policy, camera mode ownership, or dependency surface.
- The complete terrain/artifact target cannot be met within the locked single-heightfield and performance constraints after the predetermined optimization/expansion responses are exhausted.

Do not stop or replan for:

- Local tuning of aim marker spacing, bowl width, camera composition, or macro mask placement inside the locked bands.
- One failing test or render before an evidence-producing correction has been attempted.
- Task-pre-existing dirty files that remain outside the planned staging set.
