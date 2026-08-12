---
type: plan
status: done
created: 2026-08-12
scope: Paint Mountain-derived application flow, player conveniences, and faceted mountain presentation for the two-course Cannon Golf prototype
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-12-two-course-vertical-slice.md
---

# Integrated Cannon Golf Game Flow - Execution Contract

Deliver a Windows-playable two-course Cannon Golf prototype that starts at a
proper main menu, provides course selection, settings, pause/navigation, fast
retry, and documented shortcuts, then presents both courses as connected
faceted mountain terrain under the same ground, panorama sky, light, and
low-poly environmental language retained from Paint Mountain. The existing
Cannon Golf launch, settlement, impact-history, and direct-solution rules remain
authoritative.

## Purpose

- Objective: turn the isolated playable scene into a coherent small game flow
  without restoring Paint Mountain's paint, coverage, prediction, timer, or
  finite-shot semantics.
- Deliverable: one Cannon Golf-owned app shell, adapted menu/course/settings/
  pause screens, connected faceted terrain with a shallow elevated goal basin,
  focused automated coverage, rendered flow evidence, and a refreshed Windows
  build.
- Completion state: the built app opens at the main menu and supports
  main menu -> course select -> gameplay -> pause/settings -> course select or
  main menu, with both authored solution witnesses still clearing their course.

## Scope and Boundaries

In scope:

- Main menu, two-course selection, settings, pause, course result, return
  navigation, keyboard focus, and short transitions.
- A quick next-shot retry that removes only the current unsuccessful ball while
  preserving angle, power, planning view, pan, zoom, and impact history; the
  existing full course reset remains separately available.
- Keyboard shortcuts for fire, retry, full reset, pause, view switching, setup
  adjustment, course exploration, and zoom, with an in-game visible legend.
- Existing audio, display, quality, reduced-motion, and language settings where
  they have a real runtime effect. Camera shake and exact trajectory-preview
  settings are excluded from the visible Cannon Golf settings surface.
- One connected faceted terrain mesh per course, generated deterministically
  from the existing authored shelf data, with collision, flat launch shelves,
  lateral/vertical mountain variation, and a shallow elevated goal basin.
- Paint Mountain's existing panorama sky texture, light palette, open-ground
  material, and low-poly nature dressing as retained environmental primitives.

Out of scope:

- New courses, multi-goal stages, player-placeable devices, procedural course
  generation, a level editor, mobile layouts, save migration, public-title
  approval, or deletion of retained Paint Mountain source-history files.
- Paint, coverage, exact landing prediction, score, stars, timer, lives, finite
  shots, locked-course progression, or best-score records.
- Pixel-identical reuse of Paint Mountain screens. Their hierarchy and proven
  controls are adapted to the two-course Cannon Golf domain.

Constraints and invariants:

- `CannonGolfApp` owns screen navigation. `CannonGolfGame` owns course setup,
  launch lifecycle, goal settlement, retry state, and planning cameras.
- Screens exchange a zero-based course index and navigation intent only; they
  must not call legacy `StageCatalog`, coverage results, or paint owners.
- A quick retry is available only for an active unsuccessful shot. It never
  removes confirmed goal balls. A full course reset remains explicit and clears
  course-local attempts and marks.
- Main menu and stage select must show the real connected course world, not a
  fake screenshot or an inherited generated Paint Mountain stage.
- A course remains solvable by its recorded angle/power witness after terrain
  conversion. The witness may be retuned in its course resource only when the
  physical replay proves the new deterministic value.
- The connected terrain mesh must use triangle collision and the existing
  `impact_mark_surface` identity, and must expose one terrain body to callers.
- All routine buttons remain at least 40 px high, focus is visible, Escape
  returns predictably, Korean text does not clip at 1280x720, and reduced-motion
  skips decorative fades.
- Add no external dependency.

Destructive or irreversible actions:

- None. The change adapts or adds Cannon Golf-owned owners and leaves retained
  Paint Mountain source-history paths in place.

Exact actions requiring owner or user approval:

