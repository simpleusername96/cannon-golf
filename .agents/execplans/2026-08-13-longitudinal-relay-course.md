---
type: plan
status: active
created: 2026-08-13
scope: Add one depth-dominant ordered multi-goal relay course while preserving the two existing courses
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-13-large-free-aim-course.md
  - .agents/execplans/2026-08-13-fire-camera-independence.md
  - project-specs/cannon-golf/assets/deep-relay-terrain-direction.png
---

# Longitudinal Multi-Goal Relay Course - Execution Contract

Add one third course whose generated mountain keeps the current width but extends
substantially farther through world depth. The course contains two ordered,
terrain-owned settlement goals. Confirming the first goal preserves its ball,
moves the single reusable cannon to a safe launch anchor beside that goal, and
opens the second leg; only confirming the final goal clears the course. The two
existing one-goal courses remain unchanged in terrain, launch, camera, and
solution behavior.

## Purpose

- Objective: prove the first direct multi-goal course and make the terrain read
  as a long route through depth instead of another broad frontal mountain.
- Deliverable: current product records, one new deterministic course and
  generation profile, normalized leg data, multi-goal terrain and runtime
  owners, stronger terrain walls around the new goals, leg-aware cameras,
  catalog-driven course selection, focused tests, rendered evidence, and a
  refreshed Windows build.
- Completion state: courses 1 and 2 still behave exactly as before; course 3
  starts at its original cannon, confirms goal 1 without clearing, preserves
  that ball, relocates the same cannon beside goal 1, permits unlimited attempts
  at goal 2, and clears only after goal 2 safely settles.

## Scope and Boundaries

In scope:

- Preserve `first_ridge` and `rising_bend` as the first two catalog entries and
  keep their existing resources, `210 x 120` metre generated extents, generated
  terrain signatures, goal geometry, launch anchors, default misses, certified
  witnesses, and one-goal clear flow unchanged.
- Add exactly one third course with the internal ID `deep_relay`, the Korean
  display name `깊은 릴레이`, and two ordered goals. The data and runtime model
  must support more than two legs without another ownership rewrite.
- Add a Cannon Golf-only longitudinal generation contract with an exact
  `210 x 320` metre X/Z extent, `84 x 128` cells, `21,504` maximum top
  triangles, and route stations spanning the depth at the retained
  approximately `2.5` metre sample spacing. The selected visual contract is
  `project-specs/cannon-golf/assets/deep-relay-terrain-direction.png`: a low
  start shelf, a much higher middle goal shelf, and a still higher summit goal
  joined by one continuous terraced mountain.
- Give the new course a `1.35` terrain vertical scale. Its playable top surface
  must have at least `80` metres of highest-to-lowest relief. Goal 1's rim must
  be at least `25` metres above the starting launch anchor, and goal 2's rim
  must be at least `25` metres above the goal-1 relay launch anchor. These are
  physical elevation separations, not camera or illustration-only effects.
- Use Paint Mountain's retained route resolver, route-graph mountain
  synthesizer, topology, and geometry builders. The new course remains one
  connected heightfield-like terrain body with winding lateral movement and
  meaningful elevation sequence.
- Give each new goal a `10` metre radius, a terrain center recessed `4.5`
  metres from its local source rim, and a `1.5` metre raised terrain lip. Blend
  the outside of the lip back into source terrain over the existing `5` metre
  influence band. The center-to-lip height difference is therefore `6.0`
  metres. The interior must rise monotonically from center to lip and may not
  contain a central ejecting bulge.
- Use one reusable launcher node. Each authored course leg owns an incoming
  goal, one visible `50 / 50 / 50` default miss, and one real-physics solution
  witness. Leg 1 uses the course-start launcher. Every later leg uses an
  authored route-adjacent relay launch anchor beside the previous goal.
- Put each relay anchor on the terrain just outside the completed basin, toward
  the next goal. Its center must clear the completed ball and goal lip by at
  least one launcher-base radius plus `1` metre, while remaining close enough
  to read as the same goal site. It may not occupy the goal center because the
  confirmed ball remains there.
- Preserve impact history, confirmed balls, placed-device state reserved for
  future work, and the current checkpoint across retries and camera changes.
  Reset only the three visible launch controls to `50 / 50 / 50` when a new leg
  begins. Quick retry on that leg preserves its edited setup and does not return
  to an earlier launcher.
- Default gameplay planning frames the current launcher-to-goal leg. Normal
  pan, orbit, and bounded zoom can inspect the complete long course. The course
  selection preview frames the whole course so its depth is apparent.
