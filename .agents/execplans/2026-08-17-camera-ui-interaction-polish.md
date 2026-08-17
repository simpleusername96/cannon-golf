---
type: plan
status: done
created: 2026-08-17
scope: Cannon Golf camera preset interaction, course-selection responsiveness, settings spacing, and primary-action differentiation
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Camera and UI Interaction Polish - Execution Contract

The active Cannon Golf runtime will treat Overview and Cannon as camera presets instead of navigation locks, keep the launcher-source selector at the top, make course selection visually stable and cheaper to update, separate course Start from gameplay Fire, and improve settings option padding using the existing restrained navy-and-amber system.

## Purpose

- Objective: remove the reported interaction friction without changing course content, physics, persistence values, or navigation destinations.
- Deliverable: task-scoped runtime, UI scene/theme, specification, regression-test, and rendered-evidence changes.
- Completion state: focused behavior checks, real 1280 by 720 renders, the full Cannon Golf suite, and the diff-scoped quality audit pass.

## Scope and Boundaries

In scope:

- Overview/Cannon preset round trips and exploration input after Cannon selection.
- Course-row selection state updates, preview-camera continuity, and preview-only build cost.
- Course Start presentation, settings OptionButton inner padding, and top launcher-source placement.
- Korean/English copy, focus, disabled/loading states, and current supported desktop layouts.

Out of scope:

- Course generation, terrain shape, ballistics, goal rules, save schema, new settings, and new dependencies.
- Redesign of main menu, pause, result, or shortcut-help content.

Constraints and invariants:

- Explicit preset buttons remain available and Fire remains independent from camera state.
- Exploration input from Cannon returns to Overview and then applies the requested pan/orbit/zoom; it does not move gameplay objects or alter aim/setup.
- The launcher-source selector remains a source choice, not a target choice, and occupies the top band.
- Course Start retains its circular amber action. Fire alone becomes a distinct compact horizontal filled action with a projectile cue.
- Course preview continues to use the immutable prepared render mesh and real goal/launcher visuals; preview-only construction may omit gameplay collision bodies.
- Existing unrelated untracked files remain untouched.

Destructive or irreversible actions:

- None.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Camera appears stuck after Cannon | `cannon_golf_game.gd` rejects every exploration input while `view_mode == cannon`; explicit HUD signal wiring is valid | Source trace, commit `33a8fad`, camera tests | Any exploration input exits Cannon to Overview and applies the input; add real button round-trip coverage | 1.1, 1.2 |
| Source selector location | `cannon_golf_hud.tscn` places it in the upper-left second row | Fresh `baseline/gameplay-lv12.png` | Move it to a clear top-center slot without changing source semantics | 1.3 |
| Selection flicker | `set_course_preparation_state()` refreshes every row and selection refresh rewrites all 15 controls | `cannon_golf_course_select.gd`; focused tests | Update only old/new selected rows; preparation changes update only Start | 2.1 |
| Preview stutter/blank continuity | `show_course()` synchronously creates a full gameplay builder; `set_preview_visible(true)` does not reactivate its camera | Preview/app/builder source trace | Reassert preview camera on show and add a preview-only builder path without physics collision shapes | 2.2 |
| Start and Fire look alike | Both use the same circular amber family by current rule | Fresh course/gameplay renders and theme/scene source | Keep circular Start; make Fire alone a compact filled horizontal button with a projectile cue | 3.1, 5.1 |
| Settings options feel edge-tight | Resolution, Quality, and Language use global Button style boxes with no content margins | Fresh `baseline/settings.png`, theme/scene source | Add a settings-only option variation with balanced inner padding; do not enlarge controls | 3.2 |
| Canonical rules conflict with new direction | D-051 and active design rules require Start to reuse Fire language and Cannon to reject exploration | Specifications and completed prior plan | Record the user's superseding direction in design rules and a new decision | 3.3 |
| Validation | Godot `4.7.1.stable.official.a13da4feb`, bounded wrapper, capture harness, and focused/full tests are present | Verified local executable and three fresh baseline renders | Use targeted tests during implementation, one rendered comparison gate, then one full suite | 1.2, 2.2, 3.2, 4.1 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot 4.7.1 and the repository-owned wrapper/capture paths are available and verified; no bootstrap is required.
- External research is unnecessary because the failure paths are local, reproduced, and use no uncertain external API.
- Rejected alternatives: retain Cannon navigation lock; rebuild all row state on preparation changes; cache fifteen full gameplay builders; make both primary actions larger or icon-only.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Make camera presets navigable and keep source choice at the top