- Deleting legacy runtime files, adding a dependency, selecting a public title,
  or changing the two-course product rules. None is required by this contract.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Application entry | `project.godot` directly starts `scenes/cannon_golf/cannon_golf.tscn`; no app autoloads are active | Direct config and runtime-owner inspection | Add a thin Cannon Golf app root as main scene; instantiate gameplay only after a course is selected | 1.1, 1.3 |
| Reusable screen language | Retained `main_menu.tscn`, `stage_select.tscn`, `settings.tscn`, and `pause_overlay.tscn` provide proven layout, targets, focus, and settings wiring but their scripts depend on legacy catalogs/state | Direct scene/script inspection | Reuse theme and component grammar; add Cannon Golf-specific screen owners rather than branching legacy Paint Mountain domain scripts | 1.1, 1.2, 1.3 |
| Settings and persistence | Retained settings implement audio, display, quality, language, and legacy camera/prediction options; current main path removed autoloads | Direct `settings_screen.gd`, `game_state.gd`, and `save_system.gd` inspection | Add a small Cannon Golf settings store and reuse only settings with real effects; use a distinct `user://cannon_golf_settings.json` file | 1.2 |
| Pause and navigation | Current Cannon Golf game has no pause/settings/menu shell; legacy overlay has correct action shape | Direct runtime and scene inspection | Gameplay exposes pause and navigation signals; app root owns scene removal/return and settings overlay | 1.3, 2.1 |
| Retry semantics | Failed launches currently auto-remove the ball; `R` resets the whole course | `CannonGolfGame._fail_launch`, `_finish_failed_launch`, and user direction | `R` becomes quick attempt retry/cancel; `Shift+R` and the explicit HUD button perform full course reset | 2.1, 2.2 |
| Terrain | `course_builder.gd` creates four disconnected/overlapping box bodies from authored shelf arrays | Builder and course-resource inspection | Convert shelves into a deterministic faceted route with overlapping mountain skirts, preserve one physical terrain owner, and carve a shallow goal basin around the authored elevated goal | 3.1, 3.2 |
| Sky and ground | Retained gameplay uses `skybox-day.png`, a panorama environment, warm sun, and `open_ground.gdshader` on an apron | `gameplay.tscn` and `open_play_environment.tscn` inspection | Use the same sky texture, environment/light values, and ground shader/texture in the Cannon Golf main and preview worlds | 3.2, 3.3 |
| Course solvability | Direct witnesses are `39/52` and `42/63` and pass real rigid-body replay on current block terrain | Course resources and `cannon_golf_solution_test.gd` | Real replay remains the release condition; retune only the witness values if the connected mesh changes contact geometry | 3.2, 4.1 |
| Validation and packaging | Godot 4.7.1, focused tests, source verify, capture script, Windows export preset, and built executable exist | Toolchain audit and direct command inspection | Extend the focused suite and capture tool; use the existing source verify, release export, and built-app smoke at final gate | 4.1, 4.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership,
  safety, and validation decision in this slice is closed.
- Godot 4.7.1 and all required retained assets are available. The exact source,
  focused-test, capture, export, and smoke commands are known.
- Remaining unknowns are local mesh tessellation and tuning mechanics contained
  by the witness-replay contract; they cannot expand scope or choose new UX.

## Tasks

### Phase 1: Establish the Cannon Golf app shell

Goal: start at a real menu and make the two courses and real settings reachable
without legacy stage or coverage state.

Preconditions:

- Current main scene and existing two-course focused suite are the baseline.

Source owners: `project.godot`, `src/cannon_golf/app/`,
`scenes/cannon_golf/app/`, `resources/ui/paint_mountain_theme.tres`

- [x] **1.1** Main menu and course select form one keyboard-operable flow.
  - Change: add a Cannon Golf app root, menu, and two-course select screen using
    the retained theme and the actual course catalog; display a live course
    preview and expose Play, Course Select, Settings, Quit, Back, and Start.
  - Accept: the app-flow test starts at main menu, reaches course select,
    selects each course, enters gameplay with the matching course index, and
    returns without calling `StageCatalog` or a legacy app owner.
  - Guard: visible screen copy contains no paint, coverage, stars, shot stock,
    locked-stage, mountain-number, or exact-prediction semantics.