- Add the third course to the existing start screen and result sequence without
  adding a normal-play progress card, goal counter, tutorial paragraph, or a
  new shortcut.

Out of scope:

- Modifying or replacing either existing course, adding a fourth course, adding
  more than two goals to the first relay course, or rebalancing the accepted
  eleven-course content target.
- Bounce, damping, airflow, gravity, placement UI, inventory, save migration,
  a custom level editor, disconnected islands, caves, bridges, or overhangs.
- A second cannon per goal, a launcher in the occupied goal center, a physical
  cup collider, a separate wall mesh, a visible launch envelope, a trajectory
  predictor, or a persistent goal-progress HUD.
- Changing the two-live-ball concurrency limit, baseline rebound, ball size or
  pace, impact-history capacity, current input bindings, or Fire's camera-neutral
  behavior.
- Editing `src/stage_generation/stage_generation_contract.gd` or the retained
  Paint Mountain catalog contracts. The deeper geometry is isolated behind a
  Cannon Golf subclass/resource so inherited stage validation stays unchanged.
- Adding or upgrading an external dependency.

Constraints and invariants:

- `course leg` is the canonical unit from one launcher state to one ordered
  settlement goal. `active goal` is the goal for the current leg. `confirmed
  goal` contains a protected ball. `final goal` is the only goal whose
  confirmation clears a multi-goal course. `relay launch anchor` is the
  launcher placement paired with the next leg, not another goal or device.
- Course data owns leg order, per-leg defaults, per-leg solution witnesses, and
  route-relative goal/launcher authoring. It does not own runtime nodes or
  settlement state.
- The terrain factory owns all basin/lip height deformation, generated goal and
  launch positions, per-leg camera bounds, and ballistic admission. The goal
  node owns only settlement policy and non-colliding visual state.
- The builder owns one terrain body, one launcher node, all goal nodes, and an
  immutable generated-course product. The game/session owner alone owns the
  active leg index, confirmed-ball collection, live-shot cleanup, retry, and
  final-clear transition.
- The camera rig owns current-leg framing and full-course exploration. The HUD
  may render availability but may not decide progression.
- A future goal does not accept settlement before it becomes active. A ball
  resting in a future basin is an unsuccessful attempt at the current leg.
- When any live ball confirms the active goal, lock it as confirmed and remove
  every other unconfirmed live ball before changing the launcher. This prevents
  an old projectile from crossing into the next leg after the checkpoint moves.
- Intermediate confirmation does not show the stage-result overlay. It changes
  goal visual states, relocates the launcher, resets its visible setup to
  `50 / 50 / 50`, and establishes the next leg's authored planning frame. This
  camera transition belongs to goal progression; ordinary Fire still never
  changes camera mode or pose.
- Course reset clears all live and confirmed balls, impact marks, and relay
  progress, then restores leg 1. Quick retry removes and replaces only the newest
  active unconfirmed ball from the current relay anchor.
- Single-goal courses normalize to one leg and clear on that leg's confirmation,
  preserving the current observable behavior.
- Existing single-goal resources use their current fields through a contained
  compatibility adapter. New multi-goal code consumes only the normalized leg
  interface; it must not branch on course IDs.
- For the existing courses, every terrain admission point remains reachable
  from the one start launcher under D-024. For the relay course, every visible
  terrain point outside a later-leg launch-safety footprint must pass the
  envelope of at least one authored leg. A launch-safety footprint is the
  horizontal `30` metre radius around a terrain-sited relay anchor; it is local
  supporting ground, not a flight target. The exemption applies only to the
  union whole-terrain check. Every leg's goal and intervening terrain corridor
  must still pass that leg's envelope with the existing `8` metre range, `8`
  degree yaw, and `8` metre height-margin guards.
- The new goal state is legible without color alone: the active goal uses the
  full raised flag and continuous rim markers; a future goal uses a visibly
  lowered flag and reduced marker rhythm; a confirmed goal retains its basin and
  is identified primarily by its protected ball. No state may hide the basin.
- The new course must keep the center of the screen clear under the existing
  compact HUD at `1280 x 720`, `1600 x 900`, and `1920 x 1080`.
- The selected direction image is an implementation target for silhouette,
  depth layering, and relative placement, not a license to add its decorative
  trees, switchback road, or any unplanned mechanic. Runtime acceptance comes
  from generated geometry, camera captures, and physics rather than pixel-level
  reproduction of the concept image.

