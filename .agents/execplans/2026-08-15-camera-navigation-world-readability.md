---
type: plan
status: done
created: 2026-08-15
scope: Rebuild camera navigation, remove white world patches, and add readable goal and cannon cues
supersedes: .agents/execplans/2026-08-15-interface-scale-and-close-inspection.md
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/CAMERA_AND_WORLD_READABILITY.ko.md
  - .agents/execplans/2026-08-14-camera-navigation-goal-visibility.md
  - .agents/execplans/2026-08-14-goal-plates-progressive-terrain.md
  - .agents/execplans/2026-08-14-terrain-contrast-height-contract.md
  - .agents/execplans/2026-08-13-longitudinal-relay-course.md
---

# Camera Navigation and World Readability - Execution Contract

The 2026-08-15 course-4 capture and current runtime agree on the failure. The
large clipped-white circles are not terrain-shader output: they are the
`E8E1CE` goal-plate cylinders. Because each low plate is fitted directly onto
the terrain, the player correctly reads them as unexplained white terrain
patches. Their thin unshaded cyan stem and diamond also lose shape at course
scale. Overview zoom resolves an
absolute `14 m` endpoint, then protects only that endpoint by lifting it above
the heightfield. This prevents a point intersection but does not protect the
line of sight or produce a useful view: the camera can be lifted beside an
intervening cliff, crop the mountain, and expose mostly sky or diorama base.
The current cannon preset is another external camera seven metres behind and
5.5 metres above the launcher, not a first-person aim view. Fire deliberately
keeps the current camera unchanged, contrary to the latest request.

This contract replaces the failed close-view correction branch. It retains the
completed compact menu, quiet course rows, `2.0 m` ball, enlarged plate opening,
ten-course extent/relief schedule, non-monotonic goal elevations, and free goal
order. It does not change goal locations, terrain generation, or prepared
artifacts.

## Purpose

- Objective: make every course readable and controllable without camera entry
  into terrain, hidden goal cues, or ambiguous cannon orientation.
- Deliverable: one stable free overview, one true cannon first-person view, one
  transient automatic ball-follow state, exact `Tab` return, no white ground
  patches, thick downward 3D goal arrows, and a visible cannon-direction cue.
- Completion state: reset frames the complete course; overview pan/orbit/zoom
  remain responsive without entering terrain; cannon view looks along the real
  launch vector from the launcher; Fire follows the newest ball; `Tab` restores
  the exact preceding overview or cannon pose; every incomplete goal and the
  selected cannon direction are readable in early and late rendered courses.

## Scope and Boundaries

In scope:

- Camera state ownership, course framing, pan/orbit/zoom, terrain collision,
  near/far clipping, cannon first-person pose, shot follow, and exact return.
- Goal plate/base palette, goal marker geometry and height, full-course
  presentation bounds, cannon visual scale, and direction cues.
- Existing camera/help dock semantics and one minimal first-person reticle.
- Current product/design decisions, focused source contracts, startup smoke,
  and final rendered captures after implementation is complete.

Out of scope:

- Terrain generation, goal locations, prepared artifacts, course count/order,
  accepted extent/relief schedule, ballistics, settlement rules, device
  placement, goal order, cannon-source rules, menus, cards, new panels, or new
  explanatory prose.
- A performance campaign, solution search, exact-physics certification, broad
  suite, or repeated visual experimentation during implementation.

Locked interaction and state decisions:

- Runtime camera states are exactly `OVERVIEW`, `CANNON_FIRST_PERSON`, and
  transient `SHOT_FOLLOW`. There is no side/profile preset and no target or
  next-goal camera state.
- Overview retains left-drag pan, right-drag orbit, wheel/compact-button zoom,
  arrow-key pan, and `Home` reset. A click without drag never changes the pivot.
- Overview reset uses one presentation bound that contains terrain, every goal
  arrow, and the selected cannon cue. It uses the framer result directly;
  remove the current extra `2.0x` far-overview multiplier.
- Replace the absolute `14 m` endpoint with a `28 m` desired minimum distance.
  Use ten logarithmic steps from reset to minimum and six from reset to the
  maximum fit view. Wheel and dock buttons call the same step function.
- Pan response remains distance-scaled but becomes `0.30` instead of `0.45`.
  Orbit response becomes `0.075 / 0.06` degrees per pixel. Preserve the current
  per-event pan clamp and bounds clamp.