- [x] **1.2** Settings persist only truthful Cannon Golf options.
  - Change: add a Cannon Golf settings owner and screen for master/music/SFX,
    reduced motion, fullscreen, resolution, quality, and language; apply values
    at startup and store them in the Cannon Golf settings file.
  - Accept: the settings test changes, saves, reloads, and restores every visible
    option and confirms that unsupported legacy controls are absent.
- [x] **1.3** Transitions preserve a predictable return target.
  - Change: app-root navigation owns main menu, course select, settings overlay,
    and gameplay instantiation; add a short fade that is bypassed when reduced
    motion is enabled and restore focus to the initiating screen on return.
  - Accept: the app-flow test traverses menu -> settings -> menu and gameplay ->
    settings -> gameplay with correct visibility, pause state, and focus target.

Batch gate:

- Capture and inspect main menu, course select, and settings at 1280x720; no
  clipping, overlap, fake actions, hidden primary action, or invisible focus is
  allowed.

### Phase 2: Add pause, navigation, and rapid control recovery

Goal: make the play session easy to leave, resume, retry, and understand using
buttons or shortcuts.

Preconditions:

- Phase 1 app navigation passes.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`, `src/cannon_golf/app/`

- [x] **2.1** Pause and return navigation work from every gameplay state.
  - Change: Escape opens/closes a pause overlay with Resume, Retry Attempt,
    Reset Course, Settings, Course Select, and Main Menu; app navigation releases
    tree pause before removing gameplay.
  - Accept: the session test pauses from planning and flight, resumes to the
    prior state, opens and closes settings, and returns to both outer screens
    without a stuck paused tree or orphan ball.
- [x] **2.2** Retry and reset have distinct, fast behavior.
  - Change: `R` cancels/retries the current attempt while preserving launch
    setup, planning pose, and impact history; `Shift+R` and Reset Course rebuild
    the course; Fire remains `Space` and supports immediate relaunch after
    failure recovery.
  - Accept: the session test proves rapid retry state preservation, full reset
    clearing, confirmed-ball protection, and repeated admission with no retry
    limit.
- [x] **2.3** The live HUD teaches the actual controls without obstructing play.
  - Change: add a restrained edge legend for Fire, Retry, Reset, Pause, views,
    setup, exploration, and zoom; hide or abbreviate it only where the same
    action remains discoverable.
  - Accept: the UI contract finds all real actions, at least 40 px routine
    targets, visible focus, and no unsupported wording; planning and side
    captures retain a clear view of the cannon, terrain, goal, and ball route.

Batch gate:

- Focused app/session/UI tests pass once after Tasks 2.1-2.3, followed by one
  rendered planning capture and one pause capture at 1280x720.

### Phase 3: Convert the courses to the retained mountain presentation

Goal: render and collide with connected low-poly mountain terrain while keeping
the two authored puzzles deterministic and readable.

Preconditions:

- Phase 2 behavior is stable and the original witness values are recorded.

Source owners: `src/cannon_golf/course_data.gd`,
`src/cannon_golf/course_builder.gd`, `src/cannon_golf/course_terrain_factory.gd`,
`resources/cannon_golf/courses/`, `scenes/cannon_golf/cannon_golf.tscn`

- [x] **3.1** Course data builds one deterministic connected faceted surface.
  - Change: tessellate each overlapping authored shelf into one combined
    triangular mesh with alternating diagonals, low-poly facet tones, mountain
    skirts, a flat launch shelf, and one collision body; retain editor-readable
    course data.
  - Accept: the terrain test finds one mesh and one collision owner, triangle
    collision, retained flat shelf levels and goal recess, upward top normals,
    facet variation, and one `impact_mark_surface` body.
- [x] **3.2** Each elevated goal sits in a shallow physical basin.
  - Change: lower the terrain samples immediately inside the authored goal rim,
    blend them back to the surrounding high shelf, and align the settlement
    floor/rim so entry, bounce-out, and safe rest remain physically legible.
  - Accept: goal containment and physics tests pass, and both real direct
    solution witnesses clear; if a witness must change, record the new value in
    its course resource and keep the old/new evidence in this task checkpoint.
- [x] **3.3** Ground, sky, light, and dressing match the retained environment.
  - Change: use the same panorama sky asset, sun/environment values, apron
    ground shader/texture, and low-poly rock/tree assets for gameplay and menu
    preview; keep decoration outside the certified route and goal footprint.
  - Accept: world-build tests find the shared sky and ground resources, and
    rendered menu/planning/side captures show connected terrain, sky, ground,
    and an unobstructed elevated goal.

Batch gate:

- Run the full focused Cannon Golf suite once after Tasks 3.1-3.3. Then capture
  both courses in oblique and side views; fix any route, goal, collision,
  clipping, or readability blocker before packaging.

### Phase 4: Package and prove the integrated game

Goal: verify the source and exported app along the actual player path.

Preconditions:

- Phases 1-3 and their rendered gates pass.

Source owners: `scripts/test-cannon-golf.ps1`, `scripts/verify.ps1`,
`tests/capture_cannon_golf_frame.gd`, `README.md`, this contract

- [x] **4.1** Source, focused behavior, and documented controls agree.
  - Change: extend the focused runner and capture states; update README startup,
    screen flow, controls, and retained-environment description.
  - Accept: focused tests, source verification, `git diff --check`, and a stale
    terminology scan of new Cannon Golf-owned paths all pass.
- [x] **4.2** The release export starts at the menu and the core path runs.
  - Change: export `Windows Desktop` to the existing prototype path and run a
    built-app smoke that reaches startup without engine or script errors.
  - Accept: export exits zero; the built executable starts at the main menu,
    exposes the two-course flow, and terminates cleanly after the bounded smoke.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit` | A scene, script signature, or project config changes | A relevant parse input changes |
