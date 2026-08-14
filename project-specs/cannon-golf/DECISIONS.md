---
type: record
status: active
created: 2026-08-12
source: User direction recorded on 2026-08-12
scope: Accepted product and repository decisions for the provisional Cannon Golf project
related:
  - PRD.md
  - DESIGN_RULES.md
  - OPEN_QUESTIONS.md
---

# Cannon Golf Decision Log

## Context

Paint Mountain supplies a mature Godot runtime and a useful overlay design
system, but its product goal, terrain composition, paint model, prediction UI,
and generated mechanisms conflict with the new game. This log records only
choices accepted or directly implied by the user. Unresolved design choices stay
in `OPEN_QUESTIONS.md`.

## Decision

### D-001 — Surface coverage is removed

- Status: accepted.
- The new game has no objective to paint, cover, or score a terrain area.
- A visual contact stain exists only to locate prior first impacts.

### D-002 — 3D golf is the primary product metaphor

- Status: accepted.
- The player must settle balls safely in physical holes or small bounded landing
  zones. Artillery supplies the launch method; golf supplies the objective and
  correction loop.

### D-003 — Impact history replaces explicit landing feedback

- Status: accepted.
- The newest impact mark is darkest and older marks are lighter. The terrain
  mark itself is the feedback; there is no separate prior-impact callout.

### D-004 — Stage complexity grows through goal count and reachability

- Status: accepted.
- Early content starts with one easy direct goal. Later content requires several
  successful settlements and then adds goals that cannot be completed from the
  terrain and cannon alone.

### D-005 — The first placeable device is a bounce pad

- Status: accepted for the initial concept.
- The player places a pad to redirect a ball toward otherwise unreachable goals.
  It remains the first device taught in the core progression. Later accepted
  device and mechanism behavior is recorded in D-015.

### D-006 — Camera direction must move away from frontal-only planning

- Status: accepted.
- Top, side, and oblique planning compositions are required exploration areas.
  The existing frontal view and the three early concept images are only rough
  references.
- View switching, Shot Follow return, and course exploration must preserve the
  player's aim, placed devices, completed goals, and current selection.

### D-007 — Reuse the overlay system, not the existing world composition

- Status: accepted.
- Quiet Context HUD qualities may carry forward. Coverage UI, paint copy, broad
  mountain framing, and frontal hierarchy do not.

### D-008 — Seed a new repository without runtime edits

- Status: accepted and completed.
- Code, scenes, resources, assets, tests, translations, and scripts were copied
  unchanged from Paint Mountain commit `32c0b33` into a new repository.
- Paint Mountain's old product briefs and deployment workflow were not copied.
  Current game design is stored in this `project-specs/cannon-golf/` package.

### D-009 — Use `cannon-golf` only as a working slug

- Status: provisional operational decision.
- The folder and repository need a stable local identifier, but the public game
  title remains open.

### D-010 — Goal completion requires safe settlement and then persists

- Status: accepted.
- Brief contact with a goal is not success. The ball must remain inside its hole
  or bounded landing zone under the configured settlement tolerance.
- A ball that enters and bounces out before confirmation is an unsuccessful
  launch.
- After confirmation, the ball remains visibly present and cannot be knocked out
  or have its completed goal invalidated by a later shot.

### D-011 — Misses allow unlimited retry

- Status: accepted.
- The game has no timer, lives, finite ball stock, or shot limit that ends a
  stage. A miss ends only the current launch and returns the player to planning.
- An unsuccessful ball leaves active simulation when that launch resolves. A
  later launch may begin before then under the bounded concurrency in D-026;
  only confirmed settled balls persist after active launches resolve.
- Stage success occurs after every required goal is confirmed.

### D-012 — The standard ball has baseline rebound

- Status: accepted.
- Ordinary hard-surface contact must produce a visible, predictable bounce with
  energy loss. Exact restitution, friction, and settlement thresholds remain
  tuning decisions.

### D-013 — Planning and map exploration must be state-stable

- Status: accepted.
- Switching view, exploring the course, and returning from ball follow must not
  alter launch parameters, placed devices, completed goals, or current
  selection, and must return to a valid readable framing.

### D-014 — Target an eleven-stage initial progression

- Status: accepted as a content target, not a final balancing lock.
- Target approximately two direct one-goal stages, two direct stages requiring
  several successful settlements, two stages using one bounce pad, and five
  stages that progressively increase multi-pad route complexity.
