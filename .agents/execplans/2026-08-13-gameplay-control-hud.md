---
type: plan
status: done
created: 2026-08-13
scope: Gameplay aiming controls, shortcut help, and one-way Tab return behavior
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Gameplay Control HUD - Execution Contract

The Cannon Golf gameplay HUD will replace its settings-like slider-only aiming row with precise game controls, add an on-demand shortcut panel, and make `Tab` a one-way immediate return from Shot Follow to planning. The established warm paper-white, navy, blue-accent system and open course center remain intact.

## Purpose

- Objective: make aiming fast, discoverable, and game-like without losing direct slider input or adding an always-open instruction block.
- Deliverable: three stepper-enhanced aim modules, a collapsible shortcut panel, one-way `Tab` behavior, regression tests, rendered evidence, current product records, and a refreshed Windows prototype.
- Completion state: mouse and keyboard users can precisely adjust every launch axis, discover shortcuts, and return from follow immediately; supported desktop layouts remain unclipped.

## Scope and Boundaries

In scope:

- Gameplay HUD scene/script, gameplay input routing, focused input/UI/session tests, gameplay capture state, README, and current Cannon Golf product records.

Out of scope:

- Controller or touch mappings, physics ranges, course geometry, trajectory prediction, a permanent tutorial overlay, or a replacement design system.

Constraints and invariants:

- Each horizontal, elevation, and power module shows its label, current value, decrement/increment buttons, slider, and keyboard pair.
- Step buttons change by the same one-unit canonical step as keyboard input and repeat while held; their disabled states reflect value limits and course completion.
- The shortcut panel is hidden by default, opens from a 44 px `?` button, uses concise Korean/English rows, manages focus, and closes before `Esc` can pause.
- `Tab` returns from Shot Follow to the stored planning pose. It never enters Shot Follow. When already planning, it remains available for normal GUI focus traversal.
- The explicit follow icon remains the way to enter or leave Shot Follow.
- Fire remains the sole primary action; normal gameplay adds no status copy, prediction, or permanent instruction block.
- Existing plus/minus assets and theme primitives are reused; no dependency is added.

Destructive or irreversible actions:

- None. The existing ignored Windows build output is refreshed only after source validation.

Exact actions requiring owner or user approval:

- Controller/touch mappings, new assets or dependencies, physics-range changes, or a permanent always-open tutorial require separate approval.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Slider-only aiming | `cannon_golf_hud.tscn` has one label, HSlider, and value per axis | Scene and rendered captures | Recompose three compact modules with minus/slider/plus, large value, and key hint; reuse retained plus/minus assets | 1.1, 1.2 |
| Precise repeated input | `CannonGolfGame._adjust_setup` owns canonical launcher updates; retained Paint Mountain aim controls use press-and-hold repetition | Current game/HUD and retained source | HUD steppers mutate their canonical sliders by one unit, so existing `setup_changed` remains the single setup event contract | 1.2 |
| Shortcut discoverability | No Cannon Golf shortcut panel exists; current specs prohibit persistent shortcut legends | Scene/test/spec inspection and current user override | Add a hidden-by-default contextual panel opened by `?`; update the prohibition to allow this on-demand owner only | 2.1, 3.1 |
| Tab behavior | `KEY_TAB` currently calls `toggle_shot_camera`, so a second press re-enters follow | Game source/session test and explicit user requirement | Handle Tab in `_input`; consume it only when it successfully returns from follow; remove Tab toggle from `_unhandled_input` | 2.2 |
| Accessibility/layout | Current HUD has an explicit focus chain and 40-44 px target checks at 1280x720 and 1600x900 | UI contract test and capture runner | Keep 40 px minimum steppers, 44 px help/close actions, task-order focus, localized accessible names, and an open center | 1.1, 2.1, 3.2 |
| Toolchain | Godot 4.7.1, focused tests, rendered capture runner, verify script, Windows export preset, and build path passed the immediately preceding change | Direct repo/version inspection and commit `782f5b9` evidence | Extend the existing tests/capture path, then run one focused suite, verify, export, and bounded built-app smoke | 3.2 |

Readiness statement:

- All material UX, input, ownership, dependency, and validation decisions are closed.
- The installed Godot 4.7.1 binary and repository-owned validation commands are available.
- Remaining choices are implementation-local spacing and scene wiring within the locked behavior.

## Tasks

### Phase 1: Game-like precise aiming controls

Goal: make all three launch axes fast to scan and easy to adjust by mouse or keyboard.

Preconditions:

- Existing slider values and launcher ranges remain authoritative.

Source owners: `scenes/cannon_golf/cannon_golf_hud.tscn`, `src/cannon_golf/cannon_golf_hud.gd`, `tests/cannon_golf_ui_contract_test.gd`, `tests/cannon_golf_input_test.gd`

- [x] **1.1** The aim panel presents three coherent control modules.
  - Change: use a label/value/key header and minus/slider/plus input row per axis, separated by spacing/dividers rather than nested cards.
  - Accept: UI contract checks prove values and controls are enclosed, each routine target is at least 40 px, task-order focus is explicit, and panels do not overlap at 1280x720 or 1600x900.
- [x] **1.2** Step buttons provide precise single and held adjustment.
  - Change: connect each decrement/increment button to the matching slider with one-unit press steps and bounded hold repeat; localize tooltip/accessibility copy and synchronize disabled states.
  - Accept: input tests prove every button changes only its intended launcher axis by one unit, limits disable the correct edge, hold repeat produces additional bounded steps, and cleared state disables all setup inputs.

