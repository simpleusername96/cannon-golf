---
type: plan
status: draft
created: 2026-08-12
scope: Provisional implementation-oriented task breakdown derived from PRD.md
related:
  - PRD.md
  - DESIGN_RULES.md
  - OPEN_QUESTIONS.md
---

# Cannon Golf Draft Tasks

## Purpose

Show the remaining likely implementation sequence after the first playable
slice. This is a draft planning aid, not an active execution contract. The
completed two-course slice was executed from
`.agents/execplans/2026-08-12-two-course-vertical-slice.md`; material questions
in `OPEN_QUESTIONS.md` must still be resolved before later device work is
promoted to an active plan.

## Tasks

### 1. Close the camera and aiming brief

- [x] Decide Q-01 through Q-04 for the first two-course slice.
- [ ] Produce one graybox camera storyboard of the same stage from top,
  high-oblique, side, near-profile, temporary cannon, and shot-follow views.
- [x] Save a non-runtime screen-direction storyboard covering high-oblique,
  side/profile, and Shot Follow composition in `DESIGN_RULES.md`.
- [x] Select the planning-camera grammar and record it in `DECISIONS.md` and
  `DESIGN_RULES.md`.

### 2. Define the new domain boundaries

- [ ] Decide Q-07 through Q-10 and Q-14; Q-05, Q-06, and Q-11 are resolved in
  `DECISIONS.md`.
- [ ] Specify `ImpactHistory`, `SettlementGoal`, `GoalSet`,
  `BouncePadPlacement`, launch outcome, and stage-result invariants without
  reusing paint/coverage terminology.
- [ ] Map every accepted PRD requirement to a current Paint Mountain owner that
  will be reused, adapted, or retired.

### 3. Establish one direct-goal vertical slice

- [x] Replace coverage-based completion with one safe-settlement goal in a test
  stage.
- [x] Confirm only after the ball remains within goal tolerances; preserve the
  visible confirmed ball and prevent later displacement.
- [x] Provide unlimited unsuccessful launches without a timer, life, ball-stock,
  or shot-count game over.
- [x] Retire each unsuccessful ball only when it resolves, allow unrestricted
  concurrent launches, and preserve every confirmed settled ball.
- [x] Give the standard ball a predictable energy-losing rebound on ordinary
  hard terrain.
- [x] Replace continuous paint behavior with one first-contact history mark per
  launch.
- [x] Remove exact landing guidance from normal play while preserving accessible
  angle and power controls.
- [x] Validate rapid retry and deterministic direct-solution replay.

### 4. Establish planning views

- [x] Implement the selected top/oblique and side/profile planning views.
- [x] Preserve launch setup and confirmed goals
  across map exploration, view changes, and Shot Follow.
- [x] Recompose the HUD around the selected views; remove
  coverage and paint-specific UI.

### 5. Build the initial course progression

- [ ] Implement legal placement, orientation, invalid state, edit rules, and
  deterministic collision response for one pad family.
- [x] Build two direct one-goal stages that teach angle and power.
- [ ] Build two direct multi-goal stages that require several successful
  settlements without a device.
- [ ] Build two stages with certified solutions that use one bounce pad.
- [ ] Build five stages that progressively increase multi-pad route complexity;
  determine exact later-stage pad counts through balancing.
- [ ] Prevent pad placement from creating trivial out-of-bounds or overlapping
  solutions.

### 6. Extend the mechanic vocabulary after the core loop

- [ ] Implement a damping pad that is valid only on fully flat surfaces and
  reduces rebound and rolling without freezing or teleporting the ball.
- [ ] Implement an airflow device with valid mid-air placement, a readable
  bounded stream, and a modest deterministic directional force.
- [ ] Implement a player-placeable gravity zone with valid mid-air placement; it
  produces a sharp local downward acceleration and restores ordinary gravity
  after exit.
- [ ] Decide Q-16 and Q-18 through Q-22 before assigning expansion stages or
  building a dedicated authoring editor.

### 7. Establish the stage-authoring pipeline

- [ ] Replace Paint Mountain coverage targets and fixed mechanism anchors with
  Cannon Golf goals, per-device stock, legal placement rules, and solution
  witnesses.
- [x] Author the first two course profiles manually from intended solutions;
  keep visible fresh-stage content limited to cannon, goals, and terrain.
- [ ] Record a solution witness containing device transforms, launch parameters,
  goal order, and expected settlement results.
- [ ] Replay witnesses through real physics and reject stages that fail stock,
  placement, bounds, safe-settlement, persistence, or robustness rules.
- [ ] After several stages, measure repeated authoring work and decide the
  smallest useful Godot editor dock or viewport gizmo set.

### 8. Validate the product loop

- [ ] Run the prototype comprehension targets in `PRD.md`.
- [ ] Verify newest-to-oldest impact ordering in lit and shaded terrain.
- [ ] Verify goal and selected-pad readability in every planning view.
- [ ] Verify that misses return to a stable planning state and confirmed goals
  persist through later shots and unlimited retries.
- [ ] Verify that damping, airflow, and gravity each solve a distinct route
  problem and remain readable without an exact trajectory preview.

## Progress

- [x] Created a separate Git repository at `D:/npjt/cannon-golf`.
- [x] Copied the Paint Mountain runtime baseline without code edits.
- [x] Separated current product design from Paint Mountain product briefs.
- [x] Saved external research and local visual comparators.
- [x] Saved the current screen-direction storyboard and linked it from the
  canonical visual specification.
- [x] Implemented an isolated playable runtime with two direct-shot courses,
  safe settlement, unlimited retry, impact history, and two planning views.
- [x] Replayed both authored direct-solution witnesses through real physics.

## Next Steps

- Resolve Q-07 through Q-10 and Q-14 before bounce-pad placement work.
- Playtest the two direct courses before expanding to multi-goal stages.
- Promote only the next closed content slice into an active execution contract.

## Verification

- Preserve retained legacy owners as Paint Mountain source history; validate the
  isolated `cannon_golf` main path with `scripts/test-cannon-golf.ps1`.
- Validate Markdown lifecycle metadata, local links, and `git diff --check`.
- Do not treat the legacy Paint Mountain suite as acceptance for the isolated
  Cannon Golf main path.

## Risks

- Executing this draft as if decisions were closed would allow the inherited
  target solver, coverage state, and frontal camera to choose the product.
- Building multiple devices before one direct-goal loop is proven would expand
  scope before the core learning signal is validated.
