---
type: plan
status: done
created: 2026-08-13
scope: Large launch-envelope-constrained mountain courses, three-parameter free aim, terrain-owned concave goals, retry persistence, and a minimal interface for the two-course Cannon Golf prototype
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-12-integrated-game-flow.md
---

# Large Free-Aim Course - Execution Contract

Replace the current small, fixed-horizontal-aim presentation with two large
Paint Mountain-generated courses that fit entirely inside the cannon's real
three-parameter launch envelope. The playable screen keeps only compact aim,
view, retry, pause, and Fire controls. Each goal becomes a terrain-owned
concave basin whose interior never rises into a central ejecting bulge, and a
quick retry immediately relaunches while preserving the complete setup and
impact history.

## Purpose

- Objective: make the prototype read as a large 3D mountain artillery-golf
  puzzle rather than a small HUD-heavy diorama.
- Deliverable: updated product records, launch parameter contract, generated
  terrain and range admission, goal shape, cameras, retry behavior, minimal
  gameplay and shell UI, focused tests, rendered evidence, documentation, and
  refreshed Windows build.
- Completion state: both courses start at visible parameters `50 / 50 / 50`,
  admit horizontal and vertical aiming plus power, miss at the defaults, clear
  through recorded real-physics witnesses, preserve setup and marks across a
  live quick retry, and show the complete large course without persistent UI
  obstruction.

## Scope and Boundaries

In scope:

- The existing two direct one-goal courses only.
- A player-facing horizontal aim parameter, vertical elevation angle, and power
  parameter, with all three defaulting to `50` on every course.
- Paint Mountain's retained route-graph mountain synthesis, topology, and
  geometry pipeline at its original horizontal scale.
- Internal ballistic-envelope admission for every playable terrain-top vertex
  and visible support-shell boundary; the envelope is a generation/validation
  rule, not a visible trajectory or range overlay.
- A concave terrain basin at each goal, safe settlement, quick retry, retained
  first-contact marks, stable planning cameras, live course previews, and UI
  simplification across gameplay, main menu, and course selection.
- Existing settings, pause navigation, course selection, main menu, result
  transition, Korean/English behavior, and Windows packaging where they remain
  essential.

Out of scope:

- New courses, multi-goal progress, devices, placement UI, a level editor, save
  migration, title approval, mobile layouts, or legacy Paint Mountain cleanup.
- A trajectory line, predicted landing point, visible half-sphere/dome, range
  meter, tutorial paragraph, shortcut legend, course prose card, score, timer,
  lives, or finite shots.
- Changing baseline rebound, impact-history capacity, the sky/ground art
  direction, or the terrain representation to caves, bridges, overhangs, or
  disconnected islands.

Constraints and invariants:

- `shot axis` is the generated world yaw from the cannon toward the goal. It is
  hidden implementation data, not the player's horizontal parameter.
- `horizontal aim` is a player-facing `0..100` parameter. `50` means zero
  offset from the shot axis; the endpoints map linearly to `-80..+80` degrees.
- `vertical angle` remains a physical `10..68` degree value. `power` remains a
  `10..100` percent value. Both visibly start at `50`.
- The launcher converts those three parameters into one deterministic origin
  and velocity through a pure Cannon Golf ballistics owner. The scene launcher
  owns visuals and current values, not duplicate physics math.
- `quick retry` means remove only the active unconfirmed ball and immediately
  relaunch with exactly the same horizontal aim, vertical angle, and power. It
  preserves every retained impact mark, planning view, pan, zoom, future placed
  device, and confirmed goal. It never calls course load or reset.
- `course reset` is a separate explicit pause-menu action. It rebuilds the
  current course and clears course-local balls and impact history. `Shift+R`
  may remain as an unadvertised keyboard equivalent.
- A goal interior may be flat or concave but must not be convex toward its
  center. This implementation locks a concave radial basin: the center is the
  lowest point and height increases monotonically toward the rim.
- The generated terrain owns all goal collision. `CannonGolfSettlementGoal`
  owns containment/settlement policy and non-colliding markers only.