- Exact terrain, goal count, and pad count within the later stages remain level
  design and balancing decisions.

### D-015 — Add damping, airflow, and local gravity as distinct later verbs

- Status: accepted.
- The damping pad is player-placeable only on a fully flat valid surface and
  removes rebound and rolling energy so a ball can settle on a flat goal.
- The airflow device is player-placeable in valid mid-air space and applies only
  a small directional correction to a passing ball.
- The gravity zone is player-placeable in valid mid-air space and makes a passing
  ball drop sharply.
- Exact force values, stock, editing rules, introduction order, stage counts,
  and placement-volume rules remain open.

### D-016 — The player places every route-changing mechanism

- Status: accepted.
- A fresh authored course contains the stationary cannon, settlement goals, and
  laterally winding terrain with elevation changes. It contains no preinstalled
  bounce pad, damping pad, airflow device, or gravity zone.
- Invisible authoring metadata such as bounds, camera bookmarks, legal placement
  regions, stock, goal tolerances, and certified solution witnesses remains
  necessary and is not considered a preinstalled course mechanism.

### D-017 — The first slice fixes horizontal aim per course

- Status: superseded by D-023 on 2026-08-13.
- Each introductory course points the stationary cannon down its authored shot
  axis. The player adjusts elevation angle and power in one-degree and
  one-percent steps; there is no horizontal aim control or exact trajectory
  preview in this slice.
- This keeps the first lesson to the two variables the owner named. Later
  courses may reopen horizontal aiming only if their topology requires it.

### D-018 — High-oblique is the default planning view

- Status: accepted for the two-course prototype.
- A whole-course high-oblique view is the default. A true side/profile view is
  the alternate. Left-drag orbits around a fixed course focus, arrow keys pan,
  and the mouse wheel or compact icon actions change planning distance. Clicking
  without dragging does not refocus. `Home` or the compact reset action restores
  the authored high-oblique view, zero pan, and default distance. Direct camera
  input during Shot Follow returns to planning before applying the input, and
  Shot Follow returns to the same stored view, pan, orbit, zoom, angle, and power.
  The follow action explicitly enters or leaves Shot Follow. Per D-027, `Tab`
  only returns to that stored planning pose and never enters follow.
- The prototype does not include a separate behind-cannon planning mode.

### D-019 — Retain five impact marks by launch order

- Status: accepted for the two-course prototype.
- Retain at most five first-contact marks. Their visual priority depends only on
  launch order: the newest is darkest and each older retained mark is lighter.
- Marks do not fade with wall-clock time and do not label or predict a landing.

### D-020 — Begin with manually authored terraced shelf courses

- Status: superseded by D-021 on 2026-08-12.
- The first two courses use connected, heightfield-like terraced shelves built
  from editor-readable resource data. They may bend laterally and change height
  but do not use caves, bridges, overhangs, disconnected islands, or devices.
- Human-authored direct-solution witnesses are verified through the real rigid
  body simulation. A custom level editor remains deferred until repeated manual
  authoring work justifies it.

### D-021 — Generate the first courses with Paint Mountain's mountain pipeline

- Status: accepted for the two-course prototype.
- Each course calls the retained route resolver and route-graph mountain
  synthesizer, adapts the generated coordinates to the Cannon Golf world, then
  passes the result through the retained top-topology and geometry builders.
- Cannon Golf selects a deterministic generation key and route-adjacent high
  point. It modifies only the local height samples needed to make a flat or
  concave goal depression before topology construction; it does not rebuild the
  mountain as authored shelves.
- The generated terrain owns the goal floor and side collision. The goal owner
  contains settlement rules plus non-colliding ring and flag markers only.
- Courses remain connected heightfield-like masses without caves, bridges,
  overhangs, disconnected islands, or preinstalled devices.

### D-022 — Keep the initial setup separate from the solution witness

- Status: accepted for the two-course prototype.
- A course's visible default horizontal aim, vertical angle, and power all start
  at `50` and must not equal or clear with its certified direct solution. The
  default is an intentional, readable miss.
- The solution witness remains course metadata for real-physics regression
  replay; it is not copied into the launch controls shown to the player.

### D-023 — Expose centered three-parameter free aim

- Status: accepted for the two-course prototype on 2026-08-13; supersedes
  D-017.
- The generated `shot axis` remains hidden world yaw from the cannon toward the
  goal. Player-facing horizontal aim is `0..100`; `50` follows that axis and the
  endpoints map linearly to `-80..+80` degrees.