Goal: Cannon is a useful preset, not a dead end, and source selection remains visible in the top band.

Source owners: `src/cannon_golf/cannon_golf_game.gd`, `scenes/cannon_golf/cannon_golf_hud.tscn`, `tests/cannon_golf_camera_test.gd`, `tests/cannon_golf_ui_contract_test.gd`

- [x] **1.1** Route exploration input from Cannon into Overview before applying it.
  - Change: centralize the Cannon-to-Overview transition for arrow pan, drag pan, orbit, and wheel zoom while preserving follow restoration.
  - Accept: each input changes to Overview and produces its normal bounded movement; explicit Cannon/Overview selection still works in both directions.
- [x] **1.2** Cover the player-facing view controls.
  - Change: add HUD button round-trip and Cannon-to-exploration assertions to the focused camera contract.
  - Accept: the focused camera test exits zero and distinguishes explicit preset selection from exploration transition.
- [x] **1.3** Reposition the launcher-source selector within the top band.
  - Change: center the existing compact selector between level status and view actions; preserve focus, labels, and 40 px targets.
  - Accept: it fits at 1280 by 720 and wider supported sizes without collision with top actions.

### Phase 2: Stabilize course selection and reduce preview work

Goal: selecting rows does not flash the list or stall the terrain preview.

Preconditions:

- Phase 1 acceptance passes.

Source owners: `src/cannon_golf/app/cannon_golf_course_select.gd`, `src/cannon_golf/app/cannon_golf_preview_world.gd`, `src/cannon_golf/course_builder.gd`, focused app/selection/performance tests

- [x] **2.1** Make row updates local and stable.
  - Change: refresh only the previous/current rows on selection and only Start on preparation state changes; coalesce selected-row reveal requests.
  - Accept: one row remains selected/focused, retry behavior remains valid, and preparation transitions do not rewrite row copy or selection state.
- [x] **2.2** Preserve preview-camera continuity and use preview-only construction.
  - Change: reactivate an existing preview camera immediately when the screen returns; omit terrain physics collision nodes from preview builds while retaining the same prepared mesh, goals, launcher, dressing, framing, and height sampler.
  - Accept: app-flow/camera tests prove camera continuity and preview parity; a focused performance guard proves previews do not create terrain collision shapes.

### Phase 3: Differentiate primary actions and fix settings spacing

Goal: Start and Fire read as different actions, and settings option text has intentional inner breathing room.

Preconditions:

- Phase 2 acceptance passes.

Source owners: `resources/ui/paint_mountain_theme.tres`, course-select/settings/HUD scenes and scripts, canonical design rules/decisions, UI tests

- [x] **3.1** Give Course Start its own directional action language.
  - Change: replace the circular Start with a compact horizontal amber action whose copy names the selected level and direction; retain truthful preparing/failed disabled states.
  - Accept: Start is visibly distinct from circular Fire, remains at least 44 px tall, and Korean/English copy fits.
- [x] **3.2** Add settings-only OptionButton inner padding.
  - Change: apply balanced left/right content margins through a named theme variation without increasing the 44 px controls.
  - Accept: resolution, quality, and language values and arrows no longer touch their edges; keyboard focus and disabled resolution state remain visible.
- [x] **3.3** Record the superseding interaction direction.
  - Change: update the active design rules and append a decision for preset-to-exploration behavior and distinct Start/Fire semantics.
  - Accept: canonical docs no longer direct implementation back to the rejected lock or shared primary-action shape.

### Phase 4: Render and validate the integrated result

Goal: prove the changed flow with real pixels and one final integration pass.

Preconditions:

- Phases 1 through 3 pass their task checks.

Source owners: `tests/capture_cannon_golf_frame.gd`, `.agents/evidence/cannon-golf/2026-08-17-camera-ui-polish/`, task-owned source/tests/docs