- The player-visible default `50 / 50 / 50` remains a miss. It is not copied
  from or made equal to a certified solution witness.
- The range rule applies to physical terrain, not just the goal. Every active
  terrain-top vertex and visible shell boundary must be in front of the cannon,
  within the legal `-80..+80` yaw fan, and within the height interval reachable
  at its horizontal distance by a legal elevation/power pair.
- Use no new external dependency.

Locked world and physics values:

- Terrain horizontal scale: `1.00`, producing the retained `210 x 120` metre
  local bounds instead of the current `0.42` scale (`88.2 x 50.4` metres).
- Terrain vertical scale: `0.45`; sampled maxima are approximately `26` metres
  for the two current deterministic courses.
- Cannon route standoff: `75` metres instead of the current `8` metres.
- Goal radius: `10` metres; goal depth: `3.5` metres; external blend width:
  `5` metres.
- Launcher speed range: `14..60` metres/second instead of `14..38`; launch
  damping, gravity, rebound, and the current `13` second flight horizon remain
  unchanged.
- Ballistic admission margins: at least `8` metres of horizontal range, `8`
  degrees of yaw, and `8` metres of reachable-height interval for every tested
  terrain point.
- World apron top/bottom radii: `160 / 166` metres. Gameplay and preview camera
  far distance and sun shadow distance: at least `520` metres.
- Initial solution witnesses to implement and replay, ordered as horizontal
  aim / vertical angle / power: `first_ridge = 50 / 46 / 72` and
  `rising_bend = 50 / 42 / 72`.

Destructive or irreversible actions:

- None. This work edits Cannon Golf-owned paths, product records, tests, and the
  existing prototype build. It does not delete retained legacy source history.

Exact actions requiring owner or user approval:

- Adding a dependency, deleting legacy Paint Mountain files, changing the
  course count, adding a visible range/trajectory aid, or changing the locked
  values above. None is required by this contract.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Horizontal aim | `course_terrain_factory.gd` computes `shot_yaw_degrees`; `course_builder.gd` overwrites the runtime course; `cannon_golf_launcher.gd` can rotate yaw but `set_setup` and HUD expose only elevation/power | Direct source and focused ballistics/session tests | Separate hidden shot-axis yaw from player horizontal aim; expose the latter as `0..100`, with `50` centered and `-80..+80` degree mapping | 1.1, 2.1, 4.1 |