### Phase 2: On-demand shortcuts and one-way Tab

Goal: expose controls without covering the course and make the requested return action deterministic.

Preconditions:

- Phase 1 targeted checks pass.

Source owners: `scenes/cannon_golf/cannon_golf_hud.tscn`, `src/cannon_golf/cannon_golf_hud.gd`, `src/cannon_golf/cannon_golf_game.gd`, `tests/cannon_golf_ui_contract_test.gd`, `tests/cannon_golf_input_test.gd`, `tests/cannon_golf_session_test.gd`

- [x] **2.1** A compact shortcut panel is available on demand.
  - Change: add a `?` toggle and focus-managed panel listing aim keys, Fire, planning return, retry, camera drag/zoom, pan, and pause; close it by its button, toggle, or `Esc`.
  - Accept: the panel is hidden initially, opens with localized complete rows, keeps every interactive target accessible, closes with focus restored, and consumes `Esc` without emitting pause.
- [x] **2.2** `Tab` only returns to planning.
  - Change: route Tab before GUI dispatch, consume only a successful follow-to-planning return, remove its toggle path, and remove Tab from the planning-state follow tooltip.
  - Accept: real key input returns the followed ball to planning on the first Tab and a second Tab does not re-enter follow; the follow icon can still enter and leave follow.

### Phase 3: Product record and production evidence

Goal: keep current guidance truthful and verify the actual desktop presentation.

Preconditions:

- Phase 2 behavior tests pass.

Source owners: `project-specs/cannon-golf/PRD.md`, `project-specs/cannon-golf/DESIGN_RULES.md`, `project-specs/cannon-golf/DECISIONS.md`, `README.md`, `tests/capture_cannon_golf_frame.gd`, this contract

- [x] **3.1** Current records describe the accepted HUD and input grammar.
  - Change: record stepper-enhanced aim modules, the on-demand shortcut owner, and one-way Tab return while retaining information-restraint rules.
  - Accept: docs make no claim that shortcut help is absent or that Tab toggles into follow.
- [x] **3.2** Rendered, source, and release gates pass.
  - Change: capture planning and shortcut-open states at 1280x720 and 1600x900, inspect pixels, run focused tests and verify, export Windows, and run the bounded hidden executable smoke.
  - Accept: captures show legible unclipped controls and an open center when help is closed; all commands exit zero without Godot script/runtime errors.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Run `cannon_golf_ui_contract_test.gd`, `cannon_golf_input_test.gd`, and `cannon_golf_session_test.gd` with the verified Godot 4.7.1 console binary | Phase 1 or 2 task checks are implemented | A HUD/input/session owner changes |
| UI gate | Run `tests/capture_cannon_golf_frame.gd` for `planning` and `shortcuts` at 1280x720 and 1600x900, then inspect every PNG | Phase 3.2 visible inputs are complete | A visible HUD/camera/copy input changes |
| Final source gate | Run `scripts/test-cannon-golf.ps1`, `scripts/verify.ps1`, and `git diff --check` | All tasks and UI evidence pass | A source or final-gate input changes |
| Release gate | Export `Windows Desktop` to `builds/windows/CannonGolfPrototype.exe`, then start it hidden with `--headless --quit-after 3` and require zero exit | Final source gate passes | An export/runtime input changes |

Validation rules:

- Run the narrowest task check first and each broader gate once at its named cadence.
- Do not repeat a passing check unless a relevant input changed.
- Rerun a failed check only after a relevant fix or a new hypothesis.
- On resume, continue from the first unchecked task whose prerequisites pass; checked tasks and recorded evidence remain complete unless their inputs changed.
- Update task checkboxes and the progress pointer together after each checkpoint.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch and revise this contract before continuing | Do not choose a new input scheme, design system, dependency, or game rule during implementation |
| Three modules overlap the action dock at 1280x720 | Reduce module rail width and spacing while preserving 40 px step targets and readable values | Do not hide an axis, move Fire, or reduce targets below the contract |
| Shortcut rows exceed the safe top-right region | Tighten row spacing or use two balanced columns while retaining every named action | Do not make the panel permanently visible or remove required mappings |
| Global Tab blocks focus traversal while already planning | Consume Tab only when `return_to_planning_view()` succeeds | Do not remove keyboard focus order or restore toggle behavior |

Implementation-local discoveries may be handled within the locked contract when they cannot change visible behavior, ownership, architecture, accessibility, or acceptance.

## Progress and Next Steps

- Canonical progress: the checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Last completed gate: Task 3.2 production evidence. Planning and shortcut-open captures at 1280x720 and 1600x900 were visually inspected without clipping or dock overlap; all 15 focused tests, source import/parse/startup verification, `git diff --check`, Windows release export, and the built executable smoke exited zero.
- Update rule: record concise evidence, check the completed task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check and named validation gate passes.
- Current docs own the durable behavior and this plan status is `done`.
- No placeholder or unresolved material decision remains.

Replan when:

- A material discovery invalidates the locked input, layout, ownership, accessibility, or validation contract.

Do not replan or stop for:

- Implementation-local scene spacing or signal wiring within this contract.
- A passing check whose inputs have not changed.