Destructive or irreversible actions:

- None. This work adds Cannon Golf-owned data/code and updates current product
  records, tests, UI composition, and ignored build output. It does not delete
  inherited source history or saved user data.

Exact actions requiring owner or user approval:

- Changing either existing course's geometry or solution, adding another
  course/goal, changing sequential order, changing the locked new-course extent
  or goal profile, adding a visible progress HUD, adding a dependency, or
  modifying the retained generation contract. None is required by this plan.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Locked decision | Task IDs |
| --- | --- | --- | --- |
| Course schema | `course_data.gd` owns one `goal_route_t`, one generated cannon/goal pair, and one direct witness | Add an authored `CannonGolfCourseLegData` and a normalized leg accessor. Empty explicit-leg data adapts the existing singular fields into exactly one legacy leg; the new course authors two explicit legs | 2.1 |
| Catalog and selection | `course_catalog.gd` preloads two resources; `cannon_golf_course_select.gd/.tscn` hardcode two buttons | Add `deep_relay` as index 2 and generate a keyboard/focus-safe button per catalog item. Keep the existing two names/order and derive restrained English labels from stable course IDs | 2.2, 4.3 |
| Terrain depth | The shared contract permits only `120..160` metres of Z depth and the two course resources use `210 x 120`; changing it would affect inherited generation | Add an exact Cannon Golf longitudinal contract subclass/resource at `210 x 320`, `84 x 128`, leaving the shared contract and existing profile untouched | 2.2 |
| Terrain relief | The earlier contract fixed the new course to the old `0.45` vertical scale, which could lengthen the route without producing the very large height differences shown by the selected image | Use `1.35` only for `deep_relay`; require at least `80` metres of playable-top relief plus at least `25` metres of upward separation on each relay leg | 2.2, 2.3, 4.1 |
| Goal geometry | The factory carves one lower-only `3.5` metre parabolic basin; the goal node owns no collision | Preserve the current lower-only branch for legacy goals. Explicit relay goals use the locked `4.5` metre recess plus `1.5` metre terrain lip and external blend; instantiate no collision under the goal node | 2.3, 3.1 |
| Generated runtime data | The factory returns a single-goal dictionary and the builder mutates a duplicated course resource with runtime positions | Introduce typed immutable generated-course/generated-leg results. They hold all generated positions, rims, bounds, and admission metrics; authored resources remain data, not runtime state | 2.1, 2.3 |
| Launcher ownership | The builder creates one launcher and `configure(course)` reads the singular course position/yaw/defaults | Keep one node and add `configure_leg(generated_leg, authored_leg)`. Relocation changes position, hidden shot axis, and `50 / 50 / 50` defaults without rebuilding terrain or spawning another cannon | 3.1 |
| Goal settlement | The builder exposes one `goal`; the game checks only it, and any confirmation assigns one `confirmed_ball` and enters `CLEARED` | Builder exposes an ordered goal collection. Game owns `active_leg_index` and `confirmed_balls`; intermediate confirmation advances one leg, while only the last confirmation enters `CLEARED` | 3.1, 3.2 |
| Live balls and retry | Up to two unconfirmed balls coexist; current clear removes others; retry preserves setup/marks and replaces only the newest ball | Retain the limit. Intermediate confirmation removes other unconfirmed balls before relocation. Current-leg retry preserves all confirmed checkpoints, marks, camera context, and edited setup | 3.2, 3.3 |
| Planning camera | The rig frames the whole `content_bounds`; a 320 metre course would make each leg too small, and current pan limits cannot traverse that distance | Generated legs own local frame bounds/focus. Gameplay reset frames the active leg; pan clamps against full-course bounds and maximum zoom-out can show the whole route. Preview explicitly uses full-course framing | 4.1 |
| World envelope | Gameplay and preview use a fixed `160/166` metre apron and `520` metre camera/shadow distances | Retain those minima for old courses and derive larger apron, far clip, and shadow distance from the new generated content bounds so the long course is not clipped | 4.1 |
| Goal readability | `settlement_goal.gd` always builds one full flag/rim style | Add explicit `FUTURE`, `ACTIVE`, and `CONFIRMED` visual states using flag height, marker rhythm, and the confirmed ball, with color as a secondary cue | 4.2 |
| Product records | PRD Flow 2 says the player chooses any goal; Q-10 leaves order open; AC-8 says the first confirmed ball clears the prototype | Resolve Q-10 as authored sequential order for relay courses; record that intermediate confirmation moves the launch site and that only the final required goal clears | 1.1 |
| Performance | Deterministic terrain products are cached across preview/gameplay and camera framing is already dirty-state driven; no current test times a long course | Keep immutable geometry caching and dirty-only camera recomputation. Compare the new course against the existing build/cache baseline and forbid per-frame generation, goal rebuilding, or camera reframing | 2.3, 5.1 |
| Validation and release | Godot 4.7.1, focused runner, capture script, verification script, Windows export preset, and built-app smoke path are present | Run targeted tests during implementation, then one focused suite, one rendered-evidence pass, one source verification, one audit, and one release export/smoke after inputs stabilize | 5.1, 5.2 |

