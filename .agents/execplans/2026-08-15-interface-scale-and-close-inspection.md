---
type: plan
status: superseded
superseded_by: .agents/execplans/2026-08-15-camera-navigation-world-readability.md
created: 2026-08-15
scope: Compact the main menu and course cards, double the shared ball radius, and make overview zoom reach terrain at a predictable safe distance
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-14-goal-plates-progressive-terrain.md
  - .agents/execplans/2026-08-14-camera-navigation-goal-visibility.md
---

# Interface Scale and Close Inspection - Execution Contract

This contract was superseded after its `14 m` endpoint and vertical
heightfield-lift collision model produced terrain-safe but unusable cliff
views. Completed menu, course-row, ball-size, goal-opening, and prepared-course
work remains the retained baseline. The replacement contract owns all remaining
camera, world-cue, and final-validation work.

Fresh `1280 x 720` captures show four connected presentation problems. The
single-line `CANNON GOLF` label forces the main-menu panel and every menu action
to be much wider than their content. Course rows draw a selected outline and a
second expanded focus outline at the same time. The current shared ball radius
is still `1.0 m`, half the requested radius. Overview zoom remains relative to
the complete course bounds, so a few inputs still look like a whole-course
view, while the fixed minimum can abruptly put the camera against a cliff. This
contract fixes those owners without adding panels, labels, or navigation modes.

## Purpose

- Objective: make the front-end lighter and the in-game scale and camera
  controls immediately readable.
- Deliverable: a narrow two-line main menu, quiet single-edge course rows, one
  `2.0 m` physical and visual ball radius, map-size-independent close zoom, and
  terrain-safe rendered evidence for early and late courses.
- Completion state: the same four main-menu actions remain in one compact
  panel; exactly one course appears selected without a double outline; ball
  mesh and collider both use radius `2.0 m`; twelve zoom-in actions move any
  course from its default overview to a useful `14 m` inspection distance
  without camera-ground intersection.

## Scope and Boundaries

In scope:

- Main-menu title wrapping, panel bounds, content margins, and action width.
- Course-row normal, hover, selected, and keyboard-focus surfaces plus row gap.
- The shared ball radius and directly dependent muzzle, trajectory, goal,
  construction-identity, and prepared-artifact inputs.
- High-oblique planning zoom and the camera's terrain-clearance footprint.
- Current product/design decisions, focused contracts, final captures, and one
  prepared-course rebuild after the ball-size change.

Out of scope:

- New menu sections, cards, explanatory copy, icons, camera presets, goals,
  courses, devices, mechanics, or terrain redesign.
- Changing the ball material, gravity, legal aim/power range, motion time scale,
  goal order, cannon-source behavior, or fire/camera independence.
- A solution search, physics certification campaign, performance benchmark,
  broad test suite, or repeated visual tuning loop.

Locked decisions and invariants:

- Keep one main-menu `BrandPanel`. Set the title to `CANNON\nGOLF`; do not create
  a separate title panel. At `1280 x 720`, use a `356 px` panel width, `34 px`
  horizontal content margins, `60 px` title type, and `-8 px` title line
  spacing. The resulting action width is `288 px`; the four existing actions
  and focus order do not change.
- Keep the existing outer course-list panel and `7 px` scrollbar. Course rows
  remain at least `68 px` high, but their gap becomes `6 px`, corner radius
  becomes `6 px`, and the normal row loses its shadow. Selection uses a quiet
  blue tint plus one `3 px` left accent. Keyboard focus uses the same edge with
  a `2 px` accent and no expanded all-side outline. Selected copy remains blue;
  only one toggle may be pressed.
- The shared ball radius becomes exactly `2.0 m` and therefore diameter becomes
  `4.0 m`. `CannonGolfBallistics.BALL_RADIUS`, `CannonGolfBall.RADIUS`, the
  sphere mesh, and sphere collider remain one value. A visual-only scale is not
  permitted.
- Existing `8-14 m` goal-plate radii remain unchanged. A plate wall must remain
  physically useful for the larger ball: the constructed wall height is at
  least `0.8 * BALL_RADIUS`, and its incoming opening must be at least the ball
  diameter plus `0.5 m`. These limits may raise a wall or widen its existing
  opening; they must not add a new enclosing basin.
- High-oblique zoom uses twelve equal control steps from default overview to a
  `14 m` focus-to-camera close distance on every course. The distance curve is
  logarithmic, so each input produces a visible proportional change and late
  courses do not stop farther away. Six zoom-out steps reach the current full
  overview. Wheel and compact buttons invoke the same step function.
