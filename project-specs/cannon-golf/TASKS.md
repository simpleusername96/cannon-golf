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

Show the likely implementation sequence without authorizing code changes. This
is a draft planning aid, not an active execution contract. Material questions
in `OPEN_QUESTIONS.md` must be resolved before the affected task is promoted to
an active plan.

## Tasks

### 1. Close the camera and aiming brief

- [ ] Decide Q-01 through Q-04.
- [ ] Produce one graybox camera storyboard of the same stage from top,
  high-oblique, side, near-profile, temporary cannon, and shot-follow views.
- [x] Save a non-runtime screen-direction storyboard covering high-oblique,
  side/profile, and Shot Follow composition in `DESIGN_RULES.md`.
- [ ] Select the planning-camera grammar and record it in `DECISIONS.md` and
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

- [ ] Replace coverage-based completion with one safe-settlement goal in a test
  stage.
- [ ] Confirm only after the ball remains within goal tolerances; preserve the
  visible confirmed ball and prevent later displacement.
- [ ] Provide unlimited unsuccessful launches without a timer, life, ball-stock,
  or shot-count game over.
- [ ] Clear each unsuccessful ball before the next launch while preserving every
  confirmed settled ball.
- [ ] Give the standard ball a predictable energy-losing rebound on ordinary
  hard terrain.
- [ ] Replace continuous paint behavior with one first-contact history mark per
  launch.
- [ ] Remove exact landing guidance from normal play while preserving accessible
  angle and power controls.
- [ ] Validate rapid retry and repeated-shot determinism.

### 4. Establish planning views

- [ ] Implement the selected top/oblique and side/profile planning views.
- [ ] Preserve launch setup, placed devices, confirmed goals, and selection
  across map exploration, view changes, and Shot Follow.
- [ ] Recompose inherited HUD elements around the selected views; remove
  coverage and paint-specific UI.

### 5. Build the initial course progression

- [ ] Implement legal placement, orientation, invalid state, edit rules, and
  deterministic collision response for one pad family.
- [ ] Build two direct one-goal stages that teach angle and power.
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
- [ ] Author the first few course profiles manually from intended solutions;
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
- [x] Confirmed that no gameplay, UI, scene, resource, test, script, project
  setting, or export setting was modified while establishing this specification.

## Next Steps

- Resolve the camera and aiming questions first.
- Create a low-cost multi-view graybox storyboard before any gameplay rewrite.
- Convert only the first closed task group into an active execution contract.

## Verification

- Confirm copied runtime files match Paint Mountain commit `32c0b33` before any
  future implementation commit.
- Validate Markdown lifecycle metadata, local links, and `git diff --check`.
- Do not run or claim new gameplay validation while the runtime remains the
  unchanged Paint Mountain baseline.

## Risks

- Executing this draft as if decisions were closed would allow the inherited
  target solver, coverage state, and frontal camera to choose the product.
- Building multiple devices before one direct-goal loop is proven would expand
  scope before the core learning signal is validated.