Readiness statement:

- Product order, content count, terrain topology, dimensions, goal shape,
  checkpoint behavior, retry behavior, camera behavior, data ownership,
  compatibility, UI restraint, dependency scope, and final evidence are closed.
- Exact route station X offsets, deterministic seed, and solution witness values
  are content-tuning outputs, not open product decisions. They may change only
  inside the locked profile/extent/goal/leg contract until the real-physics and
  tolerance gates pass.
- Implementation can start at Task 1.1 without another product or architecture
  decision.

## Tasks

### Phase 1: Align the product contract

Goal: make the active specification describe ordered relay goals before code
changes make the current free-order wording false.

Preconditions:

- This execution contract is the only active task-progress ledger.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`,
`project-specs/cannon-golf/OPEN_QUESTIONS.md`

- [x] **1.1** Record the ordered relay course and depth-first terrain behavior.
  - Change: update PRD Flow 2, FR-5, FR-8, AC-4, AC-7, and AC-8 for authored
    goal order, intermediate checkpoints, launcher relocation, and final-only
    clear. Add an accepted decision after D-029 for the third longitudinal relay
    course and per-leg admission. Resolve Q-10. Extend design rules for active,
    future, and confirmed goal cues plus current-leg framing.
  - Preserve: older accepted two-course decisions as history and keep D-024's
    single-launcher whole-terrain rule scoped to the first two courses.
  - Accept: targeted searches find no active claim that a multi-goal player may
    choose any goal, that any first confirmation clears every course, or that
    the first slice still contains only two implemented courses.
  - Evidence: PRD Flow 2/FR-5/FR-8/AC-4/AC-7/AC-8, design terrain/camera/goal
    rules, accepted D-030, and resolved Q-10 now define the ordered relay,
    extreme relief, current-leg frame, and final-only clear. Targeted
    contradiction search and `git diff --check` passed.

### Phase 2: Add longitudinal course data and generation

Goal: produce one deterministic connected `210 x 320` mountain with two typed
legs and terrain-owned raised-lip goals without changing the existing outputs.

Preconditions:

- Task 1.1 passes.

Source owners: `src/cannon_golf/course_data.gd`, new
`src/cannon_golf/course_leg_data.gd`, new
`src/cannon_golf/generated_course.gd`, new
`src/cannon_golf/generated_course_leg.gd`, new
`src/cannon_golf/longitudinal_generation_contract.gd`,
`src/cannon_golf/course_catalog.gd`,
`src/cannon_golf/course_terrain_factory.gd`,
`resources/cannon_golf/courses/`

- [ ] **2.1** Establish one normalized leg contract and typed generated output.
  - Change: add the authored leg Resource and immutable generated course/leg
    types. Add `leg_count`, `leg_at`, and `solution_for_leg` access through
    `CannonGolfCourseData`. Normalize the existing singular fields to one leg
    only when no explicit legs are authored; keep `direct_solution()` scoped to
    those one-goal resources.
  - Validate: explicit legs are ordered from the initial launcher toward the
    final goal; each default is integer `50 / 50 / 50`; each witness is legal;
    goal influence regions do not overlap; a later launcher lies between the
    previous and current goal and satisfies the locked clearance band.
  - Accept: both existing `.tres` files remain byte-unchanged and normalize to
    one leg; an invalid, unordered, overlapping, or missing-final-goal course
    fails closed with a focused data test.

- [ ] **2.2** Author the isolated longitudinal profile and third course.
  - Change: implement the Cannon Golf-only exact contract subclass and add a
    deterministic profile with 18 monotonically increasing route stations
    spanning exactly `-140` to `+140` metres. Add `deep_relay.tres` with two
    explicit legs, then append it to the catalog after the existing entries.
  - Tune only: route X offsets, grade sequence, seed, goal route parameters,
    relay anchor parameter, and per-leg solution witnesses may be tuned within
    the locked world contract. The route must visibly wind, change elevation in
    both legs, and keep the relay anchor next to goal 1.
  - Accept: the new profile validates without editing the shared contract; the
    catalog order is exactly `first_ridge`, `rising_bend`, `deep_relay`; course
    3 reports two legs, a `210 x 320` source extent, and vertical scale `1.35`.

- [ ] **2.3** Generate both goals, per-leg envelopes, bounds, and cached output.
  - Change: preserve the exact existing one-goal generation path. For explicit
    legs, resolve all goal centers, apply non-overlapping terrain deformation,
    rebuild topology once, resolve each launcher and hidden shot axis, compute
    current-leg frame bounds, validate each leg corridor, validate union
    admission for the complete visible terrain outside the exact `30` metre
    later-leg launch-safety footprints, and return typed immutable output. The
    footprints do not exempt goals or leg corridors. Include the explicit
    leg/profile contract in the cache key.
  - Goal profile: set the new center `4.5` metres below the source rim, the lip
    `1.5` metres above it, and blend back over `5` metres. Do not add goal-owned
    collision or a separate wall mesh.
  - Performance guard: preview and gameplay builders must reuse the same cached
    immutable geometry. An unchanged frame may not rerun generation, rebuild
    goal visuals, or resolve camera framing. The new uncached build may scale
    with its `2.67x` cell count but must not exceed `3x` the measured existing
    uncached build on the same run; cached rebuild overhead must remain within
    `25%` of the existing cached path.
  - Accept: old course geometry signatures, positions, range metrics, and
    witnesses match the pre-change baseline; the new topology has one connected
    terrain body, both basin centers are below their lips, both raised lips are
    present in collision, canonical playable-top vertices (not the support
    shell or base) have at least `80` metres of relief, each goal rim clears its
    incoming launch anchor by at least `25` metres, each relay anchor clears the
    previous goal lip and confirmed-ball footprint, and every applicable
    admission guard passes.

### Phase 3: Implement the relay session state

Goal: turn generated legs into one persistent checkpoint flow without spawning
duplicate launchers or losing confirmed balls.

Preconditions:

- Phase 2 passes its data, geometry, range, and cache checks.

Source owners: `src/cannon_golf/course_builder.gd`,
`src/cannon_golf/cannon_golf_launcher.gd`,
`src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/cannon_golf_hud.gd`

- [ ] **3.1** Build one launcher and an ordered goal collection.
  - Change: make the builder consume typed generated output, instantiate one
    non-colliding `CannonGolfSettlementGoal` per generated leg, and expose
    ordered `goals`/`goal_at` access. Add launcher leg configuration that moves
    the existing node and applies the leg's hidden axis/default setup.
  - Accept: each course owns exactly one terrain body and one launcher; old
    courses build one goal; `deep_relay` builds two; no goal contains a
    `StaticBody3D`; the relay launcher does not overlap the completed goal or
    ball.

- [ ] **3.2** Separate checkpoint confirmation from final course clear.
  - Change: replace the singular progression assumption with
    `active_leg_index` plus one canonical confirmed-ball collection. Check only
    the active goal. On intermediate confirmation, lock and retain the winning
    ball, remove every other unconfirmed ball, mark the goal confirmed, advance
    the index, activate the next goal, relocate the launcher, reset setup to
    `50 / 50 / 50`, and return to planning without showing the result overlay.
    On final confirmation, retain all confirmed balls and enter the existing
    clear/result flow.
  - Accept: goal 1 confirmation leaves exactly one visible protected ball,
    enables Fire from a distinct next origin, and does not enter `CLEARED`;
    landing in goal 2 before it is active does not advance; goal 2 confirmation
    enters `CLEARED` with both balls still visible.

- [ ] **3.3** Preserve retries, concurrency, and one-goal behavior across legs.
  - Change: make Fire availability depend on final-clear state rather than the
    existence of any confirmed ball. Keep the two-live-ball limit. Scope quick
    retry to the newest current-leg ball and course reset to the complete relay
    session.
  - Accept: a current-leg retry preserves its launcher origin, edited values,
    all prior impact marks, and every earlier confirmed ball; another attempt
    can start while one current-leg ball is live; confirming one removes the
    other before relocation; reset returns to leg 1 and clears all course-local
    state. Both old one-goal courses still clear on their first confirmed goal.

### Phase 4: Make the long course readable and selectable

Goal: show the active leg at a useful scale, keep complete-map exploration, and
add the third course without UI clutter.

Preconditions:

- Phase 3 state transitions pass focused headless tests.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/app/cannon_golf_preview_world.gd`,
`src/cannon_golf/app/cannon_golf_course_select.gd`,
`scenes/cannon_golf/cannon_golf.tscn`,
`scenes/cannon_golf/app/cannon_golf_course_select.tscn`

