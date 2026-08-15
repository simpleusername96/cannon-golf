---
type: spec
status: active
created: 2026-08-12
last_reviewed: 2026-08-13
canonical_for: Current product requirements for the provisional Cannon Golf project
scope: Game concept and observable player experience; three-course prototype implemented and later device progression specified
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
`cannon_golf` runtime now implements a ten-course prepared catalog with
player-chosen multi-goal routes. Later device requirements remain specified but
unimplemented.

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
preinstalled puzzle mechanism. Strategic high-oblique and per-leg cannon views
plus stable course exploration are more important than the inherited frontal
cannon composition.

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
- Main steps: inspect the complete goal field from planning views, choose a
  useful incomplete goal, choose the original start or a completed goal as the
  cannon location,
  compare prior impact marks, place and orient a limited bounce pad when the
  natural route is insufficient, then fire and observe. Confirming a goal
  preserves its ball and unlocks that plate as an optional cannon location; it
  does not choose the next goal or move the cannon automatically.
- Expected outcome: each required goal contains a confirmed settled ball. A
  confirmed ball remains visible and cannot be displaced from its completed
  goal by later shots. Confirming every required goal clears the course,
  regardless of order.

### Flow 3: Learn from a miss

- Trigger: a launched ball first contacts terrain outside the intended route,
  exits the playable course, or comes to rest outside every incomplete goal.
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
  prototype maps legal power to approximately `34.3..147.0 m/s`. This is the
  previous range multiplied by `sqrt(1.5)` so the same power percentages remain
  useful after the accepted horizontal course expansion. Ball-local gravity, damping,
  motion thresholds, and dwell thresholds are time-scaled so established course
  paths resolve at roughly twice their former pace instead of doubling spatial
  range. The player cannot steer the ball in flight.
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

- Requirement: every current-catalog goal is a shallow physical landing plate
  installed on connected terrain. It has a readable floor, a low retaining
  wall, and a broad lowered opening facing the incoming leg. The terrain below
  it provides support only; it must not be excavated into a cup or deep basin.
  A ball counts only after it remains inside the plate under the stage's
  position and safe-motion tolerances for one continuous second. Entering and
  then bouncing out cancels that settlement attempt but leaves the ball live.
  It may later re-enter the same or another incomplete goal. A live ball resolves
  only on confirmation, explicit out-of-bounds, manual retry/reset, or after it
  remains at rest outside every incomplete goal for two continuous real seconds.
  A 15-second safety timeout applies only when the ball has never recorded a
  valid surface contact; no absolute timeout applies after first contact.
- Reason: success is controlled settlement, not brief trigger contact or target
  shooting.

### FR-5: Multi-goal completion

- Requirement: a stage may require one or more goals. A course may author an
  stable goal numbering for authoring and UI, but gameplay order is free. Any
  incomplete goal may confirm. Once a goal confirms a settled ball, that ball
  remains visibly present and protected from later displacement, and that
  plate becomes an optional cannon source. The cannon never relocates
  automatically. The player may select the original start or any completed
  goal; selecting a source centers the reusable cannon on that source, aligns
  it to the plate floor when applicable, and starts that source at
  `50 / 50 / 50`. Stage completion depends only on confirming every goal.
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

- Requirement: planning supports one terrain-reading high-oblique overview and
  one true first-person view at the currently selected cannon source. The
  first-person camera looks along the real launch direction and never tracks,
  frames, or implies a next goal. Fire immediately follows the newest ball.
  `Tab` restores the exact overview or cannon state stored before follow; a
  second launch retargets follow without replacing that stored state.
  Overview interaction uses left-drag pan, right-drag orbit, the mouse wheel or
  compact actions for distance, and arrow keys for pan. Ten logarithmic
  zoom-in actions move from reset framing to a `28 m` desired minimum distance;
  six zoom-out actions reach the complete-course fit. A swept camera boom
  shortens before terrain instead of lifting the camera above an obstruction.
  Arrow keys pan, and `Home` or the compact reset action must
  restore the authored high-oblique pose. A click without drag must not refocus
  the camera. Starting any direct course exploration during Shot Follow first
  returns to planning. Launch controls remain editable in either camera mode.
  View changes and course exploration must preserve aim parameters, device
  placements, completed goals, current selection, and a stable return context.
  The high-oblique reset frames the complete presentation bounds. Cannon view
  is a fixed first-person aim pose; map exploration remains owned by overview.
- Reason: height, depth, goal position, and pad orientation are difficult to
  judge from the inherited frontal composition.

### FR-9: Information restraint

- Requirement: normal play must not display an exact predicted landing point,
  a full post-launch trajectory, or a separate UI label for the prior impact.
  The terrain mark itself is the feedback. Persistent gameplay UI is limited to
  compact horizontal aim, vertical angle, and power modules with direct
  decrement, slider, and increment input; Fire; overview; cannon view; ball
  follow; quick retry; pause; one compact completed-goals/total-goals tally; a
  compact cannon-source selector; and one restrained camera/help dock. A single shortcut panel may open on demand
  from that dock and must be collapsed by default. Course prose, progress cards,
  permanently expanded shortcut legends, feedback panels, and in-game course
  navigation do not persist over the world.
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
  Each ball resolves settlement and failure independently. A confirmation
  completes whichever incomplete goal contains that ball; the course clears
  only when no incomplete goals remain.
  Identical launch/device state must produce materially similar first impacts.
  During a live launch,
  quick retry removes only the newest active unconfirmed ball and
  immediately relaunches with the exact horizontal aim, vertical angle, and
  power. It preserves impact history, camera view, exploration state, placed
  devices, and confirmed goals. Every live ball remembers its launch source and
  setup so quick retry remains exact even if the player has since selected a
  different cannon source. Course reset remains a separate pause-menu action,
  clears course-local attempt state, and restores the original start.
