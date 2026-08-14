---
type: plan
status: active
created: 2026-08-14
scope: Make Cannon Golf camera exploration controlled and terrain-safe, replace side view with a reusable cannon view, and keep every goal visibly locatable
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-14-terrain-contrast-height-contract.md
---

# Terrain-safe Camera and Goal Visibility - Execution Contract

The current ten-course build keeps free camera exploration, but its pan, orbit,
and zoom inputs move too aggressively, the camera pose is not conditioned
against the generated terrain, and the existing small flags disappear against
high-relief courses. This contract replaces the obsolete side preset with a
per-leg cannon preset, makes every planning pose terrain-safe, and gives each
goal a large generated world marker without flattening the accepted mountain
relief.

## Purpose

- Objective: make map inspection controlled, prevent the planning camera from
  entering terrain, and make every goal easy to locate from the authored views.
- Deliverable: updated product decisions, camera navigation and collision
  conditioning, oblique/cannon view controls, goal visibility conditioning,
  rebuilt prepared courses, and representative rendered evidence.
- Completion state: the game starts with all ten courses; gentle input produces
  gentle motion; no supported planning pose intersects terrain; `1` selects the
  oblique view, `2` selects the current leg's cannon view; every active and
  future goal has an obvious marker above its local skyline.

## Scope and Boundaries

In scope:

- Planning-camera wheel zoom, left-drag pan, right-drag orbit, and arrow pan.
- Terrain clearance for oblique, cannon, zoomed, panned, orbited, and smoothly
  interpolated planning poses.
- Replacement of the side/profile preset, HUD action, shortcut copy, and tests
  with a deterministic per-leg cannon preset.
- Large non-colliding world-space goal markers and a bounded terrain apron that
  keeps a goal mouth from being swallowed by an adjacent terrain wall.
- Rebuilding the existing ten prepared course artifacts after the local goal
  apron changes.

Out of scope:

- Ball physics, success/failure rules, aim controls, shot follow, course count,
  course relief targets, goal order, or device placement.
- A minimap, screen-edge arrows, through-terrain HUD waypoint, or automatic
  camera movement on Fire.
- A new terrain algorithm or any reduction of the accepted peak/valley relief.
- Broad physics certification, solution search, or exhaustive test suites.

Constraints and invariants:

- Fire never changes the selected planning view or its explored pose. Shot
  Follow remains explicit and Tab retains its existing behavior.
- Home still restores the authored high-oblique view, zero pan/orbit, and
  default distance.
- The cannon preset is generated from the active leg's launcher, shot axis, and
  goal. It is recomputed when a relay advances and is available at any time.
- Goal markers are visual only. They do not add collision or change settlement.
- Goal visibility conditioning affects only the small annulus outside each
  bowl. It must not flatten peaks, valleys, route relief, or the bowl interior.
- All camera correction is deterministic and bounded. No per-frame search,
  persistent diagnostic log, or runtime terrain rebuild is introduced.
- Each course still bakes below the existing 60-second hard limit; expected
  generation time remains well below one second.

Destructive or irreversible actions:

- None. Prepared `.res` files are reproducible build products.

Exact actions requiring owner or user approval:

- None within this contract.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Zoom is too strong | `course_camera_rig.gd` multiplies distance by `0.78` per step, a 22% jump; current PRD/tests require at least 20% | `ZOOM_FACTOR_PER_STEP`, camera test, zoom captures | Use `0.90` per wheel/button step; preserve current min/max bounds | 1.1, 2.1 |
| Drag is too strong | Left drag intersects two screen rays with a world plane and applies the complete world-space difference; shallow angles and distant cameras amplify it | `pan_drag()` and `camera-pan-panned.png`; capture/test require four 120 px drags to move over 20 m | Replace ray-plane panning with camera-basis, FOV, viewport-height, and focus-distance conversion; apply `0.45` response and cap one event to 2% of horizontal course span | 2.1, 4.1 |
| Orbit/arrow movement is coarse | Orbit uses `0.18/0.14` degrees per pixel; arrow pan uses 2% of course span per press | Camera rig constants and `pan()` | Use `0.10/0.08` degrees per pixel and 1% of span per arrow press | 2.1 |
| Camera enters terrain | `_resolve_planning_pose()` frames an AABB and writes the resulting position directly; it has no height sample, ray/sphere test, or clearance rule. Focus clamping only constrains an AABB | Camera rig source and high-relief course captures | Give the rig the prepared-course height sampler; keep focus at least 1.5 m above terrain and every camera candidate at least 2.0 m above terrain; sample the focus-to-camera segment at intervals no larger than 1.5 m, refine the first blocked interval, and apply the same guard to interpolated positions | 2.2, 4.1 |
| Side view is obsolete | Runtime, HUD, shortcut copy, captures, and specs still expose `side`; key `2` selects it | Game/HUD/camera source, PRD FR-7, D-018, current side button | Supported planning presets become `oblique` and `cannon`; key/button `1` = oblique and `2` = cannon | 1.1, 2.3, 4.1 |
| Cannon view is missing | D-018 explicitly rejected it and the rig has no launcher/goal context | Decisions and camera source | Compute per-leg forward from `shot_axis_yaw_degrees`; place the desired camera 14 m behind and 7 m above the launcher and look 24 m forward/3.5 m above it, then pass that pose through the same terrain-clearance guard | 1.1, 2.3 |
| Goal markers disappear | Active flag is only `4 x 1.7 m` at 9 m; future flags fall to 62% scale and 4.2 m. On courses 5 and 10, most flags cannot be found in the rendered frame | `settlement_goal.gd`, `terrain-fixed/course-4.png`, `terrain-fixed/course-9.png` | Keep the rim flag, add a centered airborne marker, and calculate a common marker-top height from the maximum terrain within 32 m: at least 18 m above the lip and 8 m above that local skyline. Active/future/confirmed states remain distinct without making future markers disappear | 3.1, 4.1 |
| Camera framing ignores markers | Prepared per-leg bounds include launcher and goal-floor positions but not the flag or marker top; no marker-to-camera occlusion check exists | Factory, builder, and camera framer source | Expand runtime per-leg framing with the complete marker envelope and check the authored oblique/cannon sightline; keep decorative dressing outside the goal marker's local clearance area | 3.1, 4.2 |
| Goal mouth can be visually buried | Goal carving blends from lip to arbitrary terrain over only 5 m; an immediately adjacent peak can form an opaque wall. Builder provides marker code only goal position/radius/lip | `_carve_goal()`, builder source, high-relief captures | Add a 14 m visibility apron outside each bowl and cap only that annulus to a smooth rise no steeper than 0.45 m per horizontal metre; preserve the bowl floor/rim and all terrain outside the apron | 3.2, 3.3 |
| Existing checks encode the bug | Camera test requires a 20% zoom step; input/capture checks require more than 20 m movement after four drags; capture states still use side | Camera/input tests and capture harness | Replace these expectations with bounded-response, terrain-clearance, oblique/cannon, and goal-marker visibility checks | 4.1 |