- [ ] **4.1** Add current-leg framing and full-course exploration.
  - Change: configure the gameplay rig from generated course/leg bounds. Reset
    and leg transition use the active leg's high-oblique frame; pan limits span
    the complete content bounds; maximum zoom-out can frame the entire route;
    side view remains leg-local. Preview uses full-course bounds. Derive apron,
    camera far clip, and sun shadow distance from generated bounds with the old
    `160/166` and `520` values as minima.
  - Preserve: Fire never changes camera mode, planning pose, or follow target.
    Direct drag/wheel/arrow input, `Tab`, view actions, and Home retain their
    current meanings.
  - Accept: course 3 starts with launcher 1 and goal 1 readable rather than the
    entire terrain miniaturized; zoom-out plus pan can inspect both goals and the
    full depth; default and side views make the three elevation bands and
    `80+` metre relief unmistakable; goal 1 confirmation establishes a valid
    leg-2 frame; no terrain,
    goal, launcher, or confirmed ball is clipped by the world envelope.

- [ ] **4.2** Express active, future, and confirmed states in the world.
  - Change: add the three visual states to `CannonGolfSettlementGoal`; have the
    session owner set them on load and transition. Use flag height and rim-marker
    rhythm as primary differences and restrained color/contrast as secondary
    differences. Keep the confirmed ball as the dominant completed cue.
  - Accept: grayscale inspection distinguishes active from future and confirmed
    goals; raised terrain walls remain visible; neither goal is obscured by its
    markers; no persistent goal count, status text, toast, or progress panel is
    added.