| Default setup | Resources currently use `24/30` and `22/32`; D-022 requires a non-winning default | Course resources, D-022, solution replay | Every course visibly starts `50 / 50 / 50`; retain separate three-value solution metadata and prove the default misses | 1.1, 2.1, 3.2 |
| Terrain size and distance | Both resources use horizontal scale `0.42`, vertical scale about `0.16`; the factory uses `8` metre cannon standoff; captures show a compact diorama and roughly 40 metre cannon-goal route | Course resources, factory constants, 1280x720 planning/side captures | Use horizontal `1.00`, vertical `0.45`, and `75` metre standoff; resize world/cameras around generated content bounds | 2.2, 2.3 |
| Whole-terrain reachability | Cannon Golf currently validates only solution replay; it has no terrain-wide range owner. The retained legacy `ProjectileRangeConstraint` is coupled to Paint Mountain `StageData` and projectile resources | Direct source comparison and range probe | Add a Cannon Golf pure ballistics/envelope owner; fail course construction if any playable terrain or visible shell-boundary point violates the locked envelope or margins | 2.1, 2.2 |
| Range feasibility | At the locked scale/standoff and `60` m/s maximum, current deterministic mountains place goals about `146` metres away, their farthest top vertices about `181` metres away, and the damped maximum ground range about `233` metres | Bounded Godot probe using retained generation output and the current 60 Hz damping/gravity recurrence | Keep the locked values; observed minimum margins are about `10.5` metres range, `10.4` degrees yaw, and `20.9` metres height, all above the `8`-unit guard | 2.2 |
| Goal shape | `_depress_goal_samples` forces a flat center at `0.56 * radius` and blends outward; the goal node owns no collision | Factory and terrain/goal tests | Replace the flat-floor assumption with a terrain-only parabolic basin whose center is lowest, rim is highest, and blend only lowers source samples | 3.1 |
| Goal containment | `SettlementGoal` uses fixed vertical bands relative to the center floor; a deeper bowl would make its current `3.2` metre upper band incorrect | `settlement_goal.gd` | Derive vertical containment from configured rim height plus ball clearance; keep radial containment and speed/duration settlement policy | 3.1 |
| Goal feasibility | A bounded prototype using the locked world values and a `3.5` metre parabolic basin produced a failed `50/50/50` default and one safe real-physics settlement per course | Temporary probe, removed after evidence collection | Seed solution metadata with `50/46/72` and `50/42/72`; the production replay test is authoritative | 3.2 |
| Retry persistence | `retry_attempt` currently frees the active ball, leaves impact history and launcher values intact, returns to planning, then immediately calls `fire`; the current test checks only elevation/power and camera context | `cannon_golf_game.gd`, session test | Preserve that immediate-relaunch behavior, add horizontal aim, and prove marks and the entire planning/setup snapshot survive a retry during flight | 4.1 |
| HUD clutter | Current gameplay has course/brief/progress, course navigation, feedback, view panel, 602-pixel setup panel, shortcut grid, three quick actions, Fire, pause overlay, and result prose. Captures show persistent panels across most screen edges | HUD scene/script and 1280x720 captures | Keep a compact three-control aim panel, Fire, four icon actions (overview, side, retry, pause), concise pause/result overlays, and remove the rest | 5.1 |
| Shell clutter | Main menu and course selection retain eyebrow/tagline/summary, selection hints, preview caption/brief/facts, and other explanatory copy | App scenes/scripts and menu capture | Preserve navigation and live previews; remove filler copy and duplicated facts, leaving title, course names, settings/navigation, preview, and primary actions | 5.2 |
| Camera scaling | Camera rig uses authored offsets and fixed pan limits; gameplay/preview far clip is `260`; apron is `48/52` metres | Camera rig, gameplay scene, preview owner | Frame generated content bounds through `TerrainCameraFramer`, derive pan distance from bounds, enlarge apron/far/shadows, and keep high-oblique/side/follow state stability | 2.3 |
| Product-record conflict | D-017 fixes horizontal aim, D-022 assumes two controls, and current design rules permit more persistent status than the new direction | Active PRD, design rules, decisions, and open questions | Record the new three-parameter/default/retry/range/UI rules before code; mark D-017 superseded without rewriting history | 1.1 |
| Validation and packaging | Godot 4.7.1, focused runner, capture script, verify script, Windows export preset, and built executable exist and were used by the completed prior plan | Direct command/path inspection and prior plan evidence | Extend focused coverage, collect rendered states at supported desktop sizes, then run verify, release export, and bounded built-app smoke once | 6.1, 6.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership,
  safety, and validation decision is closed.
- Godot `4.7.1`, the focused runner, capture route, verification script,
  Windows export preset, and build path are available. The current capture
  command and proposed range/goal values were exercised against the project.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Align the product contract

Goal: remove conflicts that would otherwise make code and active specifications
describe different controls, retry semantics, goal geometry, range, or UI.

Preconditions:

- This contract is the active progress source.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`,
`project-specs/cannon-golf/OPEN_QUESTIONS.md`

- [x] **1.1** Active product records state the locked three-parameter, world,
  goal, retry, and minimal-interface behavior.
  - Change: add accepted decisions that supersede D-017 and refine D-021/D-022;
    update PRD requirements/acceptance, the resolved Q-01 entry, and design
    rules. Preserve older decisions as history instead of deleting them.
  - Accept: a targeted terminology scan finds no active claim that horizontal
    aim is fixed, that a goal floor must be flat, that defaults differ by
    course, or that a shortcut/status panel must persist in normal play.
  - Guard: device and eleven-stage future requirements remain unchanged.

### Phase 2: Establish one launch model and generate the large reachable world

Goal: put the complete original-scale mountain inside a measurable real launch
envelope and frame it consistently in gameplay and previews.

Preconditions:

- Task 1.1 is accepted.

Source owners: `src/cannon_golf/cannon_golf_ballistics.gd` (new),
`src/cannon_golf/course_data.gd`, `src/cannon_golf/cannon_golf_launcher.gd`,
`src/cannon_golf/course_terrain_factory.gd`,
`src/cannon_golf/course_builder.gd`, `src/cannon_golf/course_camera_rig.gd`,
`src/cannon_golf/app/cannon_golf_preview_world.gd`,
`scenes/cannon_golf/cannon_golf.tscn`, `resources/cannon_golf/courses/`

- [x] **2.1** One pure Cannon Golf ballistics owner maps the three parameters to
  launch origin, direction, speed, and reachable height intervals.
  - Change: move duplicated constants/math out of `CannonGolfLauncher`; expose
    named horizontal/vertical/power operations, centered-horizontal mapping,
    the locked speed range, and deterministic damped-envelope queries. Keep
    launcher scene visuals synchronized with that result.
  - Accept: `cannon_golf_ballistics_test.gd` proves `50` horizontal equals the
    shot axis, endpoints equal `-80/+80`, vertical/power clamping is stable,
    repeated input gives identical origin/velocity, and higher power increases
    speed.
  - Guard: no exact impact point or trajectory is published to gameplay UI.
- [x] **2.2** Both generated mountains use the locked scale/standoff and pass a
  fail-closed whole-terrain launch-envelope gate.
  - Change: update course data/resource limits and values; place the cannon from
    the route tangent at `75` metres; compute content/play bounds; test active
    top vertices and support-shell boundary points through the pure envelope;
    reject a build that fails the front/yaw/range/height or `8`-unit margins.
  - Accept: `cannon_golf_range_test.gd` proves both course bounds are
    `210 x 120`, cannon-goal distance is at least `140` metres, farthest terrain
    distance is at least `175` metres, and every tested point passes all four
    admission rules and margins.
  - Guard: the factory still calls `RouteGraphResolver`,
    `RouteGraphMountainSynthesizer`, `TerrainTopTopology`, and
    `TerrainGeometryFactory`; it does not scale below `1.00`, clip geometry, or
    replace the source mountain with authored shelves.
- [x] **2.3** Gameplay and preview worlds frame the large course without manual
  per-course camera guesswork.
  - Change: store generated content bounds on the runtime course; use
    `TerrainCameraFramer` to preserve high-oblique and true side directions while
    fitting those bounds; derive pan scale/limits from course size; enlarge
    apron, camera far clip, and shadow distance to the locked values in both
    world owners.
  - Accept: camera tests prove cannon, goal, and terrain-bound corners fit at
    `1280x720` in both views before and after allowed pan/zoom; preview and
    gameplay consume the same generated course and framing contract.

Batch gate:

- Run only `cannon_golf_ballistics_test.gd`, `cannon_golf_range_test.gd`,
  `cannon_golf_terrain_test.gd`, `cannon_golf_course_build_test.gd`, and the
  affected camera test once after Tasks 2.1-2.3 pass.

### Phase 3: Build a concave, terrain-owned settlement goal

Goal: make the hole retain a safely landed ball through physical terrain shape
without requiring a flat floor or separate cup collider.

Preconditions:

- Phase 2 batch gate passes.

Source owners: `src/cannon_golf/course_terrain_factory.gd`,
`src/cannon_golf/settlement_goal.gd`, `src/cannon_golf/course_builder.gd`,
`resources/cannon_golf/courses/`, `tests/cannon_golf_goal_test.gd`,
`tests/cannon_golf_terrain_test.gd`, `tests/cannon_golf_solution_test.gd`

- [x] **3.1** The goal is a monotonic concave basin in the generated topology.
  - Change: replace `_depress_goal_samples` with a basin carver. Let `rim_y` be
    the minimum original sample height within the 10 metre goal radius, set
    `height(r) = rim_y - 3.5 + 3.5 * (r / 10)^2` inside the goal, then smooth
    from `rim_y` to the untouched source over 5 metres. Because `rim_y` is the
    local minimum, this operation only lowers source samples. Configure goal
    containment from the resulting center/rim heights and ball clearance.
  - Accept: topology tests prove the center is lowest, sampled height never
    decreases while moving from center to rim beyond one topology tolerance,
    every internal sample is at or below the rim, render/collision share that
    topology, and the goal contains no `StaticBody3D`.
  - Guard: a low-speed ball released at center and several off-center basin
    positions remains contained until settlement; a fast ball that exits still
    fails and does not confirm.
- [x] **3.2** Defaults miss and the locked solution witnesses clear through the
  real rigid-body simulation.
  - Change: add horizontal solution metadata, set all default fields to `50`,
    and set the two locked witnesses in the course resources.
  - Accept: `cannon_golf_solution_test.gd` replays `50/50/50` as a miss and the
    exact `50/46/72` and `50/42/72` witnesses as safe settlements within the
    existing timeout and settlement rules.

Batch gate:

- Run the terrain, goal, physics, course, and solution tests once after Tasks
  3.1-3.2. Do not run the full suite yet.

### Phase 4: Preserve the complete attempt state across quick retry

Goal: make free aim and retained spatial evidence survive retry during a live
shot while keeping full reset distinct.

Preconditions:

- Phase 3 batch gate passes.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/cannon_golf_launcher.gd`,
`src/cannon_golf/impact_history.gd`, `tests/cannon_golf_session_test.gd`