- Reason: iterative correction becomes frustrating when setup is slow or the
  physics result is noisy.

### FR-12: Baseline ball bounce

- Requirement: the standard ball must have a visible, predictable baseline
  rebound on ordinary hard terrain, with energy loss sufficient for eventual
  rest. The current catalog uses one shared `2.0 m` radius for its visible
  sphere, collision sphere, muzzle clearance, goal containment, and range
  admission. It uses a dark low-gloss material that remains readable against
  the pale terrain. It must neither stick dead on ordinary impact nor gain
  unstable energy.
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
- Current catalog baseline: deterministic generation retains the connected
  triangulated mountain topology, but goals are separate physical plates over a
  shallow fitted support footprint. The first two teaching courses use a
  `315 x 180` metre baseline. Later course horizontal scale increases through
  `1.50, 1.50, 1.58, 1.65, 1.73, 1.80, 1.92, 2.03, 2.13, 2.25`, reaching
  approximately `473 x 720` metres for course 10, while
  target playable relief increases from `60` to `160` metres. Final relief must
  remain between each target and `target + 16` metres. Across the final shared
  render/collision height array, adjacent-sample slope p95 must be at most `42`
  degrees, maximum slope at most `60` degrees, and at most `3%` of samples may
  exceed `45` degrees. That relief must
  read as macro peaks, shelves, ridges, and valleys rather than local goal
  excavation. Goal elevations may rise or descend across the authored layout. The launch
  envelope remains an internal admission rule, never a visible trajectory or
  range overlay.
- Reason: the course supplies the spatial problem while the player supplies all
  route-changing mechanisms.

### FR-16: Stage solvability evidence [assumption]

- Requirement: [assumption] every shipped stage must include at least one certified solution
  witness containing the relevant launch parameters, goal attempts, and
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
- Conditions for done: the third selectable course, `deep_relay`, contains two
  numbered goals on one connected progressively scaled terrain body with at
  least `80` metres of playable-top relief. Either goal may confirm first. Its
  ball remains visible and its plate becomes selectable beside the original
  start; the cannon does not move until the player chooses it. The compact HUD
  reads `1 / 2` after either first confirmation. The
  later eleven-stage device progression remains a content target, and every
  pad-dependent goal has no certified direct solution from permitted cannon
  states.

### AC-5: Strategic composition

- Applies to: FR-8, FR-10.
- Conditions for done: planning provides one top/oblique view and one true
  cannon first-person view in which settled balls, retained marks, and the
  selected pad are not hidden by persistent HUD elements. Changing view,
  exploring the map, and returning from Shot Follow preserves the complete
  planning state and does not strand the player in an invalid framing. Firing
  follows the newest ball; `Tab` restores the exact stored pre-fire context;
  direct overview/cannon selection exits follow; and launch controls remain
  usable. Overview keeps a stable bounded focus, click-only input does not move
  it, camera collision never enters terrain, and reset fits the full course.

### AC-6: Repeatability

- Applies to: FR-11.
- Conditions for done: [assumption] ten launches from identical stage, cannon,
  and pad state place the first terrain contact within one quarter of a ball
  diameter of the reference contact.

### AC-7: Safe settlement and persistent completion

- Applies to: FR-4, FR-5, FR-12.
- Conditions for done: entering a goal at excessive speed and bouncing out does
  not complete it or remove the live ball; it may re-enter that goal or another
  incomplete goal. Remaining within tolerances for the required settle time
  completes it. A contacted ball has no absolute lifetime timeout, while
  out-of-bounds and two seconds of stable rest outside all goals resolve it. On
  `deep_relay`, either goal may confirm first without clearing the
  course. After confirmation, the ball stays visible in that goal and cannot be
  knocked out by later shots. The original start and that goal appear in the
  cannon-source selector; choosing the goal centers the cannon on its plate.
  The compact goal tally advances from `0 / 2` to `1 / 2`.

### AC-8: Unlimited recovery from misses

- Applies to: FR-11.
- Conditions for done: repeated misses never exhaust time, lives, balls, or
  shots. The player can adjust and fire a second shot while the first remains
  unresolved; a third simultaneous shot is blocked. Each ball resolves without
  corrupting the others. A first confirmation clears only a one-goal course;
  a multi-goal course clears only after every goal confirms. Quick retry during
  flight replaces only the newest active ball with identical launch origin and
  velocity while retaining all prior impact marks and planning context; at a
  a source change it restores the retried ball's recorded cannon source and
  setup. Course reset clears that attempt history and restores the original start.
  A ball that rebounds out of a settlement candidate remains one of the active
  balls until it reaches an explicit resolution condition.

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
  Every goal supplies its own shallow plate floor and low retaining wall, while
  the connected generated terrain supplies only its fitted support. Generated
  top and support-shell geometry remain inside their accepted construction and
  triangle contracts.

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
