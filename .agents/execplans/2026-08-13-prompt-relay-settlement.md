---
type: plan
status: done
created: 2026-08-13
scope: Make visibly captured relay balls settle promptly and expose the relocated launcher for immediate next-leg fire
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-13-longitudinal-relay-course.md
  - .agents/execplans/2026-08-13-camera-pan-goal-settlement.md
---

# Prompt Relay Settlement - Execution Contract

Keep the accepted safe-settlement and bounce-out rules, but remove the long
rolling tail that makes a visibly captured ball look stuck. Once a contained
ball has lost enough energy, goal-local settlement drag must bring it through
the existing strict motion-and-dwell gate promptly; confirmation must then
relocate the one launcher and leave Fire immediately usable for the next leg.

## Purpose

- Objective: make a captured edge landing in `deep_relay` advance to leg two in
  a short, predictable interval without confirming a fast ball that can escape.
- Deliverable: bounded settlement-drag behavior, relay transition regression
  coverage, and rendered proof that the confirmed ball and relocated launcher
  coexist in the leg-two planning state.
- Completion state: a representative edge landing confirms within `3.0`
  seconds, a fast arrival still bounces out, the relocated launcher can fire,
  targeted physics/state checks and rendered states pass, and Windows export
  and smoke checks pass.

## Scope and Boundaries

In scope:

- The active goal's low-energy settlement phase.
- Restoration of ordinary ball drag outside that phase.
- Relay confirmation, launcher relocation, immediate next-leg firing, and
  rendered transition evidence.

Out of scope:

- Terrain geometry, goal radius/recess/lip, ballistics, certified launch
  witnesses, global safe-motion thresholds, dwell duration, camera controls,
  HUD layout, and new textual status UI.

Constraints and invariants:

- Contact or containment alone never confirms a goal.
- Existing `motion_is_safe` thresholds and `settle_seconds` remain the final
  confirmation gate.
- Settlement drag begins only while the ball remains in the active goal and
  both its linear and angular motion are below the bounded capture-entry gate.
  Once admitted, it stays latched until the ball leaves that goal or resolves;
  this prevents a steep basin slope from repeatedly disabling capture drag.
- A faster ball retains ordinary physics and must be able to leave as
  `bounced_out`.
- Intermediate confirmation preserves the settled ball, moves the same
  launcher to the authored next-leg anchor, resets setup to `50 / 50 / 50`, and
  permits Fire without a stage reset.
- No dependencies or destructive actions are required.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Long visible delay | `CannonGolfGame._update_live_ball` accumulates dwell only below `1.44 m/s` linear and `4.4 rad/s` angular; ordinary ball drag remains `0.20 / 0.84` inside the basin | Real-physics probes from center/45%/75%/90% radius resolved in `0.67 / 3.77 / 5.82 / 7.52` seconds; a real edge start crossed the entry gate during its first `0.25` seconds, then the steep slope accelerated it above `4 m/s` and repeatedly disabled a non-latched draft | Retain the strict gate; latch conditional settlement drag after the contained ball first falls below `4.0 m/s` linear and `16.0 rad/s` angular, and clear the latch only on exit or resolution | 1.1, 1.2 |
| Bounce-out rule | `entered_goal` switches containment to the rebound column and any later exit fails `bounced_out` | PRD FR-4/AC-7 and relay regression | Do not confirm on contact or containment; clear latched drag on goal exit and preserve exit failure | 1.1, 1.2 |
| Next-leg cannon | `CourseBuilder.activate_leg` already reconfigures the one launcher and `_confirm_goal` returns to planning with Fire available | Source trace, relay state test, and rendered diagnostic | Keep those owners; strengthen evidence to prove the authored anchor, visible launcher, valid muzzle origin, and immediate Fire | 2.1, 2.2 |
| UI feedback | The confirmed world state uses the retained ball, reduced confirmed-goal rim/flag, active next goal, launcher, and enabled Fire; persistent HUD prose is forbidden | D-025/D-030 and existing capture harness | Do not add text or panels; make the state transition prompt and prove the world-state composition | 2.2 |

Readiness statement:

- Product, physics, ownership, UX, dependency, and validation decisions are
  closed. The selected drag gate was compared against ordinary drag and an
  unconditional strong-drag alternative; unconditional strong drag was
  rejected because it captured a `30 / 16 m/s` escape probe.
- Godot `4.7.1`, the repository test scripts, background rendered capture,
  verification script, Windows export preset, and built-app smoke path are
  available and their invocation is known.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Prompt but safe physical settlement

Goal: shorten only the low-energy rolling tail inside the active goal.

Preconditions:

- Current real-physics witnesses pass before the change.

Source owners: `src/cannon_golf/golf_ball.gd`,
`src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/cannon_golf_game.gd`,
`tests/cannon_golf_goal_test.gd`, `tests/cannon_golf_relay_test.gd`

- [x] **1.1** Add a reversible, bounded settlement-drag mode.
  - Change: let the ball own ordinary versus latched settlement drag values;
    let the goal own the `4.0 m/s` linear and `16.0 rad/s` angular capture-entry
    gate.
  - Accept: ordinary drag remains `0.20 / 0.84`; settlement mode applies
    `1.20 / 2.40`; leaving the goal or resolving restores ordinary drag.
  - Guard: `motion_is_safe` continues to reject `2.5 m/s` translation and
    `5.0 rad/s` rotation.
  - Evidence: `cannon_golf_goal_test.gd` passed with ordinary `0.20 / 0.84`,
    settlement `1.20 / 2.40`, reversible mode, bounded entry, and unchanged
    strict safe-motion assertions.