- [x] **4.1** Quick retry replaces only the active ball and immediately reuses
  the exact current three-parameter setup.
  - Change: extend game/HUD setup signals and keyboard adjustment to horizontal
    aim (`Q/E`), vertical angle (`W/S`), and power (`A/D`). Keep `R` wired to an
    immediate retry, but isolate active-ball cleanup from course reset and do
    not clear marks or planning context.
  - Accept: the session test snapshots horizontal/vertical/power, view, pan,
    zoom, and five known mark identities; after a retry during flight it finds a
    different active ball launched with the same origin/velocity and an
    identical snapshot/impact history.
  - Guard: confirmed balls/goals reject retry; full reset still clears marks and
    returns all three defaults to `50`.

### Phase 5: Reduce the interface to current decisions only

Goal: let the mountain, cannon, goal, ball, and impact marks dominate every
normal gameplay frame while retaining essential mouse and keyboard access.

Preconditions:

- Task 4.1 passes.

Source owners: `scenes/cannon_golf/cannon_golf_hud.tscn`,
`src/cannon_golf/cannon_golf_hud.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`scenes/cannon_golf/app/cannon_golf_main_menu.tscn`,
`src/cannon_golf/app/cannon_golf_main_menu.gd`,
`scenes/cannon_golf/app/cannon_golf_course_select.tscn`,
`src/cannon_golf/app/cannon_golf_course_select.gd`,
`tests/cannon_golf_ui_contract_test.gd`,
`tests/cannon_golf_app_flow_test.gd`

- [x] **5.1** Normal gameplay shows only aim, Fire, view, retry, and pause.
  - Change: remove course panel/brief/progress, in-game previous/next course,
    feedback panel, shortcut panel, separate view panel, visible reset action,
    and duplicated labels. Build one compact edge aim panel with `좌우`, `상하`,
    and `파워` controls/values; retain one blue `발사` button and 40-pixel icon
    buttons for overview, side, retry, and pause. Give every icon a tooltip and
    accessible name. Keep full reset/settings/course select/main menu inside the
    pause overlay. Reduce the result overlay to a completion title and one next
    course/replay action.
  - Accept: UI contract inspection finds only those normal-play controls, all
    routine targets are at least 40 pixels, keyboard focus follows task order,
    Korean/English labels fit, and every icon has a non-empty accessible name.
  - Guard: the center 70% of the viewport has no persistent panel and Fire is
    the only saturated primary action.
- [x] **5.2** Main menu and course selection retain their jobs without filler.
  - Change: remove the menu eyebrow/tagline/summary and course-selection hints,
    preview caption/brief/fact list. Keep working title, Play, Course Select,
    Settings, Exit, Back, two course names, live preview, and Start.
  - Accept: app-flow tests still traverse menu -> course select -> gameplay and
    menu/pause -> settings, with no unsupported or dead action; visible-copy
    tests find no removed filler strings.
  - Guard: settings controls and pause navigation are not removed merely to
    reduce text.
- [x] **5.3** The Level 3 desktop UI gate passes on the actual rendered world.
  - Change: extend capture states only as needed for the three controls, live
    retry, concise pause/result, and simplified shell.
  - Accept: inspect both courses in planning and side views plus menu, course
    select, pause, and clear at `1280x720`, and planning at `1600x900`. The large
    terrain, cannon, goal, setup, and impact marks are readable; text and panels
    do not clip or overlap; focus remains visible; the course center is open.
  - Guard: desktop-only is an explicit project exception; no narrow-mobile
    claim is made.

Batch gate:

- Run app/session/UI tests after task checks, then collect the named captures
  once. Fix only visible blockers before continuing.

### Phase 6: Integrate, document, audit, and package

Goal: prove the whole source and exported desktop app follow the locked design.

Preconditions:

- Phases 1-5 and rendered UI gate pass.

Source owners: `scripts/test-cannon-golf.ps1`, `scripts/verify.ps1`,
`tests/capture_cannon_golf_frame.gd`, `README.md`, this contract,
`builds/windows/CannonGolfPrototype.exe`

- [x] **6.1** Focused coverage, documentation, and task-owned architecture agree.
  - Change: add the range test to the focused runner; update README controls,
    world scale, goal, retry, and minimal UI; run the repository-required
    multi-file quality audit and make only small task-scoped corrections.
  - Accept: all focused tests pass, `scripts/verify.ps1` passes, active docs and
    visible copy use the canonical terms, and `git diff --check` reports no
    whitespace errors.
  - Guard: no Cannon Golf-owned catch-all gains unrelated legacy paint,
    coverage, prediction, device, or app-shell responsibility.
- [x] **6.2** The refreshed Windows release starts and exposes the simplified
  large-course flow.
  - Change: export the existing `Windows Desktop` preset to the existing build
    path and run a bounded hidden startup smoke.
  - Accept: export exits zero; the built executable starts at the minimal main
    menu without script/runtime errors and exits cleanly after the bounded
    smoke.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit` | A scene, script signature, or resource schema changes | A relevant parse/import input changes |