- Vertical angle remains a physical `10..68` degree value and power remains
  `10..100`. Horizontal aim, vertical angle, and power visibly start at `50` on
  every course.
- Normal play exposes no trajectory, predicted impact, dome, or range overlay.

### D-024 — Admit the whole original-scale mountain through real ballistics

- Status: accepted for the two-course prototype on 2026-08-13.
- Retain the generated mountain's original `210 x 120` metre horizontal extent,
  use `0.45` vertical scale, and place the cannon `75` metres behind the route
  start. Per D-028, launch speed now spans `28..120` metres/second with
  ball-local temporal scaling that preserves the intended spatial envelope.
- Every playable terrain-top vertex and visible support-shell boundary point
  must be in front of the cannon and pass legal yaw, horizontal range, and
  reachable-height admission with at least `8` metres range, `8` degrees yaw,
  and `8` metres height-interval margin. Course construction fails closed when
  this contract is violated.
- The envelope exists only for generation and validation. It is not player UI.

### D-025 — Keep goal, retry, and normal-play UI physically direct

- Status: accepted for the two-course prototype on 2026-08-13.
- Each goal is a terrain-owned concave basin: its center is lowest, height rises
  toward the rim, and the goal node adds no physical cup. Safe settlement still
  determines success; a ball that rebounds out fails.
- Quick retry during a live shot removes only the newest active unconfirmed ball
  and immediately launches a replacement with the exact three-parameter setup.
  It preserves impact history and planning context. Course reset remains a
  separate pause-menu action and clears course-local attempt state.
- Normal play shows only the compact three-control aim panel, Fire, overview,
  side view, ball follow, quick retry, pause, and one restrained camera/help
  dock. Per D-027, one collapsed-by-default shortcut panel may open from that
  dock. Course prose, progress/status cards, permanently expanded shortcut
  legends, feedback panels, in-game course navigation, and visible full-course
  reset do not persist over the course.

### D-026 — Shot Follow does not lock the next launch

- Status: accepted for the two-course prototype on 2026-08-13.
- This decision originally made Fire start temporary Shot Follow on the newest
  ball. D-029 supersedes that automatic camera transition; the remaining
  multi-ball and non-locking rules below stay accepted.
- The prototype permits at most two simultaneous unconfirmed balls. Each owns
  its settlement and failure state; quick retry replaces only the newest one.
- The first ball to confirm safe goal settlement clears the course. All other
  unconfirmed balls are then removed so they cannot invalidate the result.

### D-027 — Aim controls are stepper-enhanced and Tab only returns

- Status: accepted for the two-course prototype on 2026-08-13.
- Horizontal aim, vertical angle, and power each use one compact module with a
  prominent value, matching keyboard pair, decrement and increment buttons, and
  a slider. Step buttons change one canonical unit and repeat while held. This
  preserves precise direct input without making the HUD read like a settings
  screen.
- One `?` action opens the sole shortcut explanation panel. The panel is
  collapsed by default, is localized, restores focus when closed, and closes on
  `Esc` before pause opens.
- `Tab` is a one-way immediate return from Shot Follow to the stored planning
  pose. It does nothing to camera mode while already planning, so it never
  re-enters follow. The explicit follow icon remains the entry/exit control.

### D-028 — Ball motion is twice-paced without doubling course range

- Status: accepted for the two-course prototype on 2026-08-13.
- The live and ballistic ball share a `0.75 m` radius. Legal launch speed doubles
  from `14..60` to `28..120 m/s`.
- To make play resolve faster without invalidating the original-scale mountain,
  the ball uses `4x` local gravity, `2x` linear/angular damping, doubled
  velocity thresholds, halved dwell thresholds, and a bounded `10 s` flight
  horizon. This is ball-local temporal scaling, not global engine time scale.
- First Ridge retains its certified solution at `50 / 46° / 72%`. Rising Bend
  retains `50 / 42°` and recertifies the adjacent power `71%`.
- Planning zoom changes distance by `22%` per wheel notch or compact action and
  remains bounded to `0.38..2.0` around the authored framed distance.

### D-029 — Fire and camera control are independent

- Status: accepted for the two-course prototype on 2026-08-13; supersedes only
  D-026's automatic Shot Follow transition.
- Fire creates the admitted ball without changing camera mode, the stored
  planning view, pan, orbit, zoom, the resulting camera transform, or an
  existing Shot Follow target.