- Do not lift the final camera vertically to satisfy terrain clearance. The
  overview owner sweeps a `1.25 m` radius sphere from a terrain-safe pivot to
  the desired orbit point on collision layer 1, excludes runtime goal and
  launcher bodies, and shortens the camera boom to the last non-intersecting
  point with `0.5 m` margin. The pivot is resampled to terrain height plus
  `2.0 m` after pan. If the boom is fully blocked, preserve the last valid pose
  rather than jumping upward or into the sky.
- Camera `far` is recomputed from presentation-bound diagonal and resolved
  camera distance, with a minimum `520 m` and `25%` reserve. `near` remains
  `0.1 m`. The diorama base and shadow range use the same presentation envelope.
- Cannon first-person eye position is the selected launcher pivot at
  `YAW_PIVOT_HEIGHT + 0.65 m`, offset `0.35 m` behind the actual launch vector.
  It looks along `CannonGolfLauncher.launch_direction()` with no orbit, pan, or
  implied target. Its FOV is `70 degrees`, and changing horizontal aim or
  elevation updates it immediately.
- Increase only launcher visual dimensions by `1.6x` around the existing yaw
  pivot. Keep the physics position, yaw/elevation values, barrel-axis length,
  launch origin, and velocity unchanged. Reposition the visual muzzle band so
  the enlarged art still ends on the ballistic barrel axis.
- Add one non-colliding world direction cue at the selected launcher: a dark
  `5.5 m` radius ground ring and matte amber wedge aligned to current world yaw.
  Add one panel-free first-person reticle with a center point and four short
  yaw/elevation chevrons. Existing numeric aim controls remain the exact values;
  do not add a compass panel or duplicate numeric readout.
- Successful Fire stores the preceding planning state only if no stored state
  exists, then immediately follows the newest ball. A second Fire retargets the
  newest ball without overwriting that stored state. Aim and Fire controls stay
  usable subject to the current two-live-ball limit.
- `Tab` during Shot Follow immediately restores the exact stored overview
  pan/orbit/zoom or cannon first-person state. Direct overview/cannon selection
  also exits follow into the selected state. When the followed shot resolves,
  return to the stored state after `0.5 s`; failure cleanup may return sooner if
  the target ceases to exist.
- Shot Follow derives its offset from the ball's horizontal velocity: `12 m`
  behind and `6 m` above, falling back to its last valid travel direction. Its
  camera boom uses the same collision sweep so a grounded ball cannot pull the
  camera through terrain.

Locked world-readability decisions:

- Remove white or near-white ground surfaces. Goal plate floor becomes matte
  moss `#53634F`; segmented wall/rim becomes dark slate `#24394D`. The plate
  remains distinguishable by its circular edge, wall, arrow, and material
  roughness, not by a bright floor. Settlement physics and dimensions do not
  change.
- Keep the current green-gray terrain shader and course palettes. Do not lower
  the whole scene's light to hide one bad material. Keep Sun, fill, and ambient
  energies unchanged. The diorama base must render as muted green-gray rather
  than white; set its shader base to `#596657`, cap photographic detail mix at
  `0.10`, and retain full roughness.
- Keep the physical goal flag at the plate as the local landing cue. Replace
  only the cyan unshaded stem and diamond with one thick downward 3D arrow.
  Use a matte amber `#F2A33A` shaft and cone plus a
  dark `#13243A` collar. The shaft is `1.1 m` thick and `7 m` tall; the conical
  tip is `4.8 m` wide and `4 m` tall. It is real all-angle geometry, has no
  emission, and does not collide or cast a shadow.
- The arrow tip sits at the existing local-skyline marker height: at least
  `8 m` above the highest prepared terrain sample within `32 m` of its goal and
  at least `18 m` above the plate lip. The arrow extends upward from that tip.
  Thus it remains above nearby peaks without moving away from the real goal.
- Every incomplete goal shows the same full arrow because there is no active or
  next goal. A confirmed goal hides its arrow; the retained ball and sparse rim
  state continue to show completion.

Locked carry-forward terrain decisions:

- Preserve the completed horizontal-scale schedule
  `1.00, 1.00, 1.05, 1.10, 1.15, 1.20, 1.28, 1.35, 1.42, 1.50` and minimum
  playable relief schedule `60, 65, 80, 90, 100, 112, 124, 136, 148, 160 m`.
  Relief still belongs to macro peaks, shelves, ridges, and valleys rather than
  local plate support.
- Preserve mixed goal elevations. Goals do not have to rise in completion
  order, and there is still no next goal.