| Phase gate | `powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'` | A phase's task-level checks pass | A focused gameplay/UI/terrain input changes |
| UI gate | `& 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe' --path . --script res://tests/capture_cannon_golf_frame.gd -- --output=res://.godot/capture-temp/<state>.png --state=<state> --background` | A named screen or visible world phase is complete | A visible UI, camera, terrain, environment, or copy input changes |
| Final gate | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -GodotPath 'D:/tools/Godot/4.7.1-stable/Godot_v4.7.1-stable_win64_console.exe'`; focused suite; Windows release export; built-app smoke; `git diff --check` | All phases pass | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Run each named phase gate once after its owned tasks pass.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- Record known non-blocking warnings once instead of rediscovering them.
- The legacy Paint Mountain suite remains outside this Cannon Golf release
  contract unless a retained shared primitive is intentionally changed.

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
| The connected mesh breaks a recorded solution | First preserve the required flat launch/goal zones and tune only local surface samples; if replay still fails, retune that course's angle/power witness and record the evidence | Do not restore disconnected box terrain or weaken safe-settlement rules |
| A retained settings option has no observable Cannon Golf effect | Remove it from the Cannon Golf settings UI and store rather than present a fake control | Do not implement a new gameplay feature solely to justify a legacy toggle |
| The panorama or ground texture fails to import or render | Use the existing imported resource path and current renderer-compatible material; report the exact asset/import failure if unavailable | Do not add or download replacement dependencies or assets |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: none; the integrated two-course game flow is ready for playtesting.
- Last completed gate: final source, focused-suite, rendered UI, Windows export,
  and built-app smoke gate on 2026-08-12.
- Evidence: all 11 focused Cannon Golf tests passed on Godot 4.7.1; the direct
  solution replay cleared both courses at the existing witnesses; 1280x720
  menu, course-select, settings, planning, side, pause, and clear captures were
  inspected; `scripts/verify.ps1`, Windows release export, and the bounded
  exported-app startup smoke passed without script or runtime errors.
- Update rule: after a checkpoint passes, record its concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every guard, phase gate, and final gate named by this contract passes.
- The Level 3 UIUX evidence report records menu, course select, settings,
  planning, side, pause, and clear states at 1280x720, keyboard/focus checks,
  Korean text fit, and remaining warnings.
- No placeholder or unresolved material decision remains.
- Durable new behavior and run/verify knowledge are reflected in the owning
  specification, decision record, README, or repo-local policy when necessary.
- Frontmatter status is changed to `done` only after implementation completes.

Replan when:

- A material discovery invalidates the locked app ownership, retry semantics,
  terrain representation, settings boundary, or validation contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
