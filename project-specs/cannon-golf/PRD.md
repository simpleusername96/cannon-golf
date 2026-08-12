---
type: spec
status: active
created: 2026-08-12
last_reviewed: 2026-08-12
canonical_for: Current product requirements for the provisional Cannon Golf project
scope: Game concept and observable player experience; implementation has not started
source: User direction recorded on 2026-08-12
related:
  - DESIGN_RULES.md
  - DECISIONS.md
  - RESEARCH.md
  - OPEN_QUESTIONS.md
  - TASKS.md
---

# Cannon Golf

## Purpose and Scope

Define the current product direction for a new Windows desktop 3D physics
puzzle. The copied Paint Mountain runtime is reusable technical material only.
This specification replaces surface coverage as the product goal, but it does
not claim that the copied code already implements the new rules.

## Summary

Cannon Golf is a deliberate, retry-driven 3D golf puzzle. The player launches
balls from a stationary cannon, reads the result, adjusts angle and power, and
settles one ball in each physical hole on the stage. A shot leaves one visible
mark at its first terrain impact. That mark is aiming history, not paintable
area, a resource, a route trail, or a score. The newest impact is darkest and
older impacts are progressively lighter. Later stages add multiple holes that
cannot all be reached from the cannon and terrain alone, so the player places a
limited bounce pad to redirect a shot. Strategic top, side, and oblique views
are more important than the inherited frontal cannon composition.

## Problem Statement

- Precision artillery games often make a miss disappear without leaving a
  useful spatial memory, or they reveal an exact trajectory and remove most of
  the estimation.
- Traditional 3D golf usually offers one ball and one hole at a time. It rarely
  combines repeated artillery estimation, several simultaneous goals, and
  player-placed trajectory devices.
- The desired game should make each miss informative while preserving the
  satisfaction of learning the physical course rather than following an exact
  landing indicator.

## Target User

- [assumption] Primary user: a solo player who enjoys compact physics puzzles,
  miniature golf, and learning through repeated attempts rather than reflexes.
- Context: short Windows desktop sessions with clear, self-contained stages.
- Motivation: turn an initially uncertain ballistic shot into a solved route by
  reading terrain, prior impacts, and device orientation.

## Job To Be Done

- When a ball cannot reach a visible hole directly, the player wants to compare
  recent impact marks, adjust the launch, and place a small number of trajectory
  devices so they can produce a physical solution they understand.

## Goals

- Make misses useful without drawing an exact predicted landing point.
- Make the terrain, holes, settled balls, impact history, and device orientation
  readable from planning cameras.
- Teach one direct hole first, then increase hole count and route dependency.
- Preserve deterministic enough physics that the same setup produces nearly
  the same first impact and outcome.
- Reuse the calm overlay HUD language and proven runtime boundaries where they
  remain compatible with the new product.

## Non-Goals

- Painting, covering, or scoring a percentage of terrain.
- Continuous paint trails after impact.
- Combat, enemies, damage, destructible terrain, or reflex shooting.
- In-flight steering.
- A broad collection of pads, balls, cannons, upgrades, currencies, or live
  service systems in the first playable slice.
- Treating the inherited frontal Aim View as the required primary composition.
- Renaming or redesigning the copied runtime before the product decisions in
  `OPEN_QUESTIONS.md` are resolved.

## User Flows

### Flow 1: Learn a direct shot

- Trigger: the player starts an introductory stage with one nearby, unobstructed
  hole and no required device.
- Main steps: inspect the course, set the cannon angle and power, fire, observe
  the ball and its first-impact mark, then correct the next launch if needed.
- Expected outcome: one ball settles in the hole and the stage clears.

### Flow 2: Solve a multi-hole course

- Trigger: the player starts a later stage with several holes at different
  heights, depths, or branches.
- Main steps: inspect the course from planning views, decide which hole to
  attempt, compare prior impact marks, place and orient a limited bounce pad
  when the natural route is insufficient, then fire and observe.
- Expected outcome: each required hole contains a settled ball at the same time
  or remains recorded as completed according to the unresolved persistence rule.

### Flow 3: Learn from a miss

- Trigger: a launched ball first contacts terrain outside the intended route.
- Main steps: the game stamps one impact mark, makes it the darkest mark, fades
  earlier marks in visual priority, and returns control without an exact landing
  callout.
- Expected outcome: the player can identify the newest miss relative to the
  hole and make a directional correction.

## Functional Requirements

### FR-1: Ballistic launch

- Requirement: the stationary cannon must launch a physical ball from explicit
  pre-shot parameters that include angle and power. The player cannot steer the
  ball in flight.
- Reason: the game is about planning and result-based correction.

### FR-2: First-impact history

- Requirement: each launch may create at most one history mark, placed at the
  ball's first valid terrain contact. Later rolling, sliding, bouncing, goal
  contact, and device contact must not paint or draw a route.
- Reason: the mark is evidence of the initial shot, not a surface-paint system.

### FR-3: Recency hierarchy

- Requirement: the newest retained impact mark must be the darkest and most
  prominent. Older retained marks must form a clear monotonic fade by recency.
- Reason: the player needs an ordered visual memory without numbered callouts.

### FR-4: Physical goal holes

- Requirement: every goal must read as a physical recess or cup in the terrain.
  A ball counts only after it enters and remains settled under the stage's goal
  tolerance.
- Reason: the closest product metaphor is 3D golf, not target shooting.

### FR-5: Multi-goal completion

- Requirement: a stage may require one or more holes. Stage completion depends
  on satisfying every required hole, not on surface coverage or score.
- Reason: the hole set is the stage objective and the main difficulty axis.