- The older Deep Relay plan contains a course-specific high middle shelf and
  higher summit goal. Treat that completed course contract as retained baseline
  only. It is not evidence for a general rule that every goal belongs near a
  peak, and this plan adds no such rule.

Destructive or irreversible actions:

- None. No prepared artifact or authored course resource changes in this work.

Stop and ask the user before continuing when:

- The same rendered defect reaches a sixth correction attempt.
- Any individual command or capture reaches ten minutes.
- Physics sweep cannot distinguish terrain from goal/launcher bodies without a
  new collision layer or changing gameplay collision.
- True first-person alignment requires changing launch origin or ballistics.
- Goal readability would require moving a goal or regenerating terrain.
- A requested correction would add a fourth camera state, another HUD panel,
  or goal-order semantics.

## Discovery Closure

| Concern | Current evidence and cause | Locked correction | Tasks |
| --- | --- | --- | --- |
| White terrain-like patches | The screenshot circles correspond to `GoalPlateFloor`; terrain palettes are green-gray, but the fitted `E8E1CE` plate reads as part of the ground | Remove white ground materials; moss/slate plate, muted base, unchanged world light | 1.1, 2.1 |
| Reset/far view becomes sky or clipped terrain | Rig blends to complete bounds then multiplies distance up to `2.0x`; endpoint-only lift can jump beside a cliff; presentation bounds omit full arrow geometry | One fit distance, presentation bounds, dynamic far plane, collision boom | 1.1, 3.1-3.3 |
| Drag/zoom feels blocked | `14 m` endpoint is smaller than local cliff scale and pan/orbit responses fight endpoint lifting | `28 m` minimum, restrained response, stable terrain-safe pivot, sweep instead of lift | 3.1-3.3 |
| Cannon preset is not first-person | Current constants place camera `7 m` behind and `5.5 m` above while looking at a separate focus | Pose eye at launcher and look along exact 3D launch direction | 1.1, 4.1 |
| Cannon rotation is unreadable | Launcher base is about `4 m` across on courses hundreds of metres wide; no orientation cue exists | `1.6x` visual art, rotating ground wedge, minimal first-person reticle | 2.3, 4.1-4.2 |
| Fire/Tab behavior conflicts with request | `fire()` never calls follow; D-029/D-034/D-037 require camera independence and `Tab` is return-only | Supersede those clauses: automatic newest-ball follow and exact stored-state return | 1.1, 5.1-5.2 |
| Goal order could be implied accidentally | Older `VisualState` names include future/active, but D-036 and runtime expose every incomplete goal | Same arrow for every incomplete goal; no target framing or next-goal copy | 1.1, 2.2 |

Readiness statement:

- Screenshot, current camera rig, input dispatch, launcher geometry, goal
  geometry/materials, terrain/base shaders, marker skyline calculation, world
  envelope, prior done plans, HUD camera controls, and accepted camera/goal
  decisions were inspected.
- Every material interaction, visual, ownership, and validation decision is
  closed. The executor must implement this contract, not run another camera
  concept search.

Carry-forward audit:

| Prior accepted plan | Retained requirement | Treatment here |
| --- | --- | --- |
| `2026-08-14-goal-plates-progressive-terrain.md` | Physical plates on ordinary terrain, one-second settlement, free goal order, unlocked completed-goal cannon sources, progressive width/relief | Retained unchanged; only plate material and marker presentation change |
| `2026-08-14-terrain-contrast-height-contract.md` | Green-gray non-white terrain, semantic peaks/ridges/valleys, fixed relief schedule, mixed goal elevations | Retained; this plan removes the remaining white plate/base surfaces only |
| `2026-08-13-longitudinal-relay-course.md` | Deep Relay high middle shelf, higher summit goal, and `+25 m` incoming rises | Retained as that course's completed baseline; not generalized to other goals |
| `2026-08-14-camera-navigation-goal-visibility.md` | Terrain-safe exploration and goal markers above local skyline | Replaced only in mechanism: swept boom and thick 3D arrow supersede endpoint lift and cyan marker |
| `2026-08-15-interface-scale-and-close-inspection.md` | Compact menu/cards, `2.0 m` ball, usable plate opening | Completed output retained; failed `14 m` camera endpoint is superseded |

## Tasks