Rendered baseline inspected on 2026-08-14:

- `.godot/capture-temp/terrain-fixed/course-0.png`: one active flag is
  technically present but tiny compared with the course.
- `.godot/capture-temp/terrain-fixed/course-4.png`: the HUD reports three
  goals, while their flags are not readable against the terrain.
- `.godot/capture-temp/terrain-fixed/course-9.png`: the HUD reports six goals,
  while only a tiny cyan trace is visible.
- `.godot/capture-temp/camera-pan-panned.png`: the camera focus has traversed a
  large part of the world and leaves the cannon isolated far from the terrain.

Readiness statement:

- Product, camera, terrain, marker, UI, shortcut, and validation decisions are
  closed. No owner choice is required before implementation.
- Existing prepared height sampling, generated leg data, HUD view buttons, and
  background capture harness provide the required seams.

## Tasks

### Phase 1: Supersede obsolete product rules

Goal: make the current user decision authoritative before changing behavior.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`

- [ ] **1.1** Replace the side-view and 20%-zoom requirements.
  - Change: record oblique plus per-leg cannon as the two planning presets;
    specify the gentler navigation values and terrain-clearance requirement;
    retain free pan/orbit/zoom and explicit Shot Follow.
  - Accept: no active canonical clause requires side/profile or a minimum 20%
    zoom jump; the history of the earlier decision remains truthful.

### Phase 2: Make camera exploration controlled and terrain-safe

Goal: correct navigation at its camera-rig owner without coupling input code to
terrain generation.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/course_builder.gd`

- [ ] **2.1** Replace the sensitivity model.
  - Change: use the locked zoom/orbit/arrow constants and projection-based pan
    conversion; remove the ray-plane delta path.
  - Accept: one 120 px drag cannot move farther than 2% of course span; one zoom
    step changes distance by 10%; response remains proportional at near and far
    zoom; a click without motion changes nothing.
- [ ] **2.2** Condition every planning pose against terrain.
  - Change: pass the builder's prepared height sampler into the rig, raise an
    invalid focus, shorten/refine a blocked focus-to-camera segment, and guard
    the actual interpolated candidate before assigning the camera transform.
  - Accept: camera and focus clear the terrain margins at default, min/max zoom,
    full legal pitch, course edges, and while transitioning; correction is
    stable and does not oscillate.
- [ ] **2.3** Generate and expose the cannon preset.
  - Change: replace `side` with `cannon`, provide active launcher/axis/goal
    context on course load and relay advance, derive the locked behind-cannon
    pose, and terrain-condition it through task 2.2.
  - Accept: the cannon is visible in the foreground, the view faces the active
    shot direction, `2` can enter it from planning or follow, and changing legs
    updates it without changing aim or firing.

### Phase 3: Keep goals visibly locatable

Goal: preserve real recessed goals while making their positions unmistakable.

Source owners: `src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/course_builder.gd`,
`src/cannon_golf/trajectory_course_generator.gd`,
`resources/cannon_golf/prepared/*.res`

