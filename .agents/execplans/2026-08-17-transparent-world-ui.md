---
type: plan
status: done
created: 2026-08-17
scope: Cannon Golf gameplay HUD and course-selection visual parity with the user-approved real-snapshot redesigns
related:
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Transparent World UI - Execution Contract

The shipped 1280 by 720 gameplay and course-selection screens will preserve the current rendered world and replace only their UI chrome with the user-approved transparent, navy-and-amber overlays: one bottom aim rail in gameplay and one flat auto-scrolled level list in course selection.

## Purpose

- Objective: implement the approved real-snapshot UI redesign without changing terrain, camera, gameplay, course preparation, or navigation behavior.
- Deliverable: updated Godot UI scenes, scripts, shared theme variations, canonical UI guidance, focused regression tests, and inspected rendered evidence.
- Completion state: the approved layouts render at 1280 by 720, remain operable at wider desktop sizes, focused and full Cannon Golf checks pass, and the task-owned quality audit is clean.

## Scope and Boundaries

In scope:

- Normal-play HUD status, cannon-source selector, top action row, aim controls, power control, and Fire presentation.
- Course-selection heading, catalog rows, thin scrollbar, automatic selected-row visibility, Back, and Start presentation.
- Korean and English copy, keyboard focus, tooltip/accessibility names, preparation states, and existing gameplay signals.
- Canonical design-rule and decision-record updates required to prevent the retired white-card/blue-primary direction from returning.

Out of scope:

- Terrain, camera, goals, launcher, physics, course generation, settings, main menu, shortcut panel content, pause layout, and result layout.
- New dependencies, new icons, world-space UI, or gameplay rules.

Constraints and invariants:

- Preserve every existing world-rendering and interaction owner; UI changes remain in current scene/script/theme owners.
- Normal play uses no persistent white/cream panel surface, no mobile D-pad, and no blue rectangular Fire button.
- Gameplay keeps the center open: compact status at upper-left, five routine actions at upper-right, and a single transparent rail along the bottom edge.
- The 1280 by 720 gameplay rail uses 32 px outer margins, at least 40 px routine targets, three aligned setup groups, and an 88 px circular amber Fire action at the far right.
- Course selection uses no list card or vertical divider. The selected row has a 4 px amber left mark, stronger type, and goal count; unselected rows remain surface-free.
- Selecting or opening a course scrolls its row into view. Level text is not duplicated as difficulty, score, or stars.
- Selected, disabled, hover, pressed, and keyboard-focus states remain visible without color alone.
- Existing unrelated untracked files remain untouched.

Destructive or irreversible actions:

- None.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| HUD layout | `scenes/cannon_golf/cannon_golf_hud.tscn` owns five persistent pale panels; `src/cannon_golf/cannon_golf_hud.gd` owns signals, copy, focus, and state | Current scene/script and real LV12 capture | Retain owners and behavior; replace chrome with transparent status/actions and one bottom rail | 2.1, 2.2 |
| Course-selection layout | `cannon_golf_course_select.tscn/.gd` owns a flat 15-row list but does not ensure the selected row is visible | Current scene/script, selection tests, real LV12 capture | Keep one direct ScrollContainer; add selected goal-count copy and deferred `ensure_control_visible` | 1.1, 1.2 |
| Visual language | Shared theme still defines warm white HUD surfaces and blue primary actions | `resources/ui/paint_mountain_theme.tres`; current `DESIGN_RULES.md` | Add named transparent/amber variations without altering unrelated UI types; update canonical guidance and append D-051 | 0.1, 1.1, 2.1 |
| Accessibility and states | Existing controls have explicit focus chains, tooltips, accessible names, and preparation-state copy | `cannon_golf_ui_contract_test.gd`; `cannon_golf_course_selection_state_test.gd` | Preserve semantics and 40 px targets; selected/focus states use shape/border/weight as well as color | 1.2, 2.2, 3.1 |
| Validation | Godot 4.7.1 and bounded wrapper work under PowerShell 7; focused baseline UI tests pass | Verified `pwsh ... invoke-cannon-golf-validation.ps1` runs on 2026-08-17 | Use `pwsh`, focused checks while editing, rendered capture once after implementation, then full suite once | 1.2, 2.2, 3.1, 3.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership, safety, and validation decision is closed.
- Godot `4.7.1.stable.official.a13da4feb`, PowerShell 7, the bounded validation wrapper, focused UI tests, and rendered capture harness are available and verified.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 0: Record the accepted direction

Goal: make the latest user-approved direction canonical before code changes.

Source owners: `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/DECISIONS.md`

- [x] **0.1** Replace the obsolete persistent white-surface/blue-primary HUD rule and append D-051.
  - Change: specify world-preserving transparent overlays, navy text, amber selection/Fire, one bottom rail, flat course rows, and retained accessibility/state behavior.
  - Accept: the active spec and record no longer direct future implementation back to white HUD cards or a blue rectangular Fire action.

### Phase 1: Match the approved course-selection snapshot

Goal: make LV12 visible and selected in a transparent flat list beside the unchanged real preview.

Preconditions:

- Task 0.1 accepted.

Source owners: `resources/ui/paint_mountain_theme.tres`, `scenes/cannon_golf/app/cannon_golf_course_select.tscn`, `src/cannon_golf/app/cannon_golf_course_select.gd`, `tests/cannon_golf_course_selection_state_test.gd`