- Cannon view remains local and unchanged. Pan, orbit, reset, Shot Follow, fire
  independence, and stored planning pose remain unchanged.
- Overview collision clearance samples a `1.25 m` camera footprint at its
  center plus eight radial points and raises the camera above the highest
  sampled terrain by `2.0 m`. This applies to desired and interpolated poses so
  the camera body and near plane cannot enter a steep face.
- Changing the ball radius changes constructive trajectory and clearance
  inputs. Increment `CannonGolfPreparedCourse.CONSTRUCTION_VERSION` and rebuild
  all ten prepared artifacts once. Runtime generation remains forbidden and
  each course retains the existing hard `60 s` construction limit.
- All UI/runtime validation occurs after implementation and artifact rebuilding.
  Do not run the performance suite or exact solution/certifier tests for this
  work.

Destructive or irreversible actions:

- None. Prepared `.res` artifacts are reproducible outputs and are replaced
  only by the approved deterministic bake.

Stop and ask the user before continuing when:

- The same implementation/capture correction would be attempted a sixth time.
- Any individual validation reaches ten minutes.
- Any course construction reaches its existing `60 s` limit.
- A `2.0 m` ball cannot use the current goal-radius catalog without changing
  course layout, ballistics ranges, or the requested radius.
- Useful close zoom requires a new camera mode or physics raycast owner instead
  of the heightfield sampler already owned by the camera rig.

## Discovery Closure

| Concern | Current evidence and cause | Locked correction | Tasks |
| --- | --- | --- | --- |
| Main menu is too wide | Fresh menu capture shows a `444 px` panel; `MenuTitle` is `64 px` and the single-line title consumes almost the complete inner width, so the buttons inherit a `376 px` width | Wrap the title inside the existing panel and reduce the panel/action widths to `356/288 px`; add no new component | 1.1, 2.1 |
| Course-card edges look doubled | `StageCardSelected` draws a `2 px` blue border on four sides; `StageCardFocus` then draws another `2 px` gray border with `2 px` expand margins. The selected button grabs focus, so both appear together | Remove floating-card shadow and all-side selected border; use one left-edge accent for selected/focus with no expanded focus margin | 1.1, 2.2 |
| Ball remains too small | `CannonGolfBallistics.BALL_RADIUS` is `1.0`; `CannonGolfBall.RADIUS` correctly shares it with the mesh and collider | Change the single shared value to `2.0`, preserve the dark material, condition plate wall/opening dimensions, and rebuild dependent prepared artifacts | 1.1, 3.1-3.2 |
| Useful close zoom is inconsistent | The rig multiplies a full-course framed pose by a fixed `0.38-2.0` ratio. Three zoom inputs still show nearly the whole captured course; an extreme/minimum capture abruptly fills the screen with a cliff. Later, wider courses necessarily stop farther from the focus | Replace course-relative minimum scaling with a twelve-step logarithmic distance range ending at an absolute `14 m`, while preserving full-course reset/overview | 1.1, 4.1 |
| Terrain collision is point-sized | `_terrain_safe_camera_position()` samples only the camera's exact `x/z` point. It does not account for the camera near plane or nearby steep triangles | Sample a small nine-point camera footprint and lift above the highest local terrain sample at every interpolated pose | 4.2 |
| Existing decision text would conflict | D-034 fixes a `10%` distance step and D-035 fixes a `1.0 m` ball | Record a new accepted decision that supersedes only those two clauses; preserve all other camera, goal, and multi-goal decisions | 1.1 |

Readiness statement:

- Every material UX, gameplay, ownership, artifact, and validation decision is
  closed. No research or design choice remains for the executor.
- The relevant scenes, shared theme, ball/goal owners, camera rig, prepared
  artifact identity, bake entrypoint, focused tests, and capture harness exist
  in the current Godot `4.7.1` project.

## Tasks

### Phase 1: Make the new scale and zoom contract authoritative