### Phase 1: Make the replacement camera and surface contract authoritative

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`

- [x] **1.1** Record the three-state camera and surface contract.
  - Change: add one accepted decision superseding D-029's explicit-only follow,
    D-034's external cannon view and endpoint lift, and D-037's `14 m` close
    endpoint/fire independence. Update matching current PRD/design clauses.
  - Accept: active text defines overview, cannon first-person, automatic follow,
    exact `Tab` return, no white world-ground patches, all-goals-equal markers,
    and no side/next-goal view.

### Phase 2: Make goals and cannon direction readable in the world

Precondition: task 1.1 is complete.

Source owners: `src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/cannon_golf_launcher.gd`,
`src/cannon_golf/course_builder.gd`, `scenes/cannon_golf/cannon_golf.tscn`,
`tests/cannon_golf_goal_test.gd`, `tests/cannon_golf_course_build_test.gd`

- [x] **2.1** Remove white ground patches without changing world lighting.
  - Accept: plate floor/wall and base shader equal the locked values; Sun, fill,
    ambient, goal physics, goal dimensions, and terrain palettes are unchanged;
    no visible world ground surface uses the old pale plate materials.
- [x] **2.2** Keep the plate flag and replace only the airborne cyan marker.
  - Accept: every goal retains its physical flag; every incomplete goal also
    has one downward arrow at its actual `x/z`; the arrow tip clears the
    computed local skyline; confirmed arrows are hidden; no active/future/
    next-goal distinction remains.
- [x] **2.3** Enlarge cannon art and add its world-yaw cue.
  - Accept: visual extents are `1.6x`, cue wedge tracks current yaw after key,
    slider, and source changes, while launch origin/velocity remain byte-for-byte
    equivalent for the same `50 / 50 / 50` input.
### Phase 3: Replace endpoint lift with stable overview navigation

Precondition: Phase 2 source changes are stable.

Source owners: `src/cannon_golf/course_camera_rig.gd`, new responsibility-shaped
`src/cannon_golf/overview_camera_solver.gd`,
`src/cannon_golf/course_world_envelope.gd`,
`src/cannon_golf/cannon_golf_game.gd`, `tests/cannon_golf_camera_test.gd`

- [x] **3.1** Extract overview pose/framing from the camera state owner.
  - Change: keep transitions/follow in the rig; move overview focus, bounds,
    orbit, pan, zoom, and desired pose math to the solver. Remove cannon scaling,
    `14 m`, `2.0x` overview, and vertical endpoint-lift paths.
  - Accept: reset fits presentation bounds directly; ten zoom-ins resolve to a
    desired `28 m`; six zoom-outs never exceed the fit view; no old constants or
    competing overview resolver remains reachable.
- [x] **3.2** Add terrain-safe pivot and swept camera boom.
  - Accept: pan/orbit/zoom and interpolation keep the camera sphere outside
    terrain; blocked motion shortens the boom or preserves the last pose and
    never raises the camera into a sky-dominant jump.
- [x] **3.3** Use presentation bounds for camera, base, shadow, and clipping.
  - Accept: all goal arrows and cannon cue fit reset framing on courses 1, 4,
    and 10; finite near/far planes contain the complete visible course.

### Phase 4: Implement true cannon first-person and minimal aim cues

Precondition: Phase 3 passes its focused source contract.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`,
`tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_ui_contract_test.gd`

- [x] **4.1** Resolve cannon view directly from launcher transform and direction.
  - Accept: at minimum/maximum yaw and elevation the camera origin remains at
    the selected launcher and its forward vector matches launch direction within
    `0.1 degrees`; no goal position enters the calculation.
- [x] **4.2** Add the panel-free reticle and update compact camera/help semantics.
  - Accept: reticle appears only in cannon first-person; overview and follow
    buttons remain one restrained dock; help says left-drag pan, right-drag
    orbit, wheel zoom, `1` overview, `2` cannon, and `Tab` return.

### Phase 5: Make firing follow the ball and restore exact prior context