- The compact follow action is the sole ordinary entry to Shot Follow and
  selects the newest live ball. `Tab` remains return-only. Quick retry may
  retarget its replacement only when the removed ball was already the explicit
  follow target.

### D-030 — Add the depth-first ordered longitudinal relay course

- Status: accepted on 2026-08-13.
- `deep_relay` is the third selectable course. It has two authored, ordered
  terrain-owned settlement goals on one connected `210 x 320` metre generated
  terrain body at `1.35` vertical scale. Its playable top has at least `80`
  metres of relief, and each incoming launcher-to-goal rim separation rises at
  least `25` metres.
- Only the active goal may confirm. Confirming goal 1 preserves its settled
  ball, removes all other unconfirmed balls, relocates the one reusable launcher
  to a terrain-adjacent relay anchor beside that completed basin and toward goal
  2, resets only the visible launch controls to `50 / 50 / 50`, and activates
  goal 2. Retry preserves this checkpoint and the edited current-leg setup;
  course reset returns to leg 1. Only goal 2 confirmation clears the course.
- Each relay leg has its own real-physics admission and solution witness. The
  default planning and reset frame show the current leg; bounded exploration and
  course selection preview can show the complete route. Active, future, and
  confirmed goals are distinguished in the world by flag height, rim-marker
  rhythm, and the retained confirmed ball, with color only as a secondary cue.
- Relay union admission excludes only the horizontal `30` metre launch-safety
  footprint around each later, terrain-sited relay anchor. That local supporting
  ground is not a flight target. Goals and intervening terrain corridors retain
  the `8` metre range, `8` degree yaw, and `8` metre height-margin guards, and
  all visible terrain outside those exact footprints must pass at least one
  leg's envelope.
- D-024 remains scoped to the original two `210 x 120` metre courses and their
  whole-terrain single-launcher admission rule. This decision adds no constraint
  to those retained courses and preserves their behavior as historical baseline.

### D-031 — Center relay launchers and show a compact goal tally

- Status: accepted on 2026-08-13; supersedes the conflicting relay-anchor and
  no-counter clauses in D-025 and D-030.
- After an intermediate goal confirms, the reusable launcher's horizontal
  position is the exact center of that completed goal. Its vertical position is
  aligned to the generated goal surface. It is not authored as a separate relay
  anchor beside the goal.
- Normal play shows one small edge-aligned completed-goals/total-goals tally.
  It is status text, not a progress card, and does not add course prose or a
  second control panel.
- A centered launcher necessarily occupies the bottom of a concave goal. The
  local `30` metre support footprint remains excluded from whole-terrain union
  admission. Outside that footprint, every visible terrain point must remain
  inside at least one leg's real ballistic interval with the full `8` metre
  range and `8` degree yaw guards; the prior additional `8` metre whole-terrain
  height guard is reduced to a nonnegative height margin. Authored goal and
  launcher-to-goal corridor validation retain the full height guard.

### D-032 — Resolve course geometry from constraints and certify it offline

- Status: accepted on 2026-08-14; expands D-021 from the initial courses and
  resolves Q-20 for direct shots and Q-22 for course authoring.
- A course has three distinct representations. A `Course Recipe` contains the
  generation seed window, goal count and order, route and lateral placement
  regions, relative rim bands, bounded goal dimensions, semantic landform roles,
  and difficulty targets. It does not contain final goal coordinates or a copied
  solution shot. A sealed `Resolved Course Plan` contains the selected launcher,
  goal, terrain adjustment and rejection metrics. A `Prepared Course` contains
  the immutable runtime geometry, collision, resolved legs and physics
  certificate.
- The offline resolver uses bounded feedback, not a one-way geometry pass:
  launcher state → analytic ballistic reachability → goal candidates → bounded
  terrain conditioning → final geometry/admission validation → real Godot
  physics certification. A failed later leg backtracks to an earlier candidate.
  It never changes the accepted ballistics, settlement, connectivity, checkpoint
  or admission rules to obtain a pass.
- Analytic ballistics is only a cheap candidate filter. The built collision scene
  is the solvability authority. The certifier repeats the center witness twice
  and tests the six axial one-unit neighbors across horizontal aim, elevation
  and power. The center must pass twice; at least four neighbors must pass, with
  at least one passing neighbor on each control axis. `50 / 50 / 50` remains a
  separately replayed miss. Device-placement tolerance remains unresolved until
  those mechanics are accepted.