### FR-6: Difficulty progression

- Requirement: the first teaching stage must have one directly reachable hole.
  Later stages may add holes, height separation, occlusion, branch choice,
  narrower safe routes, and device-dependent solutions.
- Reason: the player should learn launch correction before route construction.

### FR-7: Placeable bounce pad

- Requirement: the first device must be a limited, player-placeable bounce pad
  whose position and orientation change the ball's outgoing trajectory.
- Reason: later stages need a controlled way to make otherwise impossible
  routes solvable.

### FR-8: Planning cameras

- Requirement: planning must support terrain-reading compositions such as
  top/oblique and side/profile views. A behind-cannon view may support launch
  drama or local aim, but must not be the only or automatically dominant view.
- Reason: height, depth, hole position, and pad orientation are difficult to
  judge from the inherited frontal composition.

### FR-9: Information restraint

- Requirement: normal play must not display an exact predicted landing point,
  a full post-launch trajectory, or a separate UI label for the prior impact.
  The terrain mark itself is the feedback.
- Reason: estimation and learning are the intended challenge.

### FR-10: Overlay HUD continuity

- Requirement: the interface may reuse Paint Mountain's warm paper-white,
  navy, blue-accent, Korean-first, edge-aligned overlay system. Coverage UI and
  paint-specific labels must not survive into the new game.
- Reason: the HUD language remains useful while the world composition and rules
  change substantially.

### FR-11: Rapid and repeatable retry

- Requirement: the player must be able to retry a shot or stage without a long
  transition, and identical launch/device state must produce materially similar
  first impacts.
- Reason: iterative correction becomes frustrating when setup is slow or the
  physics result is noisy.

## Acceptance Criteria

### AC-1: No coverage gameplay

- Applies to: FR-2, FR-5, FR-10.
- Conditions for done: a playable stage has no terrain coverage target, coverage
  meter, paint payload, or surface-percentage contribution to completion.

### AC-2: One ordered impact history

- Applies to: FR-2, FR-3, FR-9.
- Conditions for done: after three terrain-first shots, exactly three or fewer
  retained first-impact marks are visible; the third is darkest, the second is
  lighter, and the first is lightest; no contact trail or exact landing callout
  appears.

### AC-3: Direct introductory goal

- Applies to: FR-4, FR-6.
- Conditions for done: the first teaching stage contains one unobstructed hole
  with at least one direct solution that does not require a device.

### AC-4: Device-dependent later goal

- Applies to: FR-5, FR-7.
- Conditions for done: a later test stage contains multiple required holes and
  at least one certified solution that requires a placed bounce pad; the same
  hole cannot be completed from the permitted cannon states without that pad.

### AC-5: Strategic composition

- Applies to: FR-8, FR-10.
- Conditions for done: planning provides at least one top/oblique view and one
  side/profile view in which holes, settled balls, retained marks, and the
  selected pad are not hidden by persistent HUD elements.

### AC-6: Repeatability

- Applies to: FR-11.
- Conditions for done: [assumption] ten launches from identical stage, cannon,
  and pad state place the first terrain contact within one quarter of a ball
  diameter of the reference contact.

## Constraints

- Windows desktop and Godot 4.x remain the initial platform and engine.
- The copied runtime is Paint Mountain commit `32c0b33`; no runtime code was
  changed while establishing this specification.
- No new production dependency is approved.
- Current product name, camera transitions, launch parameter model, impact-mark
  retention rule, ball persistence, and device editing rules remain open.
- UI should remain Korean-first with persistent English support when
  implementation begins.

## Dependencies

- Existing Godot cannon ballistics, projectile contact, terrain, camera,
  resource, input, UI theme, localization, save, and stage-state code are
  candidate implementation inputs, not automatically accepted owners.
- Existing Paint Mountain paint coverage, target mask, predicted impact,
  horizontal mountain generation, and baked mechanism placement conflict with
  the new product and require explicit replacement decisions before editing.
- Approved local assets and licenses are retained in `assets/` and
  `docs/asset-licenses.md`.

## Risks

- Reusing class and resource boundaries without redefining their responsibility
  could preserve surface coverage under a different name.
- A purely frontal camera could make height, depth, hidden holes, and pad
  orientation unreadable.
- Too many retained marks could become noise; too few could make correction
  arbitrary.
- Player-placeable devices may trivialize direct shots unless placement area,
  count, and orientation are constrained.
- A physical ball that remains in a hole may obstruct later balls; removing it
  may weaken the multi-goal physical fantasy.
- The current exact impact prediction and target-click inverse solver may remove
  the estimation challenge if reused without a product decision.

## Success Metrics

- [assumption] In a first five-player prototype test, at least four players can
  identify the newest of three impact marks without explanation.
- [assumption] At least four of five players complete the introductory one-hole
  stage within three launches.
- [assumption] At least four of five players can explain how the bounce pad
  changed a failed shot after one device tutorial stage.
- The repeatability target in AC-6 passes before content difficulty is tuned.
- Measure these during the first playable prototype; they are validation targets,
  not release KPIs.

## Rollout or Validation Plan

- First validate one direct-hole graybox with no device.
- Add impact-history readability and test it without a trajectory preview.
- Compare planning-camera storyboards or captures before selecting the default
  camera and transition grammar.
- Add one constrained bounce pad and one two-hole graybox only after direct-shot
  correction is understandable.
- Expand content only after direct and pad-dependent solutions are deterministic.

## Open Questions Summary

- The material choices that still affect implementation are tracked in
  [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md), especially camera transitions,
  launch controls, impact fading, goal persistence, shot economy, and pad
  placement timing.