Precondition: Phases 3-4 are complete.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_input_test.gd`

- [x] **5.1** Store/restore one exact planning snapshot around Shot Follow.
  - Accept: Fire from overview and first-person follows the spawned ball; `Tab`
    restores exact prior state; second Fire retargets without replacing the
    snapshot; direct view selection exits follow deterministically.
- [x] **5.2** Make follow velocity-relative and collision-safe.
  - Accept: airborne and grounded follow never enter terrain, outcome returns
    after `0.5 s`, quick retry follows its replacement, and controls remain
    usable under the existing live-ball limit.

### Phase 6: Run one final functional and rendered gate

Preconditions: tasks 1.1-5.2 are complete. Do not run UI, performance, broad,
solution, certification, or rendered tests earlier.

- [x] **6.1** Run the focused final gate once through
  `scripts/invoke-cannon-golf-validation.ps1`.
  - Order: camera (`90 s`), input (`90 s`), goal (`300 s`), course build
    (`120 s`), UI contract (`60 s`), app flow (`90 s`), catalog smoke (`120 s`).
  - Accept: every process exits zero, persistent-log growth is zero, and no
    task-owned Godot process remains. Stop at first failure; rerun only its
    owner after one material correction.
- [x] **6.2** Capture final user-facing states once.
  - Capture: courses 1, 4, and 10 at `1280 x 720`: reset overview, panned close
    overview, cannon first-person at `50 / 50 / 50`, and active Shot Follow.
  - Accept: no white terrain-like patch remains; goals/arrows separate from
    terrain; full course is not sky-clipped; close navigation works; cannon
    direction is clear; HUD has no new panel or overlap.
- [x] **6.3** Run the task-scoped quality and hygiene gate.
  - Accept: codebase-quality audit finds no catch-all or competing camera owner;
    `git diff --check` passes; task-owned captures/logs are removed after review;
    no prepared resource changed; one coherent task commit remains.

## Verification

- Implementation inspection and cheap static checks may run during Phases 1-5.
  Godot/UI/rendered validation waits until Phase 6, as requested.
- The named wrapper prevents persistent log growth and owns its timeout cleanup.
  A timeout limits a stuck tool process, not gameplay time or player behavior.
- A passing gate is not rerun unless its owning input changed.
- One failed gate permits one material correction and one rerun. A third need is
  a plan change. A sixth correction for the same rendered symptom stops the task
  and asks the user.
- No individual command may run beyond ten minutes. This plan contains no
  performance benchmark, solution search, course-generation run, or physics-
  certification run.

## Risks

- A camera boom can stay outside terrain while a nearer peak still blocks the
  selected pivot. The overview must preserve orbit and pan recovery; collision
  code must not claim that every angle has an unobstructed sightline.
- Enlarging only launcher art can visually separate the muzzle from the fixed
  ballistic origin. Acceptance therefore compares their axis and endpoint
  without changing the underlying launch calculation.
- A marker that is visible at reset can still overlap another arrow in one
  orbit angle. Real 3D depth, local-skyline clearance, and free orbit are the
  chosen solution; screen-space labels or target ordering are not fallbacks.
- Automatic follow could interrupt repeated aiming. Exact `Tab` return, editable
  controls, and the unchanged two-ball limit are required safeguards.

### Predetermined Contingencies and Change Control

- If the sphere sweep starts overlapped at a terrain-safe pivot, move only the
  sweep origin upward by its `1.25 m` radius; do not revive endpoint lifting.
- If an arrow is hidden by a taller peak outside the `32 m` local radius, raise
  that arrow tip to the maximum terrain height inside the goal's camera-visible
  presentation cell plus `8 m`; do not move its `x/z` or add screen-space labels.
- If the enlarged launcher art occludes first-person view, hide only its camera-
  facing barrel mesh in first-person and keep the world cue/reticle; do not move
  the camera away from the launcher.
- If automatic follow motion is uncomfortable, reduce only follow interpolation
  response from `4.2` to `3.2`; do not remove automatic follow or exact `Tab`
  return.
- Any need to move goals, regenerate terrain, change goal count, accepted
  relief/extent, ballistics/collision layers, add another camera state, or add a
  HUD panel is a contract change and requires user approval.

## Progress

- [x] Inspected the current screenshot, runtime camera/input/state code, goal
  and launcher geometry, terrain/base materials, skyline marker calculation,
  world envelope, prior done plans, HUD dock, and accepted product/design
  decisions.
- [x] Closed camera-state, collision, visual-cue, input, ownership, and final-
  validation decisions in this contract.
- [x] Implemented the surface, goal-arrow, launcher-cue, overview, first-person,
  follow, exact-return, and minimal-reticle changes without regenerating terrain.
- [x] Focused camera, input, goal, course-build, UI, app-flow, and catalog checks
  passed through the storage-safe wrapper with zero persistent-log growth.
- [x] Reviewed courses 1, 4, and 10 in reset, close-pan, cannon, and follow
  captures; removed the first-person barrel occlusion found by that review.

## Next Steps

- [x] Complete. No follow-up task remains in this execution contract.

## Completion and Stop Conditions

Mark this plan `done` only after tasks 1.1-6.3 pass and the final captures meet
the locked visual acceptance. Stop with the exact failing task and evidence if
any stated stop condition occurs. Do not mark completion from source edits or
headless tests alone.