- [x] **1.1** Implement transparent rows and amber Start/selection presentation.
  - Change: remove Shade and divider-like composition, apply named flat row and circular action variations, show selected goal count once, and keep Back surface-free.
  - Accept: unselected rows have no filled surface; the selected row has a non-color amber mark and stronger copy; Start is circular and all states remain truthful.
- [x] **1.2** Ensure selection visibility and preserve keyboard/state behavior.
  - Change: defer `ensure_control_visible()` after selection/open/language refresh and update the focused test for selected copy, visibility, focus, and preparation states.
  - Accept: selecting LV12 at 1280 by 720 makes its row visible and focused; the focused course-selection test exits zero.

### Phase 2: Match the approved gameplay snapshot

Goal: replace five persistent panels with one sparse edge-aligned HUD over the unchanged world.

Preconditions:

- Phase 1 acceptance passes.

Source owners: `resources/ui/paint_mountain_theme.tres`, `scenes/cannon_golf/cannon_golf_hud.tscn`, `src/cannon_golf/cannon_golf_hud.gd`, `tests/cannon_golf_ui_contract_test.gd`, `tests/cannon_golf_relay_test.gd`

- [x] **2.1** Recompose the normal-play HUD.
  - Change: convert status/source/actions/aim/power owners to transparent controls; place horizontal, elevation, and power controls on one bottom baseline; use a circular amber Fire action; keep on-demand help, pause, and result behavior unchanged.
  - Accept: no persistent normal-play panel has an opaque white/cream surface; no D-pad remains; the three setup groups share one bottom rail and Fire is the only primary action.
- [x] **2.2** Preserve behavior, localization, focus, and responsive fit.
  - Change: retain signal wiring and stable node names, update copy/focus/layout contracts for the new structure, and preserve source-selection and live-ball states.
  - Accept: the focused HUD and relay tests exit zero at the existing logical viewport checks; Korean and English labels fit and every icon action retains an accessible name.

### Phase 3: Prove rendered parity and integration

Goal: verify actual Godot pixels and the complete Cannon Golf test surface once.

Preconditions:

- Phases 1 and 2 pass.

Source owners: `tests/capture_cannon_golf_frame.gd`, `.agents/evidence/cannon-golf/2026-08-17-transparent-world-ui/`, task-owned source/tests/docs

- [x] **3.1** Capture and inspect real 1280 by 720 output.
  - Change: render `planning` course 11 and `course_ready` course 11 through the existing background capture harness to the task evidence directory.
  - Accept: images are real, nonblank, correct-state Godot frames; the world composition is unchanged; gameplay matches the transparent top/bottom HUD and course selection shows LV12 in view without cards, divider, or blue rectangular Start.
- [x] **3.2** Run final integration and quality gates.
  - Change: run the complete Cannon Golf focused suite, `git diff --check`, and the diff-scoped codebase quality audit; make only small task-owned corrections.
  - Accept: every command exits zero, no Godot error is reported, rendered blockers are absent, and no task-owned responsibility or failure-path issue remains.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-cannon-golf-validation.ps1 -Script res://tests/cannon_golf_course_selection_state_test.gd -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe' -TimeoutSeconds 120` or the same command with `cannon_golf_ui_contract_test.gd` | Its owning screen reaches a coherent state | Relevant screen/script/test input changes |
| Rendered phase gate | The same wrapper with `-Rendered`, `res://tests/capture_cannon_golf_frame.gd`, and user arguments for the two named 1280 by 720 captures | Both screen phases pass | A visible scene/theme/script/capture input changes |
| Final gate | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'`; `git diff --check`; diff-scoped quality audit | Rendered phase gate passes | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not repeat a passing check unless its relevant inputs changed.
- Rerun a failed check only after a relevant implementation change or new hypothesis.
- Record known non-blocking warnings once instead of rediscovering them.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, update the contract, and obtain required approval before resuming | Do not choose a new UX, architecture, dependency, scope, or validation contract during implementation |
| Transparent controls lose contrast over a reachable world state | Add a localized text outline/shadow or low-alpha line treatment only | Do not restore persistent white/cream surfaces or section cards |
| Circular Fire or Start cannot retain minimum target size at a supported desktop viewport | Preserve the circle and reduce adjacent spacing/rail widths first | Do not revert to a blue rectangular primary action |

Implementation-local discoveries may be handled inside the locked contract when they cannot change scope, visible behavior, ownership, architecture, safety, or acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: Complete.
- Next task: None.
- Last completed gate: Task 3.2 — all 24 Cannon Golf validation entries passed in 127.6 seconds, `git diff --check` passed, and the diff-scoped quality audit found no task-owned responsibility, contract, or reachable failure-path issue. Final 1280 by 720 captures retain the real LV12 world while matching the approved transparent navy-and-amber UI.
- Update rule: after a checkpoint passes, record concise evidence, check the task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- The rendered and final gates pass.
- No unresolved UIUX blocker or task-owned quality finding remains.
- Frontmatter status is changed to `done` only after implementation is complete.

Replan when:

- A material discovery invalidates the locked contract.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.

## Anti-Rework Execution Rules

- On start or resume, read this contract and inspect the worktree only enough to confirm checkpoint inputs, then continue from the first unchecked task whose prerequisites are satisfied.
- Treat checked tasks and recorded passing evidence as complete unless a relevant input changed or evidence is missing.
- Mark a task complete only after its acceptance check passes, and update this file as the single progress source.
- Do not rerun passing checks merely to regain confidence.