- Search is deterministic and bounded: no more than 180 analytic goal/terrain
  candidates per leg, a beam of four partial multi-leg plans, and twelve exact
  physics finalists per course. An exhausted domain rejects the recipe with
  metrics; it does not fall back to a hand-placed goal or an unbounded search.
- Bakes and certificates use the pinned Godot `4.7.1` build, explicit
  `GodotPhysics3D`, 60 Hz ticks and recorded relevant settings. Same inputs must
  reproduce the resolved-plan and semantic artifact hashes. Godot physics is not
  treated as bit-exact across machines or engine changes; affected artifacts are
  recertified by outcome and tolerance instead of trajectory hash.
- Runtime selection, preview and gameplay consume only a valid prepared artifact.
  They never run the resolver, terrain generator or solution search.

### D-033 — Construct the first ten courses trajectory-first under one minute

- Status: accepted on 2026-08-14; supersedes D-032's candidate-search and
  mandatory physics-certificate requirements for the first ten-course catalog.
- Each leg starts from one of a small fixed set of deterministic intended shot
  setups. The generator calculates the flight first, chooses a descending goal
  point, and then makes one connected terrain mesh below the protected flight
  corridor. It does not generate a mountain repeatedly until a shot happens to
  fit.
- The terrain generator adds retaining goal bowls and deterministic peaks,
  shelves, valleys, and basins only after every launcher, intended trajectory,
  and goal is fixed. Goal elevation may rise or fall between legs.
- Each course has a measured hard generation limit of 60 seconds. An overrun
  rejects and stops the bake; it does not widen the search or run a longer
  certifier.
- Preview and gameplay still load an immutable identity-checked prepared
  artifact. The artifact records the construction algorithm version and intended
  setups. Runtime course generation remains forbidden.
- Acceptance for this implementation is intentionally narrow: the game starts
  and all ten prepared courses load and instantiate. Exhaustive solution replay,
  neighbor robustness certification, and rendered tuning are not required by
  this decision.

## Rationale

- Separating impact memory from painting prevents the inherited coverage system
  from defining the new product by accident.
- The golf metaphor explains holes, settling, course reading, and iterative
  correction more directly than a shooter metaphor.
- Separating launch failure from stage failure permits high difficulty without
  punishing experimentation.
- Persistent confirmed goals make multi-goal progress legible; baseline rebound
  makes controlled settlement a real part of the puzzle.
- Multiple planning angles are necessary because later solutions depend on both
  height and lateral pad orientation, while stable transitions keep the player
  from losing a carefully prepared solution.
- The staged content target teaches one variable set at a time before combining
  several pads.
- The additional mechanics remain distinct because they respectively redirect
  on contact, remove energy on a flat surface, bend a route slightly in mid-air,
  and force a sharp local vertical drop.
- An unchanged technical baseline makes later reuse decisions auditable: any
  runtime divergence will appear in future commits rather than being hidden in
  project creation.
- Excluding the old product briefs prevents competing canonical specifications.

## Consequences

- The current executable opens the isolated two-course Cannon Golf prototype.
  Retained legacy scenes still behave as Paint Mountain when instantiated
  directly and remain source-history material.
- Paint, coverage, predicted-impact, terrain-generation, mechanism-placement,
  HUD, and stage-result owners must be classified as reuse, adaptation, or
  retirement before coding.
- Camera and input decisions must be resolved before the first gameplay rewrite;
  otherwise the copied frontal target solver may dictate the experience.
- Stage-result logic must distinguish an unsuccessful launch from a cleared
  settlement goal and must make confirmed goals irreversible within the stage.
- HUD and save state must not assume a timer, finite shot stock, or later
  displacement of confirmed balls.
- Placement and course-state owners must distinguish surface pads, mid-air
  airflow and gravity placement instead of treating every mechanism as the same
  placeable object.
- New reference images must demonstrate top, side, or mixed planning rather than
  refine the current frontal mockups.

## Alternatives

- Full repository clone including Paint Mountain briefs: rejected because it
  would leave the old coverage game as a competing source of truth.
- Start from an empty Godot project: rejected for now because the cannon,
  projectile, terrain, camera, UI, localization, save, and test infrastructure
  are valuable candidates.
- Keep painting as a secondary score: rejected by the user; impact visualization
  is not a painting objective.
- Approve all three early concept images: rejected; they are only roughly useful
  and preserve too much frontal composition.
