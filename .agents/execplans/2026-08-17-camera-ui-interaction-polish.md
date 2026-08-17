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
- Course Start retains its approved horizontal directional action. Fire alone receives the smaller projectile-marked treatment.
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

### Phase 6: Restore Start and make preview changes immediate and atomic

Goal: correct the Start-button misunderstanding and remove the delayed, scale-like terrain preview swap.

Preconditions:

- The user's 2026-08-17 correction supersedes Phase 5's Start rollback; Fire remains the only newly redesigned button.
- Measured cold prepared-resource loads take 19–85 ms and preview construction takes 8–25 ms; the preview camera already snaps in one frame, so no camera tween needs removal.

Source owners: `src/cannon_golf/course_artifact_repository.gd`, `src/cannon_golf/app/cannon_golf_app.gd`, `src/cannon_golf/app/cannon_golf_preview_world.gd`, course-select scene/script/theme, focused repository/app/UI tests, canonical design rules/decisions

- [x] **6.1** Warm the prepared catalog without blocking selection.
  - Change: let the artifact repository prefetch the bounded fifteen-course catalog after prioritizing the selected course, retain those immutable prepared artifacts, and let a user request preempt queued background work.
  - Accept: all catalog artifacts become ready through threaded loading, the latest explicit request still wins, no terrain generation occurs, and selection can reuse warmed artifacts immediately.
- [x] **6.2** Make the visible preview swap atomic.
  - Change: build the replacement hidden, configure and snap the preview camera, then switch old/new visibility in one call before freeing the old builder.
  - Accept: no reachable frame can show a new terrain with the old framing or both terrain builders together; the final preview retains exact prepared visual parity.
- [x] **6.3** Restore the approved directional Start action.
  - Change: restore the compact horizontal `LV n 시작 →` / `START LV n →` button and its own theme variation; keep the redesigned Fire unchanged.
  - Accept: Start matches the pre-rollback course-select render, truthful preparation/error states remain, and Fire retains its current projectile-marked action.
- [x] **6.4** Validate interaction, timing, and rendered output.
  - Change: run focused repository, app-flow, performance, selection, and UI contracts; capture and inspect a real course-ready frame; run `git diff --check` and the diff-scoped quality audit.
  - Accept: focused checks exit zero, the render has no clipping or stale composition, and no task-owned quality finding remains.

### Phase 7: Keep Cannon stable while editing launch setup

Goal: stop aim and power controls from reauthoring the selected Cannon camera preset.

Preconditions:

- Cannon remains source-relative, so selecting another launcher source may relocate it.
- Deliberate map pan, orbit, wheel zoom, or arrow-pan may still enter Overview as accepted in D-052.

Source owners: `src/cannon_golf/cannon_golf_game.gd`, focused camera test/capture, canonical product behavior and decision records

- [x] **7.1** Decouple launch setup from the Cannon camera transform.
  - Change: update the launcher and HUD for horizontal aim, elevation, and power without resubmitting a camera pose; retain pose synchronization when the launcher source changes.
  - Accept: setup controls move the barrel and aim display while the selected Cannon camera transform remains fixed and finite.
- [x] **7.2** Add a regression contract for extreme setup edits.
  - Change: change horizontal aim, elevation, and power after selecting Cannon, advance the camera, and compare the final transform with the stored preset.
  - Accept: Cannon remains selected and the transform is unchanged; existing deliberate Overview exploration checks continue to pass.
- [x] **7.3** Render and inspect the stable setup state.
  - Change: capture a real 1280 by 720 Cannon frame after an extreme setup edit, inspect it at native pixels, then run `git diff --check` and the diff-scoped quality audit.
  - Accept: the terrain framing is stable, the changed launcher direction remains legible, and no task-owned quality finding remains.

### Phase 8: Explore locally without leaving Cannon

Goal: let the player inspect the selected cannon's nearby surroundings without an implicit Overview transition.

Preconditions:

- The user's 2026-08-17 clarification supersedes Phase 7's retained D-052 exploration transition.
- Overview and Cannon remain explicit presets with independent exploration state.

Source owners: `src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/cannon_golf_game.gd`, focused camera/input tests and capture, canonical camera rules and decisions

- [x] **8.1** Give Cannon bounded local pan, orbit, and zoom.
  - Change: store Cannon-local exploration independently from Overview, apply drag, wheel, and arrow input to the active preset, and bound Cannon movement so it remains a rear/local terrain view rather than becoming aerial or course-wide.
  - Accept: each input visibly moves the Cannon camera while `view_mode` remains `cannon`; the Overview state remains unchanged.
- [x] **8.2** Preserve and reset the correct Cannon context.
  - Change: snapshot Cannon exploration across Shot Follow, reset it when Cannon is explicitly reselected or the launcher source changes, and make camera reset restore the active preset instead of forcing Overview.
  - Accept: `Tab` restores the exact explored Cannon pose, while explicit Cannon reset/source relocation returns to the authored local pose.
- [x] **8.3** Replace the transition regression with local-exploration evidence.
  - Change: update camera/input contracts and capture a real 1280 by 720 Cannon frame after combined local pan, orbit, and zoom.
  - Accept: focused and full checks pass, the rendered view remains near the cannon without a top-view jump, and no task-owned quality finding remains.

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
| Cannon exploration approaches a map-wide or top-down composition | Tighten Cannon-local pan, yaw, pitch, or distance bounds in the existing rig | Do not add a second camera controller or silently enter Overview |
| Localized Start copy clips | Shorten to `LV n 시작 →` / `START LV n →` and preserve the 44 px target | Do not enlarge it into another dominant circle or panel |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Phase 8 — Cannon retained its view through bounded local pan, orbit, arrow, and zoom input; exact explored state returned after Shot Follow, active reset and source relocation restored the authored local pose, base/explored 1280 by 720 renders remained near the launcher, and all twenty-four focused suite checks, `git diff --check`, document lifecycle review, and the diff-scoped quality audit passed with no task-owned finding.
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