- [ ] **4.3** Make course selection catalog-driven.
  - Change: replace the two hardcoded course buttons with one reusable button
    component generated from catalog data. Preserve course order, selected
    state, keyboard/controller focus, back/start actions, Korean copy, concise
    English labels, and live preview updates.
  - Accept: three course buttons fit at all supported desktop resolutions
    without clipping or overflow; selection state is visible without color
    alone; selecting index 2 previews and starts `deep_relay`; no explanatory
    card or course-progress copy returns.

### Phase 5: Certify, inspect, audit, and package

Goal: prove the relay with real physics, inspect the Level 3 UI/gameplay states,
and ship one coherent implementation commit.

Preconditions:

- Phases 1 through 4 pass their targeted checks.

Source owners: `tests/cannon_golf_course_test.gd`,
`tests/cannon_golf_course_build_test.gd`,
`tests/cannon_golf_terrain_test.gd`,
`tests/cannon_golf_range_test.gd`,
`tests/cannon_golf_goal_test.gd`,
`tests/cannon_golf_session_test.gd`,
`tests/cannon_golf_camera_test.gd`,
`tests/cannon_golf_performance_test.gd`,
`tests/cannon_golf_solution_test.gd`,
`tests/cannon_golf_app_flow_test.gd`,
`tests/cannon_golf_ui_contract_test.gd`, new
`tests/cannon_golf_relay_test.gd`,
`tests/capture_cannon_golf_frame.gd`,
`scripts/test-cannon-golf.ps1`, this contract

- [ ] **5.1** Add deterministic data, physics, state, camera, UI, and performance
  regression coverage.
  - Change: extend the focused runner and existing owners; add one relay-specific
    test only for behavior that has no current owner. Replay each new leg's
    witness through the real rigid body, settlement thresholds, and transition.
    Prove each new leg's `50 / 50 / 50` default misses. Keep the broader numeric
    solution-tolerance threshold owned by unresolved Q-20; this task must not
    silently select that product-wide value.
  - Accept: old deterministic checks still pass unchanged; course 3's two
    witnesses settle in order; future-goal contact, bounced-out contact,
    concurrent-ball cleanup, retry-at-checkpoint, final clear, camera framing,
    catalog selection, cache reuse, and performance ratios all pass headlessly.

