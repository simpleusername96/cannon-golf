---
type: spec
status: active
created: 2026-08-12
last_reviewed: 2026-08-13
canonical_for: Current product requirements for the provisional Cannon Golf project
scope: Game concept and observable player experience; two-course direct-shot prototype implemented
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
This specification replaces surface coverage as the product goal. The isolated
`cannon_golf` runtime now implements the two-course direct-shot slice; later
multi-goal and device requirements remain specified but unimplemented.

## Summary

Cannon Golf is a deliberate, retry-driven 3D golf puzzle. The player launches
balls from a stationary cannon, reads the result, adjusts horizontal aim,
vertical angle, and power, and
settles one ball in each goal on the stage. A goal may be a physical hole or a
small bounded landing zone, but it counts only after the ball remains safely at
rest. A shot leaves one visible mark at its first terrain impact. That mark is
aiming history, not paintable area, a resource, a route trail, or a score. The
newest impact is darkest and older impacts are progressively lighter. Later
stages add multiple goals that cannot all be reached from the cannon and terrain
alone, so the player places limited bounce pads to redirect shots. After the
core bounce-pad progression, the accepted expansion vocabulary adds a flat
damping pad, a mid-air airflow device, and a bounded gravity zone. All four
mechanism families are placed by the player; authored courses contain no
preinstalled puzzle mechanism. Strategic
top, side, and oblique views and stable course exploration are more important
than the inherited frontal cannon composition.

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

- When a ball cannot reach a visible goal directly, the player wants to compare
  recent impact marks, adjust the launch, and place a small number of trajectory
  devices so they can produce a physical solution they understand.

## Goals

- Make misses useful without drawing an exact predicted landing point.
- Make the terrain, goals, settled balls, impact history, and device orientation
  readable from planning cameras.
- Preserve horizontal aim, vertical angle, power, placed devices, completed
  goals, and selected context
  while the player changes view or explores the course.
- Teach direct one-goal shots first, then increase goal count and route
  dependency.
- Preserve deterministic enough physics that the same setup produces nearly
  the same first impact and outcome.
- Allow unlimited retries so difficulty comes from learning the course rather
  than exhausting time, lives, balls, or shot stock.
- Reuse the calm overlay HUD language and proven runtime boundaries where they
  remain compatible with the new product.

## Non-Goals

- Painting, covering, or scoring a percentage of terrain.
- Continuous paint trails after impact.
- Combat, enemies, damage, destructible terrain, or reflex shooting.
- In-flight steering.
- Timers, finite shot stock, lives, or a score threshold that can fail a stage.
- A broad collection of pads, balls, cannons, upgrades, currencies, or live
  service systems in the first playable slice.
- Treating the inherited frontal Aim View as the required primary composition.
- Renaming or redesigning the copied runtime before the product decisions in
  `OPEN_QUESTIONS.md` are resolved.

## User Flows

### Flow 1: Learn a direct shot

- Trigger: the player starts an introductory stage with one nearby, unobstructed
  goal and no required device.
- Main steps: inspect the course, set horizontal aim, vertical angle, and power,
  fire, observe the ball and its first-impact mark, then immediately return to
  the stored planning view, correct the setup, and launch again if needed.
- Expected outcome: one ball settles safely in the goal and the stage clears.

### Flow 2: Solve a multi-goal course

- Trigger: the player starts a later stage with several goals at different
  heights, depths, or branches.
- Main steps: inspect the course from planning views, decide which goal to
  attempt, compare prior impact marks, place and orient a limited bounce pad
  when the natural route is insufficient, then fire and observe.
- Expected outcome: each required goal contains a confirmed settled ball. A
  confirmed ball remains visible and cannot be displaced from its completed
  goal by later shots.

### Flow 3: Learn from a miss

- Trigger: a launched ball first contacts terrain outside the intended route,
  leaves a goal before settling, exits the playable course, or comes to rest
  outside every incomplete goal.
- Main steps: the game stamps one impact mark, makes it the darkest mark, fades
  earlier marks in visual priority, and returns control without an exact landing
  callout.
- Expected outcome: only that launch is unsuccessful. The player can identify
  the newest miss relative to the goal and retry without losing the stage.

## Functional Requirements

### FR-1: Ballistic launch

- Requirement: the stationary cannon must launch a physical ball from three
  explicit pre-shot parameters: horizontal aim `0..100`, physical vertical
  angle `10..68` degrees, and power `10..100`. Horizontal aim `50` follows the
  generated course shot axis; the endpoints map linearly to `-80..+80` degrees
  from that axis. All three visible values start at `50` on every course. The
  player cannot steer the ball in flight.
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