- [x] **4.1** Capture and inspect affected states.
  - Change: render settings, LV12 course-ready, Overview gameplay, Cannon gameplay, and a scripted Cannon-to-Overview state at 1280 by 720; inspect native pixels.
  - Accept: no clipping/overlap/blank frame remains; Start/Fire differ clearly; option padding and top source placement are visible; camera states are correct.
- [x] **4.2** Run final integration and quality gates.
  - Change: run the complete Cannon Golf suite once, `git diff --check`, and the diff-scoped codebase quality audit; make only small task-owned corrections.
  - Accept: all checks exit zero, no Godot error or task-owned quality finding remains, and this plan becomes `done`.

### Phase 5: Correct primary-action ownership to Fire only

Goal: preserve Course Start's established circular action and make only gameplay Fire use the new distinct action shape.

Preconditions:

- The user's 2026-08-17 scope correction supersedes only the button-shape direction in Phase 3.1; all other completed work remains unchanged.

Source owners: `resources/ui/paint_mountain_theme.tres`, `scenes/cannon_golf/cannon_golf_hud.tscn`, `scenes/cannon_golf/app/cannon_golf_course_select.tscn`, localization owners, focused UI tests, canonical design rules/decisions

- [x] **5.1** Restore Start and redesign only Fire.
  - Change: restore Course Start's circular amber styling and concise localized copy; move the existing compact filled horizontal action styling to gameplay Fire and add a restrained projectile mark.
  - Accept: Start is a 112 px circular `AmberCircleButton`; Fire is a horizontal `HudFireButton` at least 44 px tall, remains the only normal-play primary action, fits Korean/English copy, and stays accessible and camera-independent.
- [x] **5.2** Render and validate the corrected pair.
  - Change: run the two focused contracts, capture course-select and gameplay at 1280 by 720, inspect native pixels, run `git diff --check`, and perform the diff-scoped quality audit.
  - Accept: both renders have no clipping or overlap, only Fire uses the new filled horizontal action, focused checks exit zero, and no task-owned quality finding remains.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/<owned-focused-test>.gd -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 120` | An owning behavior slice is complete | Relevant input changes |
| Rendered phase gate | The same wrapper with `-Rendered`, `res://tests/capture_cannon_golf_frame.gd`, named states, `--background`, and distinct outputs under the task evidence directory | Phases 1-3 pass | A visible/camera input changes |
| Final gate | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'`; `git diff --check`; diff-scoped quality audit | Rendered gate passes | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task and each named phase gate once.
- Do not rerun passing evidence unless its relevant input changes.
- Rerun a failure only after a relevant implementation change or new hypothesis.
- Keep background render processes bounded and task-owned.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A material fact contradicts this contract | Stop the affected branch and revise this contract before continuing | Do not select a new product, architecture, dependency, or UX contract during implementation |
| Preview-only build changes visible terrain/goal/launcher parity | Restore the missing visual owner while keeping physics bodies omitted | Do not cache fifteen full gameplay worlds or change prepared artifacts |
| Cannon-to-Overview transition jumps before input is applied | Snap only the preset transition, then apply the existing bounded input | Do not add a second camera controller |
| Localized Start copy clips | Shorten to `LV n 시작 →` / `START LV n →` and preserve the 44 px target | Do not enlarge it into another dominant circle or panel |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Phase 5 — the focused UI and course-selection contracts passed; real 1280 by 720 course-ready and gameplay renders passed native-pixel inspection with circular Start restored and only Fire using the compact filled horizontal action; `git diff --check`, document lifecycle review, and the diff-scoped quality audit passed with no task-owned finding.
- Update rule: after each phase passes, record concise evidence, check its tasks, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named gate passes.
- Rendered evidence has no UIUX blocker in the affected states.
- Durable decisions are recorded in their canonical owners.
- Frontmatter status changes to `done` only after implementation is complete.

Replan when:

- A material discovery invalidates a locked behavior or owner.

Do not replan or stop for:

- Implementation-local mechanics contained by this contract.
- Passing checks whose relevant inputs have not changed.