- [ ] **5.2** Complete rendered evidence, code-quality audit, source gate, and
  Windows delivery.
  - Change: extend the capture runner with deterministic `relay_initial`,
    `relay_confirmed`, and `relay_overview` states. Capture course selection and
    course 3 at `1280 x 720` plus one `1600 x 900` relay-confirmed state. Inspect
    terrain depth, taller walls, goal-state hierarchy, confirmed ball, relocated
    launcher, whole-course navigation, HUD clearance, focus, and clipping.
  - Audit: load and run `$codebase-quality-auditor` over the task-owned diff.
    Correct only small safe task-scoped findings; revise this contract before a
    material ownership or scope change.
  - Final gate: announce the several-minute focused suite/export gate, then run
    it once after visible and physics inputs stop changing. Run source
    verification, `git diff --check`, release export, and the built executable
    smoke. Update this plan's checkboxes/evidence and set `status: done` only
    after every gate passes.
  - Accept: captures are nonblank and visually pass; audit has no reachable
    task-owned failure or competing state owner; all commands exit zero; the
    Windows executable starts and exits cleanly.

## Validation and Rework Controls

Run targeted checks while implementing. Do not rerun a passing check unless one
of its listed inputs changed. The broad focused suite and export run once after
the feature stabilizes.

| Gate | Command or evidence | Prerequisite | Rerun trigger |
| --- | --- | --- | --- |
| Course/data | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_course_test.gd` | Tasks 2.1-2.2 | Course schema, resource, or catalog input changes |
| Terrain/build/range | Run `cannon_golf_terrain_test.gd`, `cannon_golf_course_build_test.gd`, and `cannon_golf_range_test.gd` with the same Godot invocation | Task 2.3 | Profile, factory, goal deformation, bounds, cache, or admission changes |
| Relay/session | Run `cannon_golf_relay_test.gd`, `cannon_golf_session_test.gd`, and `cannon_golf_goal_test.gd` with the same Godot invocation | Phase 3 | Progression, launcher, settlement, ball cleanup, retry, or reset changes |
| Camera/UI/app | Run `cannon_golf_camera_test.gd`, `cannon_golf_app_flow_test.gd`, and `cannon_golf_ui_contract_test.gd` with the same Godot invocation | Phase 4 | Camera, goal visuals, course select, preview, or HUD availability changes |
| Physics witnesses | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_solution_test.gd` | Authored witnesses stable | Ballistics, terrain, goal, launcher, or witness changes |
| Performance | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 7200 --script res://tests/cannon_golf_performance_test.gd` | Geometry/camera behavior stable | Grid, factory, cache, builder, camera invalidation, or preview changes |
| Course select capture | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --path . --script res://tests/capture_cannon_golf_frame.gd -- --state=course_select --course=2 --width=1280 --height=720 --background --output=res://.godot/capture-temp/deep-relay-select.png` | Task 4.3 | Catalog/select/preview/layout input changes |
| Relay captures | Use `tests/capture_cannon_golf_frame.gd` with `--course=2`, states `relay_initial`, `relay_confirmed`, and `relay_overview`, and the sizes named in Task 5.2 | Task 5.2 capture states exist | Visible terrain, goal, launcher, camera, HUD, or transition input changes |
| Focused final suite | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1` | All targeted gates pass | Any focused-suite input changes after the run |
| Source verification | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`; then `git diff --check` | Focused suite passes | Project/import/startup or source diff changes |
| Release gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/CannonGolfPrototype.exe'`; then run that executable hidden with `--headless --quit-after 3` and require exit code zero | Source verification and audit pass | Export/runtime input changes |

Rendered-evidence checklist:

- Course-selection capture shows three unclipped buttons, a distinct selected
  state, and the complete long preview without filler copy.
- Initial gameplay capture reads front-to-back: one cannon, active goal 1, a
  visibly deeper route, a minimum `25` metre rise to goal 1, and another minimum
  `25` metre rise to the restrained future goal 2.
- Side/high-oblique inspection shows the new raised terrain lip and recessed
  center as physical terrain, not a floating ring or separate cup.
- Confirmed capture shows ball 1 still inside goal 1, the one launcher moved to
  its adjacent relay anchor, goal 2 active, and no result/progress overlay.
- Overview capture proves zoom/pan can inspect both goals and the full course;
  current-leg reset still returns to a useful local frame.
- No capture clips Korean/English copy or places normal HUD controls in the
  center 70 percent of the viewport.

## Predetermined Contingencies and Change Control

- If the exact `84 x 128` generated profile fails retained slope/footprint
  acceptance at vertical scale `1.35`, tune only the new profile's route X
  offsets, grade signs, nominal peak, seed, and Cannon Golf-specific accepted
  slope ranges. Do not reduce the `80` metre relief or either `25` metre leg
  rise, loosen the shared generation contract, reduce the `320` metre depth,
  split the terrain, or distort old courses.