### FR-4: Settlement goals

- Requirement: a goal must be either a physical recess or cup, or a small
  bounded landing zone with a readable physical footprint. A ball counts only
  after it remains inside the goal under the stage's position, speed, and
  settle-duration tolerances. Entering and then bouncing out is an unsuccessful
  launch. A recessed goal may have a flat or concave floor, but its interior
  must not rise toward the center and eject a safely arriving ball. The first
  two courses use a terrain-owned concave basin with no separate physical cup.
- Reason: success is controlled settlement, not brief trigger contact or target
  shooting.

### FR-5: Multi-goal completion

- Requirement: a stage may require one or more goals. Once a goal confirms a
  settled ball, that ball remains visibly present and protected from later
  displacement. Stage completion depends on confirming every required goal,
  not on surface coverage or score.
- Reason: persistent goal occupancy makes progress legible and prevents later
  shots from invalidating an already completed route.

### FR-6: Difficulty progression

- Requirement: the initial course targets eleven stages: two simple one-goal
  stages solved directly with angle and power, two direct stages that require
  several successful goal settlements, two stages whose certified solution uses
  one bounce pad, and five stages that progressively increase the required or
  available bounce-pad count. Exact terrain and pad counts within the last five
  stages remain balancing decisions.
- Reason: the player should learn one launch, then repeated settlement, then one
  pad, then multi-pad route construction.

### FR-7: Placeable bounce pad

- Requirement: the first device must be a limited, player-placeable bounce pad
  whose position and orientation change the ball's outgoing trajectory.
- Reason: later stages need a controlled way to make otherwise impossible
  routes solvable.

### FR-8: Planning cameras

- Requirement: planning must support terrain-reading compositions such as
  top/oblique and side/profile views. A behind-cannon view may support launch
  drama or local aim, but must not be the only or automatically dominant view.
  Firing temporarily follows the newest ball. `Tab`, the compact follow action,
  overview, or side view must immediately restore the stored planning pose while
  balls remain live. Direct planning interaction uses left-drag to orbit around
  the current fixed course focus, the mouse wheel or compact zoom actions to
  change distance, arrow keys to pan, and `Home` or the compact reset action to
  restore the authored high-oblique pose. A click without drag must not refocus
  the camera. Starting any direct course exploration during Shot Follow first
  returns to planning. Launch controls remain editable in either camera mode.
  View changes and course exploration must preserve aim parameters, device
  placements, completed goals, current selection, and a stable return context.
- Reason: height, depth, goal position, and pad orientation are difficult to
  judge from the inherited frontal composition.

### FR-9: Information restraint

- Requirement: normal play must not display an exact predicted landing point,
  a full post-launch trajectory, or a separate UI label for the prior impact.
  The terrain mark itself is the feedback. Persistent gameplay UI is limited to
  compact horizontal aim, vertical angle, and power controls, Fire, overview,
  side view, ball follow, quick retry, pause, and one restrained icon-only camera
  zoom/reset dock. Course prose, progress cards, shortcut legends, feedback
  panels, and in-game course navigation do not persist over the world.
- Reason: estimation and learning are the intended challenge.

### FR-10: Overlay HUD continuity

- Requirement: the interface may reuse Paint Mountain's warm paper-white,
  navy, blue-accent, Korean-first, edge-aligned overlay system. Coverage UI and
  paint-specific labels must not survive into the new game.
- Reason: the HUD language remains useful while the world composition and rules
  change substantially.

### FR-11: Rapid and repeatable retry

- Requirement: the player must be able to retry a shot or stage without a long
  transition or consumable limit. A miss never creates a timer, life, ball-stock,
  or shot-count game over. Aim controls become available immediately after a
  launch, and the prototype permits up to two unconfirmed balls in active
  simulation so an obviously failed attempt does not block the next launch.
  Each ball resolves settlement and failure independently; the first confirmed
  settlement wins and removes other unconfirmed balls. Identical launch/device
  state must produce materially similar first impacts. During a live launch,
  quick retry removes only the newest active unconfirmed ball and
  immediately relaunches with the exact horizontal aim, vertical angle, and
  power. It preserves impact history, camera view, exploration state, placed
  devices, and confirmed goals. Course reset remains a separate pause-menu
  action and clears course-local attempt state.
- Reason: iterative correction becomes frustrating when setup is slow or the
  physics result is noisy.

### FR-12: Baseline ball bounce

- Requirement: the standard ball must have a visible, predictable baseline
  rebound on ordinary hard terrain, with energy loss sufficient for eventual
  rest. It must neither stick dead on ordinary impact nor gain unstable energy.