- [ ] **3.1** Build terrain-aware world markers.
  - Change: sample the prepared terrain within 32 m of each goal in the builder;
    pass the resulting skyline height to the goal; retain the physical rim flag
    and add a large centered, non-colliding airborne marker at the locked top
    height. Expand per-leg framing with the complete marker envelope and keep
    decorative dressing outside the goal marker's local clearance area. Use
    strong active, readable future, and retained confirmed shapes; color remains
    secondary.
  - Accept: every goal marker clears its local skyline by 8 m, future markers
    remain at least 75% of active size, authored oblique/cannon sightlines reach
    the marker without terrain or dressing interception, and the retained
    confirmed ball remains the primary completion cue.
- [ ] **3.2** Prevent an adjacent terrain wall from swallowing the goal mouth.
  - Change: extend goal conditioning with the locked 14 m bounded apron and
    slope cap, then reapply the unchanged bowl carve and corridor protection.
  - Accept: the complete rim remains a recess boundary; no center bulge is
    introduced; terrain beyond the apron and catalog relief metrics are
    unchanged.
- [ ] **3.3** Rebuild all ten prepared courses once.
  - Change: use the storage-safe bake path after camera-independent terrain
    changes settle.
  - Accept: all artifacts remain identity-valid, every course builds below
    60 seconds, and existing height/goal-count/leg-order contracts remain true.

### Phase 4: Replace stale UI and inspect the game

Goal: align controls and verify the actual rendered result without a broad test
campaign.

Source owners: `src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`,
`tests/cannon_golf_camera_test.gd`,
`tests/cannon_golf_input_test.gd`,
`tests/cannon_golf_ui_contract_test.gd`,
`tests/capture_cannon_golf_frame.gd`, this contract

- [ ] **4.1** Replace side UI/copy and stale camera expectations.
  - Change: reuse the current side-button slot for a cannon icon and localized
    `Cannon view (2)` copy; update shortcut help, state selection, and the
    lightweight capture assertions for the locked sensitivity, collision, and
    marker contracts.
  - Accept: no normal-play control or active help text offers side view; the
    action dock does not grow or clip at 1280x720 and 1600x900.
- [ ] **4.2** Run only the agreed lightweight runtime gate and inspect pixels.
  - Change: start the game once, load all ten prepared courses, then capture
    courses 1, 5, and 10 in oblique and cannon views plus one deliberately
    panned/orbited collision-edge state.
  - Accept: the game starts; all ten maps load; no camera is inside terrain;
    movement is visibly controlled; every goal is locatable by its airborne
    marker; active bowl mouths are readable in the current-leg oblique and
    cannon captures.
- [ ] **4.3** Audit and commit.
  - Change: run the task-scoped quality audit, update this progress ledger, and
    create coherent scoped commits only after the visual gate passes.
  - Accept: no task-owned process or persistent diagnostic log remains and no
    unrelated file is included.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Edit loop | `git diff --check` and focused source inspection | A task-owned source changes | A relevant source changes |
| Bake gate | Storage-safe course bake, one pass, 60-second per-course limit | Goal apron implementation settles | Generator or prepared identity changes |
| Runtime gate | Start the canonical game and load the ten course catalog once | Bake and UI changes settle | Startup/catalog inputs change |
| Render gate | Background 1280x720 captures: courses `0, 4, 9` in `planning` and `cannon`, plus a high-relief collision-edge state; inspect every PNG | Runtime gate passes | Camera, terrain, marker, or HUD pixels change |

Validation rules:

- Do not run physics certification, solution replay, or the broad suite.
- Startup proves only that the game runs; rendered captures are required for the
  camera and marker defects because they are visual/spatial.
- Stop a bake immediately if any course exceeds 60 seconds. Do not expand a
  timeout to hide a generation regression.
- Run each gate once after its relevant implementation batch, and rerun only
  after a material fix.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| Terrain clearance leaves no valid point on the requested focus-to-camera segment | Move the focus upward to its 1.5 m surface clearance, then select the nearest valid segment point with 2.0 m camera clearance | Do not disable collision or move outside exploration bounds |
| The cannon preset is blocked by terrain directly behind the launcher | Shorten the 14 m rear offset through the same segment solver, retaining at least 4 m behind the cannon; if less remains, raise the camera up to 8 additional metres | Do not move the launcher or change its shot axis |
| A marker still falls behind the local skyline in a rendered authored view | Increase only the sampled skyline radius to 40 m and preserve the 8 m clearance | Do not enable through-terrain rendering or add a HUD waypoint without a new user decision |
| Goal apron reduces an accepted relief metric | Preserve the peak/valley owner outside the 14 m annulus and recompute conditioning order | Do not weaken relief, rim bands, or the apron contract |
| A material fact contradicts this contract | Stop the affected branch and update this contract before implementation continues | Do not improvise a competing camera or marker owner |

## Progress and Next Steps

- Canonical progress: discovery complete; implementation not started.
- Current phase: Phase 1 pending.
- Next task: 1.1, then camera tasks 2.1-2.3.
- Baseline evidence: current camera has no terrain query; zoom is 22% per step;
  four large drags are expected to exceed 20 m; future flags shrink to 4.2 m;
  representative three- and six-goal captures do not expose readable markers.
- This document is the execution contract for the next implementation turn.