- If a new goal lip produces an invalid collision edge, increase local sample
  smoothness inside the locked `10 + 5` metre influence radius or adjust the new
  course's route parameter. Do not add a separate collider or lower the locked
  `6.0` metre center-to-lip difference without user approval.
- If a relay anchor overlaps the basin/ball or visually floats, adjust its
  route-relative parameter inside the locked clearance band and resample terrain
  height. Do not move it to the goal center or spawn another launcher.
- If a certified witness is numerically fragile, tune only the new route/goal
  parameters and witness until the tolerance test passes. Do not change global
  ball physics, settlement thresholds, or reveal the solution in the defaults.
- If union admission fails only on irrelevant far shell corners, first adjust
  route/anchor placement or the new profile footprint. Changing admission
  margins, clipping the terrain, or exempting visible points requires a plan
  revision and user approval.
- If the `3x` uncached performance ratio fails, profile the new generation,
  topology, collision, and goal-deformation steps. Optimize or cache the proven
  owner; do not reduce grid density below the retained approximately `2.5`
  metre spacing without revising this contract.
- If three catalog buttons overflow, change only the reusable button/container
  layout and spacing within the existing design system. Do not reintroduce
  course cards, prose, or a scrolling dashboard for three items.
- If a material fact invalidates ordered relay state, one connected terrain,
  the two-goal content count, or old-course preservation, stop the affected
  branch and revise this active contract before implementation continues.

## Progress and Next Steps

- [x] Current specifications, unresolved Q-10, completed execution contracts,
  course resources, generation contract/profile, single-goal factory/builder,
  launcher, settlement goal, session state, camera rig, preview, course select,
  focused tests, capture tooling, and release commands inspected.
- [x] UI/UX risk classified as Level 3 because the work changes gameplay
  progression, world-state hierarchy, camera context, and course selection.
- [x] Domain ownership closed around course legs, active/confirmed/final goals,
  relay launch anchors, and final clear.
- [x] Existing-course preservation, new extent, new goal profile, two-goal
  count, sequential order, setup reset, retry/reset semantics, camera framing,
  UI restraint, and validation strategy locked.
- [x] User-selected visual direction persisted at
  `project-specs/cannon-golf/assets/deep-relay-terrain-direction.png`; locked
  terrain relief to at least `80` metres and each relay-leg rise to at least
  `25` metres with new-course vertical scale `1.35`.
- [x] Phase 1 specification alignment completed and checked.
- [ ] Phase 2 data and generation implementation is in progress.

Next action: complete Task 2.1. Resume thereafter at the first unchecked task
whose preconditions are satisfied. Record acceptance evidence under the
corresponding checkbox; do not maintain a second progress list.

## Completion and Stop Conditions

Complete only when:

- The active product records describe the implemented longitudinal ordered
  relay behavior and Q-10 is resolved.
- The original two course resources and observable maps remain unchanged and
  pass their existing default-miss/direct-witness regressions.
- `deep_relay` is the third selectable course, uses one connected `210 x 320`
  generated terrain body with at least `80` metres of playable-top relief and
  at least `25` metres of rise per leg, has two locked raised-lip goals, and has
  one real solution witness per leg.
- Goal 1 confirmation preserves its ball, removes other unconfirmed balls,
  relocates the single launcher beside goal 1, resets only the new leg's setup,
  and permits continued play without a result overlay.
- Retry preserves the current checkpoint and edited current-leg setup; reset
  returns to leg 1; only goal 2 confirmation clears and both confirmed balls
  remain visible.
- Current-leg framing, full-course pan/zoom, side view, preview framing, dynamic
  apron/far/shadow bounds, and Fire camera independence all pass automated and
  rendered checks.
- Three course buttons, goal visual states, and all existing HUD controls fit
  and remain keyboard-accessible at every supported desktop resolution without
  persistent progress UI.
- The targeted tests, focused suite, verification, diff check, audit, captures,
  Windows export, and built-app smoke all pass after the final relevant change.
- The implementation is committed as coherent task-owned changes, this file is
  updated with final evidence, and its lifecycle status is changed to `done`.

Stop and revise this contract before continuing if implementation requires a
different course count/order, a different terrain topology or extent, a lower
goal wall, global physics/admission changes, old-course changes, a new visible
progress system, a new dependency, or edits to the retained Paint Mountain
generation contract.