- Reason: bounce is part of the aiming challenge and makes safe settlement a
  meaningful success condition.

### FR-13: Damping pad and airflow device

- Requirement: a player-placeable damping pad must work only on a valid fully
  flat surface and must reduce rebound and rolling energy so a ball can settle on
  a flat goal. A player-placeable airflow device must support valid mid-air
  placement and apply a small, bounded directional force that bends the ball's
  route without becoming a second sharp redirector.
- Reason: the damping pad solves controlled stopping where a recess cannot, while
  airflow adds a readable fine-correction verb between launch and contact.

### FR-14: Gravity zone

- Requirement: the player must be able to place a bounded gravity zone in a
  valid empty-air volume. A ball that enters it must receive a strong downward
  acceleration and drop sharply while affected. The zone must be spatially
  readable and must not change gravity for the whole stage.
- Reason: a local drop creates vertical route choices without replacing the
  cannon's ordinary ballistic rules everywhere else.

### FR-15: Authored course boundary

- Requirement: visible authored gameplay geometry must consist of the stationary
  cannon, one or more settlement goals, and terrain that can bend laterally and
  vary in elevation. Bounce pads, damping pads, airflow devices, and gravity
  zones must not be preinstalled. A stage may still store non-world metadata
  such as play bounds, camera bookmarks, goal tolerances, per-device stock,
  placement legality, and certified solution witnesses.
- Prototype baseline: the first two courses must use Paint Mountain's retained
  route-graph mountain height synthesis, topology, and geometry pipeline at its
  original `210 x 120` metre horizontal extent. A course may select deterministic
  generation inputs, use `0.45` vertical scale, place the cannon `75` metres
  behind the route start, then lower only the samples around a route-adjacent
  high point to form its goal. The complete playable terrain top and visible
  support-shell boundary must fit in front of the cannon within its legal yaw,
  range, and reachable-height envelope with the accepted margins. That depressed
  terrain remains the sole physical goal floor and wall; goal rings and flags
  are non-colliding markers. The launch envelope is an internal admission rule,
  never a visible trajectory or range overlay.
- Reason: the course supplies the spatial problem while the player supplies all
  route-changing mechanisms.

### FR-16: Stage solvability evidence [assumption]

- Requirement: [assumption] every shipped stage must include at least one certified solution
  witness containing the relevant launch parameters, ordered goal attempts, and
  player device placements. Certification must replay the real physics and pass
  safe-settlement, bounds, placement, and state-persistence rules. It must not
  rely only on geometric reachability or an analytical trajectory estimate.
- Reason: continuous launch and 3D placement variables make visual inspection or
  terrain-generation constraints insufficient proof that a stage can be solved.

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

### AC-3: Direct introductory goals

- Applies to: FR-4, FR-6.
- Conditions for done: the first two teaching stages each contain one
  unobstructed goal with at least one direct horizontal-aim, vertical-angle, and
  power solution that does not require a device. Their visible `50 / 50 / 50`
  defaults remain misses and are separate from certified solution metadata.

### AC-4: Initial course progression

- Applies to: FR-5, FR-7.
- Conditions for done: two following stages require several direct settlements
  without a pad; two following stages each have a certified solution that uses
  one pad; five further stages increase multi-pad route complexity. Every
  pad-dependent goal has no certified direct solution from permitted cannon
  states.

### AC-5: Strategic composition

- Applies to: FR-8, FR-10.
- Conditions for done: planning provides at least one top/oblique view and one
  side/profile view in which goals, settled balls, retained marks, and the
  selected pad are not hidden by persistent HUD elements. Changing view,
  exploring the map, and returning from Shot Follow preserves the complete
  planning state and does not strand the player in an invalid framing. After
  firing, `Tab` or the follow icon restores that framing without waiting for the
  ball to resolve, direct drag/wheel exploration also restores planning, and the
  launch controls remain usable. Orbit keeps a fixed course focus, click-only
  input does not move it, and camera reset returns to a valid authored frame.

### AC-6: Repeatability

- Applies to: FR-11.
- Conditions for done: [assumption] ten launches from identical stage, cannon,
  and pad state place the first terrain contact within one quarter of a ball
  diameter of the reference contact.

### AC-7: Safe settlement and persistent completion

- Applies to: FR-4, FR-5, FR-12.
- Conditions for done: entering a goal at excessive speed and bouncing out does
  not complete it; remaining within its tolerances for the required settle time
  does. After confirmation, the ball stays visible in that goal and cannot be
  knocked out by later shots.

### AC-8: Unlimited recovery from misses