Goal: prevent older accepted numeric values from overriding this request.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`

- [x] **1.1** Record the compact front-end, `2.0 m` shared ball, and close-
  inspection camera contract.
  - Change: append one decision that supersedes only D-034's fixed `10%` zoom
    step and D-035's `1.0 m` ball; update active PRD/design clauses to the locked
    values above.
  - Accept: active canonical text contains no current `1.0 m` ball or fixed
    `10%` planning-step requirement and does not introduce another menu panel,
    camera mode, or target/next-goal wording.

### Phase 2: Simplify the front-end surfaces

Goal: reduce width and edge noise without reducing readability or access.

Precondition: task 1.1 is complete.

Source owners: `scenes/cannon_golf/app/cannon_golf_main_menu.tscn`,
`scenes/cannon_golf/app/cannon_golf_course_select.tscn`,
`resources/ui/paint_mountain_theme.tres`,
`tests/cannon_golf_ui_contract_test.gd`

- [x] **2.1** Compact the main-menu title and actions.
  - Change: apply the locked two-line title, panel bounds, margins, line spacing,
    and action width in the existing scene/theme owners.
  - Accept: at `1280 x 720`, the title does not clip, all four actions fit the
    same panel, the action width is `288 px`, and keyboard focus order remains
    Play, Course Select, Settings, Quit.
- [x] **2.2** Replace stacked course-card outlines with one restrained edge.
  - Change: apply the locked row gap/radius/shadow/left-accent styles and update
    the UI contract to reject expanded focus margins and all-side selected
    borders.
  - Accept: all ten labels remain readable, exactly one row is selected, mouse
    hover and keyboard focus remain visible, no selected row shows a second
    outside rectangle, and the scrollbar remains no wider than `8 px`.

### Phase 3: Enlarge the real ball and rebuild its construction outputs

Goal: make the requested size affect the object players see and play with.

Preconditions: task 1.1 is complete; Phase 2 source changes are stable.

Source owners: `src/cannon_golf/cannon_golf_ballistics.gd`,
`src/cannon_golf/golf_ball.gd`, `src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/prepared_course.gd`,
`resources/cannon_golf/prepared/*.res`,
`tests/cannon_golf_ballistics_test.gd`, `tests/cannon_golf_goal_test.gd`

- [x] **3.1** Set one `2.0 m` physical/visual radius and keep goal plates usable.
  - Change: update the shared radius, every radius assertion, and only the
    plate wall/opening guards directly required by the larger sphere.
  - Accept: mesh radius equals collider radius equals ballistic radius `2.0`;
    the current material is unchanged; the smallest current plate still offers
    positive settlement area and an opening wider than `4.5 m`.
- [x] **3.2** Invalidate and rebuild all ten construction artifacts once.
  - Change: increment construction identity, run the approved bake after all
    source changes settle, and save every valid artifact.
  - Accept: the bake reports ten valid saves, every course completes below
    `60 s`, catalog smoke loads all ten without runtime generation, and no
    artifact retains the prior construction version.

### Phase 4: Make close terrain inspection predictable and safe

Goal: reach a useful local view on every map without entering terrain.

Preconditions: tasks 1.1 and 3.2 are complete.

Source owners: `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`tests/cannon_golf_camera_test.gd`,
`tests/capture_cannon_golf_frame.gd`

- [x] **4.1** Replace fixed full-course scaling with the locked distance curve.
  - Change: store a bounded inspection step, resolve its logarithmic distance
    from the current unscaled framed pose, and keep reset/default/maximum
    overview and stored-pose behavior intact. Update capture assertions to use
    resolved camera distance instead of the retired ratio constants.
  - Accept: twelve zoom-in actions end at `14 m +/- 0.25 m` on courses 1 and 10;
    each action moves closer; six zoom-out actions from default reach a complete
    course overview; reset restores default; cannon view remains unchanged.
- [x] **4.2** Protect the camera footprint on steep terrain.
  - Change: replace the single camera-point clearance check with the locked
    center-plus-eight-samples footprint for immediate and interpolated poses.
  - Accept: center and all eight footprint points remain at least `2.0 m` above
    sampled terrain through close zoom, orbit, pan, transition, and reset; all
    positions remain finite.

### Phase 5: Run the one final validation and visual gate

Goal: verify only startup, directly changed contracts, and final rendered
appearance after every implementation task is complete.

Preconditions: tasks 1.1-4.2 are complete; no earlier broad/UI/performance run
is authorized.

Source owners: task-owned tests and `.godot/capture-temp/` evidence only.

- [x] **5.1** Run the focused end gate once.
  - Change: run the approved storage-safe wrapper for ballistics, goal, camera,
    UI contract, app flow, and catalog smoke in that order. Do not run solution,
    certifier, broad-suite, or performance tests.
  - Accept: each process exits zero, grows no persistent Godot log, and leaves
    no task-owned Godot process. Stop at the first failure and correct only its
    owning task before one rerun.
- [ ] **5.2** Capture and inspect final user-facing states.
  - Change: capture `menu`, `course_select` with a non-default selected row,
    `two_live`, and close overview for courses 1 and 10 at `1280 x 720`; capture
    menu/course select once at `1600 x 900` for fit.
  - Accept: title and actions are compact and unclipped; course selection has
    one quiet edge; live balls are visibly twice the prior diameter; both close
    views show local terrain instead of a whole-course thumbnail or an
    intersecting cliff; HUD remains unchanged.
- [ ] **5.3** Audit task scope and repository hygiene.
  - Change: run the task-scoped quality audit, `git diff --check`, delete only
    task-owned temporary capture logs, and commit one coherent implementation.
  - Accept: no new catch-all owner, panel, card type, camera mode, persistent
    log, unrelated edit, or uncommitted task file remains.

## Validation and Rework Controls

Use `scripts/invoke-cannon-golf-validation.ps1` for every Godot script run.
Commands are final-gate commands only; do not run them during Phases 1-4.

| Gate | Command | Success condition | Rerun trigger |
| --- | --- | --- | --- |
| Ball | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_ballistics_test.gd -TimeoutSeconds 60` | Shared radius and launch consumers pass | A ballistics/ball radius owner changes |
| Goal | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_goal_test.gd -TimeoutSeconds 300` | Larger sphere retains valid plate entry/containment | Goal or radius inputs change |
| Camera | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_camera_test.gd -TimeoutSeconds 90` | Early/late close distance, overview, pose retention, and footprint clearance pass | Camera or prepared bounds change |
| UI | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_ui_contract_test.gd -TimeoutSeconds 60` | Menu/card geometry, focus, readability, and scrollbar pass | Scene/theme/UI contract changes |
| Startup | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_app_flow_test.gd -TimeoutSeconds 90` | Front-end navigation and game startup pass | App flow or scenes change |
| Catalog | `& .\scripts\invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_catalog_smoke_test.gd -TimeoutSeconds 120` | Ten prepared courses load and instantiate | Artifact/catalog/build inputs change |
| Hygiene | `git diff --check` | No whitespace errors | Any task file changes |

Rendered captures use the pinned normal renderer and
`tests/capture_cannon_golf_frame.gd`; they are inspection evidence, not a
replacement for the focused contracts. Keep only the final small images while
the plan is active and remove their temporary Godot log immediately after the
capture process.

## Predetermined Contingencies and Change Control

- If the two-line title still clips at `356 px`, reduce only `MenuTitle` from
  `60 px` to `58 px`; do not widen the panel or add a title owner.
- If a left-only focus accent is not distinguishable in the normal row, raise
  its opacity to full blue; do not restore an expanded all-side outline.
- If the `2.0 m` sphere cannot clear an existing plate opening, calculate the
  minimum whole segment count that gives `4.5 m` chord clearance; do not change
  goal locations or radii.
- If a close camera footprint point lies outside prepared terrain bounds,
  ignore only that unavailable point and retain all in-bounds samples; never
  synthesize a terrain height outside the heightfield.
- If twelve zoom steps cannot reach `14 m` because clearance raises the camera,
  measure acceptance as the desired orbit distance plus the minimal vertical
  lift. Do not lower the `2.0 m` terrain clearance.
- Any need to change course layouts, terrain generation, ballistics ranges,
  camera modes, or validation scope is a contract change and requires user
  approval before implementation continues.

## Progress and Next Steps

- [x] Current specifications, decisions, scenes, theme, ball/goal owners,
  camera math, artifact identity, tests, and fresh rendered captures inspected.
- [x] Material UX, physics-scale, artifact, camera, and validation choices
  closed in this contract.
- [x] Tasks 1.1, 2.1, 2.2, 3.1, and 3.2 are implemented. The deterministic bake
  rebuilt all ten courses in `112-765 ms` each; ball, goal, UI, startup, and
  catalog gates passed with zero persistent-log growth.
- [ ] Blocked at task 5.2 after five close-camera correction attempts. The
  `14 m` camera endpoint and nine-point footprint are terrain-safe, but fresh
  course 1 and course 10 captures are fully occluded by an intervening cliff.
  Camera-only sightline lift, matched-focus validation, a safety margin, and a
  shared focus/camera lift did not produce a stable sightline contract; the last
  diagnostic failure was `rising_bend oblique panned`, first segment at
  `y=47.3333` against terrain `65.7778`. Per the user-approved repetition limit,
  do not attempt a sixth correction without renewed direction.

## Completion and Stop Conditions

Mark this plan `done` only when tasks 1.1-5.3 pass, the ten artifacts carry the
new construction identity, all named final gates exit zero, and the final
captures meet the locked visual acceptance. Stop and leave the plan `active`
with the exact failing task and evidence when any stop condition is reached.