| Phase 2 behavior | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; foreach ($test in @('cannon_golf_ballistics_test.gd','cannon_golf_range_test.gd','cannon_golf_terrain_test.gd','cannon_golf_course_build_test.gd')) { & $godot --headless --path . --quit-after 7200 --script "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Tasks 2.1-2.3 pass | A Phase 2 owner or fixture changes |
| Phase 3 behavior | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; foreach ($test in @('cannon_golf_terrain_test.gd','cannon_golf_goal_test.gd','cannon_golf_physics_test.gd','cannon_golf_course_test.gd','cannon_golf_solution_test.gd')) { & $godot --headless --path . --quit-after 7200 --script "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Tasks 3.1-3.2 pass | A Phase 3 owner or fixture changes |
| Phase gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'` | A phase names the full focused gate or all implementation phases have passed | A focused gameplay/UI/terrain input changes |
| UI gate | `$godot = 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'; $cases = @(@('planning',0,1280,720),@('side',0,1280,720),@('planning',1,1280,720),@('side',1,1280,720),@('menu',0,1280,720),@('course_select',0,1280,720),@('pause',0,1280,720),@('clear',0,1280,720),@('planning',0,1600,900)); foreach ($case in $cases) { $state=$case[0]; $course=$case[1]; $width=$case[2]; $height=$case[3]; & $godot --path . --script res://tests/capture_cannon_golf_frame.gd -- "--output=res://.godot/capture-temp/$state-$course-$width-x-$height.png" "--state=$state" "--course=$course" "--width=$width" "--height=$height" --background; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }` | Phase 5 behavior and copy pass | A visible UI, camera, terrain, world, or copy input changes |
| Final source gate | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; focused suite; `git diff --check` | All tasks and UI evidence pass | A source/final-gate input changes |
| Release gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'builds/windows/CannonGolfPrototype.exe'`; then use `$process = Start-Process -FilePath (Resolve-Path 'builds/windows/CannonGolfPrototype.exe') -ArgumentList '--headless','--quit-after','3' -PassThru -Wait -WindowStyle Hidden; if ($process.ExitCode -ne 0) { exit $process.ExitCode }` | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Do not rerun a passing check merely to regain confidence.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.
- The retained Paint Mountain full suite remains outside this release gate
  unless a shared retained primitive is intentionally changed beyond existing
  public behavior.

Anti-rework execution rules:

- On start or resume, read this active contract and inspect the current worktree
  only enough to confirm checkpoint inputs, then continue from the first
  unchecked task whose prerequisites are satisfied.
- Treat checked tasks and recorded passing evidence as complete unless a
  relevant input changed, the evidence is missing, or this contract schedules a
  broader final gate.
- Run each check at its declared cadence. Do not repeat a passing check merely
  to regain confidence.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Mark a task complete only after its acceptance check passes; run and record a
  guard only when that task names one.
- Update task checkboxes and the progress pointer together after a checkpoint.
  Do not mirror task state into another document.
- If reality contradicts a material decision, stop that branch and revise this
  contract before continuing. Handle implementation-local mechanics within the
  locked contract without reopening planning.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update this contract, and obtain any required approval before resuming | Do not silently choose a new product, architecture, dependency, data, UX, safety, or validation contract |
| Either deterministic mountain fails an `8`-unit range margin at the locked scale/standoff/speed | Stop and revise the contract with the failing vertex and measured margin | Do not shrink the mountain, move the cannon closer, clip terrain, relax the margin, or raise speed during implementation |
| Either locked solution witness fails after the exact basin/range implementation | Confirm the failure with the single-course solution test and record the last ball/mark evidence, then stop and revise the contract | Do not weaken settlement, enlarge the goal, change defaults, or silently search a replacement witness |
| The basin physics guard fails despite the sampled concavity check passing | Treat the physical guard as authoritative and stop with the failing start state/velocity | Do not add a hidden collider or freeze an unconfirmed ball |
| Removing a panel makes an essential mouse action unreachable | Add only a 40-pixel icon action with accessible name to the compact control edge | Do not restore a status card, shortcut legend, prose hint, or duplicate navigation |
| Large-course capture clips at a supported desktop size | Recompute camera fit or compact the persistent control edge and rerun only the affected capture | Do not reduce terrain scale or move the cannon closer |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None; all contract tasks and gates passed.
- Last completed gate: Phase 6 Windows release gate on 2026-08-13.
- Task 1.1 evidence: PRD, design rules, decisions, and resolved questions now
  define centered three-parameter aim, original-scale whole-terrain admission,
  a terrain-owned concave goal, live quick retry, and minimal normal-play UI.
  Targeted terminology and future-device/eleven-stage guards passed, followed by
  `git diff --check`.
- Task 2.1 evidence: `cannon_golf_ballistics_test.gd` passed centered and
  endpoint horizontal mapping, clamping, deterministic origin/velocity, and
  increasing power through the pure `CannonGolfBallistics` owner. No gameplay
  trajectory or range surface was added.
- Task 2.2 evidence: `cannon_golf_range_test.gd` passed both original
  `210 x 120` metre generated mountains, at least 140 metres cannon-to-goal,
  at least 175 metres far-terrain distance, and every active top/support-shell
  point with all locked range, yaw, and height margins. The retained resolver,
  synthesizer, topology, and geometry owners remain the construction path.
- Task 2.3 evidence: `cannon_golf_camera_test.gd` passed full generated-content
  bounds at `1280x720` in oblique and true side views, at minimum/maximum zoom
  and derived pan limits. Gameplay and preview retain the shared course builder,
  camera rig, `TerrainCameraFramer`, 520-metre far/shadow distances, and the
  enlarged apron contract.
- Phase 2 gate evidence: ballistics, whole-terrain range, native terrain,
  course-build, and camera tests passed. The first course-build run exposed an
  AABB maximum-face containment edge; a one-centimetre content-bounds slack
  fixed it, and only the affected course-build and camera checks were rerun.
- Task 3.1 evidence: terrain and goal checks passed the center-lowest monotonic
  basin profile, source-only lowering, shared render/collision topology, no goal
  body, rim-derived containment, three low-speed start positions per course,
  and a fast physical exit that remains unconfirmed.
- Task 3.2 evidence: the real rigid-body replay passed a miss for `50/50/50`
  on both courses and safe settlements for the exact `50/46/72` first-ridge and
  `50/42/72` rising-bend witnesses.
- Phase 3 gate evidence: terrain, goal, ordinary rebound, course metadata, and
  real solution replay all passed together for both generated courses.
- Task 4.1 evidence: the session test passed active-ball-only immediate retry,
  a different ball with identical origin/velocity, retained horizontal/vertical/
  power, view/pan/zoom, and the same five impact-mark instance identities. It
  also passed planning/confirmed retry rejection and reset-to-`50/50/50` with
  cleared marks.
- Task 5.1 evidence: UI contract inspection passed exactly three normal-play
  sliders, Fire, four named icon actions, 40-pixel targets, keyboard focus,
  Korean/English copy fit, one primary action, no retired panels/reset, and no
  persistent panel intersecting the center 70 percent of `1280x720`.
- Task 5.2 evidence: app-flow and UI-copy checks passed menu -> course select ->
  gameplay, gameplay settings/pause return, course-select/main-menu return, live
  generated preview, both course names, and all retained shell actions with the
  eyebrow/tagline/hints/preview prose/facts absent.
- Task 5.3 evidence: inspected final rendered planning and side views for both
  courses, menu, course select, pause, and clear at `1280x720`, plus planning at
  `1600x900`. The first render pass found and fixed a selected-side Fire clip;
  a HUD-local flat Fire style then passed two stability captures. Final frames
  keep the world center open, show readable cannon/goal markers and all values,
  preserve visible focus/disabled states, and contain no text/panel overlap.
  Desktop-only remains the explicit supported-layout exception; no mobile claim
  is made. App, session, and UI checks passed for the final flow.
- Task 6.1 evidence: the 13-test focused suite passed course metadata, pure
  ballistics, whole-terrain range admission, terrain/goal construction,
  generated-content camera framing, rigid-body rebound, live retry state,
  default misses, both real solution witnesses, UI/accessibility, settings, and
  app flow. `scripts/verify.ps1` passed import, parsing, and main-scene startup;
  `git diff --check` passed. The quality audit removed the obsolete HUD course
  contract, added finite shot-axis validation, and found no remaining
  task-owned responsibility, contract, or reachable-failure-path issue.
- Task 6.2 evidence: the existing `Windows Desktop` export preset refreshed
  `builds/windows/CannonGolfPrototype.exe` (127,446,776 bytes), and the built
  executable completed the bounded hidden `--headless --quit-after 3` startup
  smoke with exit code zero.
- Discovery evidence: current source/UI inspection, 1280x720 planning/side/menu
  captures, a removed ballistic range probe, and a removed real-physics concave
  basin probe. No temporary probe or generated capture is tracked by Git.
- Update rule: after a checkpoint passes, record concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every guard, phase gate, UI gate, source gate, and release gate named by this
  contract passes.
- The Level 3 UIUX evidence records both courses in high-oblique and side,
  simplified menu/course selection, pause, and clear at `1280x720`, plus one
  `1600x900` planning frame, keyboard/focus checks, Korean/English text fit,
  supported desktop exception, and remaining warnings.
- The current build contains no visible range/trajectory aid, filler gameplay
  copy, shortcut panel, course prose card, in-game course navigation, or
  persistent reset action.
- No placeholder or unresolved material decision remains.
- Durable behavior and run/verify knowledge are reflected in their owning
  product records and README.
- Frontmatter status changes to `done` only after implementation and release
  validation complete.

Replan when:

- A material discovery invalidates the locked parameter mapping, scale,
  standoff, range margins, basin profile, solution witnesses, retry semantics,
  minimal interaction set, or validation contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