- Applies to: FR-11.
- Conditions for done: repeated misses never exhaust time, lives, balls, or
  shots. The player can adjust and fire a second shot while the first remains
  unresolved; a third simultaneous shot is blocked. Each ball resolves without
  corrupting the others, and the first confirmed settlement clears the stage.
  Quick retry during flight replaces only the newest active ball with identical
  launch origin and velocity while retaining all prior impact marks and planning
  context; course reset clears that attempt history.

### AC-9: Predictable baseline rebound

- Applies to: FR-12.
- Conditions for done: an ordinary hard-surface impact above the configured
  minimum produces a visible rebound, repeated identical impacts remain within
  the repeatability tolerance, and successive rebounds lose energy until rest.

### AC-10: Distinct player-placed mechanics

- Applies to: FR-13, FR-14.
- Conditions for done: a damping pad placed on a fully flat landing surface
  reduces rebound and roll enough to enable controlled settlement; the same pad
  is invalid on a slope. An airflow device can be placed in a valid empty-air
  volume and produces only a modest repeatable route correction. Entering a
  visible gravity zone produces a sharp local drop without changing the ball's
  gravity before entry or after exit. All four mechanism families begin in
  player inventory or placement mode rather than already existing in the world.

### AC-11: Course purity

- Applies to: FR-15.
- Conditions for done: loading a fresh stage creates no route-changing mechanism
  in the course; only terrain, cannon, and goals are visible gameplay objects.
  For the first two courses, the terrain and goal collision must come from the
  retained generated-mountain topology rather than an authored shelf mesh or a
  separate physical cup. Their generated top and support shell pass the accepted
  whole-terrain launch-envelope admission and margin checks.

### AC-12: Certified solution [assumption]

- Applies to: FR-16.
- Conditions for done: the stage's certified witness can place only the allowed
  stock, passes every placement rule, settles all required balls, and continues
  to pass the approved robustness perturbation test.

## Constraints

- Windows desktop and Godot 4.x remain the initial platform and engine.
- The copied runtime baseline is Paint Mountain commit `32c0b33`. The playable
  two-course prototype is isolated under `src/cannon_golf/`,
  `scenes/cannon_golf/`, and `resources/cannon_golf/`; retained legacy owners
  remain available as source history.
- No new production dependency is approved.
- Current product name, exact camera transition grammar beyond the accepted
  prototype views, goal-order rule, and device editing rules remain open. Exact
  damping, airflow, and gravity values, inventory limits, introduction stages,
  later-course terrain variation, and solution robustness tolerances also
  remain open. The first two courses' generated heightfield topology, impact
  retention, and ordinary rebound baseline are accepted prototype decisions.
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
- A purely frontal camera could make height, depth, hidden goals, and pad
  orientation unreadable.
- Too many retained marks could become noise; too few could make correction
  arbitrary.
- Player-placeable devices may trivialize direct shots unless placement area,
  count, and orientation are constrained.
- Airflow and gravity volumes may become hard to judge unless their boundaries
  and active direction are readable from both planning camera families.
- A confirmed ball must remain visible without becoming an accidental obstacle
  that invalidates later certified routes.
- The current exact impact prediction and target-click inverse solver may remove
  the estimation challenge if reused without a product decision.

## Success Metrics

- [assumption] In a first five-player prototype test, at least four players can
  identify the newest of three impact marks without explanation.
- [assumption] At least four of five players complete the introductory one-goal
  stage within three launches.
- [assumption] At least four of five players can explain how the bounce pad
  changed a failed shot after one device tutorial stage.
- The repeatability target in AC-6 passes before content difficulty is tuned.
- Measure these during the first playable prototype; they are validation targets,
  not release KPIs.

## Rollout or Validation Plan

- First validate two direct one-goal grayboxes with no device.
- Add impact-history readability and test it without a trajectory preview.
- Compare planning-camera storyboards or captures before selecting the default
  camera and transition grammar.
- Validate two repeated-settlement stages before introducing devices.
- Add two one-pad stages only after direct-shot correction is understandable.
- Expand through five multi-pad stages only after direct and one-pad solutions
  are deterministic and planning-state transitions are stable.
- Prototype damping, airflow, and gravity-zone stages only after the core
  bounce-pad progression is readable; their exact stage counts are not set.
- [assumption] Author early stages manually from an intended solution, save solution
  witnesses, and automate replay validation before attempting broad procedural
  course generation.

## Open Questions Summary

- The material choices that still affect implementation are tracked in
  [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md), especially camera transitions,
  launch controls, impact fading, goal order, bounce tuning, pad behavior,
  placement timing, expansion-mechanic tuning, introduction order, terrain
  topology, editor workflow, and solution robustness.