- [x] **1.2** Apply settlement drag only during valid active-goal containment.
  - Change: coordinate the mode in `_update_live_ball`; clear it on exit,
    failure, removal, and confirmation without changing final success rules.
  - Accept: a physical `90%`-radius zero-speed start in relay goal one advances
    within `3.0` seconds; a `30 / 16 m/s` arrival exits as `bounced_out` and
    does not advance.
  - Evidence: `cannon_golf_relay_test.gd` passed both real-physics probes;
    `cannon_golf_solution_test.gd` passed all existing per-leg witnesses.

Batch gate:

- Run `cannon_golf_goal_test.gd`, `cannon_golf_relay_test.gd`, and
  `cannon_golf_solution_test.gd` headlessly with Godot `4.7.1`.

### Phase 2: Prove the next launch site is ready and visible

Goal: make the resulting checkpoint state unambiguous and immediately usable.

Preconditions:

- Phase 1 acceptance and batch gate pass.

Source owners: `tests/cannon_golf_relay_test.gd`,
`tests/capture_cannon_golf_frame.gd`, `scripts/verify.ps1`, this contract

- [x] **2.1** Strengthen the relay transition contract.
  - Change: assert that confirmation places the launcher at the generated
    leg-two anchor, that its muzzle origin is valid and distinct from the
    confirmed ball, and that Fire immediately creates one ball from that origin.
  - Accept: the focused relay test passes through the real edge-settlement path
    and the next-leg launch path without direct `_confirm_goal` substitution.
  - Evidence: the relay test proved the authored leg-two anchor, distinct valid
    muzzle origin, enabled Fire, and a next ball launched from that origin.
- [x] **2.2** Complete rendered, audit, source, and package gates.
  - Change: extend the existing `relay_confirmed` capture assertions to require
    the launcher mesh on screen, the confirmed ball retained, planning mode,
    and Fire availability; capture at `1280 x 720` and `1600 x 900`.
  - Accept: both captures show a leg-two planning state without overlap or
    clipping; diff-scoped quality audit, `scripts/verify.ps1`,
    `git diff --check`, Windows release export, built-app smoke, and scoped
    commits pass.
  - Evidence: `relay_confirmed` rendered at `1280 x 720` and `1600 x 900` with
    the retained ball, relocated launcher, enabled Fire, and unclipped desktop
    HUD; runtime capture assertions passed. The Level 3 gameplay-flow UI/UX gate
    passed for the supported Windows desktop surface; narrow mobile is outside
    the product target. The diff-scoped responsibility/failure-path audit,
    `scripts/verify.ps1`, and `git diff --check` passed. The canonical build was
    held open by user-owned PID `3100`, so it was not terminated; the same
    `Windows Desktop` release preset exported and smoked successfully as
    `builds/windows/CannonGolfPrototype-settlement-verify.exe`.
    Implementation commit: `c357b7b`.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | Godot headless `cannon_golf_goal_test.gd` and `cannon_golf_relay_test.gd` | Goal/ball/session inputs change | Those inputs change |
| Phase gate | Godot headless `cannon_golf_solution_test.gd` | Phase 1 task checks pass | Ball physics, settlement, terrain, launcher, or witness inputs change |
| Render gate | `capture_cannon_golf_frame.gd -- --state=relay_confirmed --course=2` at the two named sizes with normal `gl_compatibility` rendering and `--background` | Phase 2 assertions pass | Visible state, camera, launcher, goal, ball, or HUD inputs change |
| Final gate | `scripts/verify.ps1`, `git diff --check`, release export through `Windows Desktop`, and built executable `--headless --quit-after 3` smoke | Tasks and audit pass | A final-gate input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not rerun passing checks unless their relevant inputs change.
- Rerun a failed check only after a relevant implementation change or a new
  hypothesis can produce new evidence.
- The product supports Windows desktop, not narrow mobile; UI evidence uses the
  two supported desktop sizes and records that exception.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch, revise the contract, and obtain any required approval before resuming | Do not select a new product, architecture, physics, UX, or validation contract during implementation |
| Fast escape is captured | Lower the capture-entry limits or drag values while retaining the existing strict final gate | Never confirm on contact, widen the goal, or weaken bounce-out |
| Edge capture exceeds `3.0` seconds | Tune only settlement drag within the ball-local mode and rerun the edge/escape pair | Do not change terrain, witnesses, final safe speeds, or dwell time |
| Relocated launcher is off-screen after valid transition | Adjust only the existing leg-two planning frame/capture assertion if source evidence proves the authored anchor is correct | Terrain or relay-anchor movement requires contract revision |
| Canonical Windows executable is held open by a user-owned process | Do not terminate it; export the same preset to a task-named verification executable and smoke that artifact | Replacing the canonical running executable waits for its owner to close it |

Implementation-local discoveries may be handled inside these boundaries when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: task checkboxes above.
- Current phase: complete.
- Next task: none.
- Last completed gate: rendered state, diff-scoped audit, source verification,
  release export, built-app smoke, and implementation commit passed.
- Update rule: record evidence, check the task, and advance this pointer in the
  same edit after each checkpoint.

## Completion and Stop Conditions

Complete when every task acceptance, named guard, phase/render/final gate, and
task-scoped commit passes, then change this document to `status: done`.

On start or resume, read this active contract and inspect only the worktree
inputs needed for the first unchecked task. Treat checked evidence as complete
unless a relevant input changed. Replan only if a material discovery invalidates
the locked contract; do not replan for implementation-local mechanics.
