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

- Status: accepted; its side-view requirement is superseded by D-034.
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
- A ball that enters and bounces out before confirmation has not completed the
  goal, but the launch remains active under D-040.
- After confirmation, the ball remains visibly present and cannot be knocked out
  or have its completed goal invalidated by a later shot.

### D-011 — Misses allow unlimited retry

- Status: accepted.
- The game has no timer, lives, finite ball stock, or shot limit that ends a
  stage. A miss ends only the current launch and returns the player to planning.
- An unsuccessful ball leaves active simulation only when that launch reaches a
  resolution condition in D-040. A
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

- Status: accepted for the two-course prototype; its goal-ownership clauses are
  superseded by D-035.
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

- Status: accepted for the two-course prototype on 2026-08-13; its side-view
  control is superseded by D-034 and its terrain-basin goal is superseded by
  D-035.
- Each goal is a terrain-owned concave basin: its center is lowest, height rises
  toward the rim, and the goal node adds no physical cup. Safe settlement still
  determines success; a ball that rebounds out fails.
- Quick retry during a live shot removes only the newest active unconfirmed ball
  and immediately launches a replacement with the exact three-parameter setup.
  It preserves impact history and planning context. Course reset remains a
  separate pause-menu action and clears course-local attempt state.
- Normal play shows only the compact three-control aim panel, Fire, overview,
  cannon view, ball follow, quick retry, pause, and one restrained camera/help
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

### D-034 — Use terrain-safe oblique and cannon planning views

- Status: accepted on 2026-08-14; supersedes every prior side/profile runtime
  requirement in D-006, D-018, and D-025 plus D-028's `22%` planning-zoom step.
- The selectable planning presets are the whole-course high-oblique view and a
  per-leg behind-cannon view derived from the active launcher and shot axis.
  Key and HUD action `1` select oblique; `2` selects cannon. A relay transition
  recomputes the cannon preset for its new launcher without changing aim or
  firing.
- One wheel notch or compact zoom action changes planning distance by `10%`.
  Left-drag pan, right-drag orbit, and arrow pan use restrained response values.
- Every planning focus, desired pose, and interpolated pose is conditioned
  against the prepared terrain height. Free exploration remains available, but
  the camera cannot enter or cross the terrain.
- Fire remains camera-independent and Shot Follow remains explicit per D-029.

### D-035 — Use physical surface goal plates and progressive macro terrain

- Status: accepted on 2026-08-14; supersedes D-021 and D-025 goal ownership,
  D-028's `0.75 m` current ball radius, and fixed late-course size/relief clauses.
- Each current-catalog goal owns a shallow physical floor, low segmented wall,
  broad incoming opening, settlement containment, world marker, and visual
  state. The generated terrain owns only a fitted support `0.18 m` below the
  plate and must not form a goal basin or retaining wall.
- Safe settlement requires one continuous second inside the active plate under
  the existing safe linear/angular motion thresholds. Brief contact or escape
  remains unsuccessful. Relay launchers move to the completed plate's exact
  horizontal center and floor elevation.
- The physical and visual ball radius is `1.0 m`; the material is dark navy and
  low gloss. Every muzzle, trajectory, containment, and clearance consumer uses
  the same shared radius.
- The ten-course horizontal scale progresses through
  `1.00, 1.00, 1.05, 1.10, 1.15, 1.20, 1.28, 1.35, 1.42, 1.50`; minimum relief
  progresses through `60, 65, 80, 90, 100, 112, 124, 136, 148, 160` metres.
  Macro peaks, shelves, ridges, and valleys own that relief. Goal support
  conditioning must not be used to satisfy it.

### D-036 — Let players choose goal order and cannon source

- Status: accepted on 2026-08-14; supersedes D-030 and D-031 ordered-progression
  clauses, D-034's per-leg target framing, and D-035's active-plate wording.
- Goal indices remain stable authoring and UI identities, not gameplay order.
  Every incomplete goal may settle a ball at any time. A course clears only
  when all goals are confirmed; there is no active, future, or next goal in
  normal play.
- Confirming a goal freezes its ball, unlocks that plate as a cannon source, and
  updates the compact tally. It does not move the cannon. The player chooses
  between the original start and any completed goal through one compact
  edge-aligned selector. A selected goal source centers the reusable cannon on
  the plate floor and resets its setup to `50 / 50 / 50`.
- Each cannon source has a stable base yaw toward the course center rather than
  toward a selected goal. The cannon camera shows only the selected source's
  local base-aim context and never frames or implies a target. The high-oblique
  view remains the complete-course planning view.
- Source selection may occur while earlier balls remain live. Each live ball
  records its source and three launch values, so quick retry restores the exact
  recorded launch rather than inheriting a later source selection.

### D-037 — Compact the front end and use map-independent close inspection

- Status: accepted on 2026-08-15; supersedes only D-034's fixed `10%` planning
  zoom step and D-035's `1.0 m` current-catalog ball radius.
- The main menu keeps one panel. Its title wraps as `CANNON` over `GOLF`, and
  the panel and four existing actions narrow around that content. Course rows
  remain one scrollable list; normal rows have no floating shadow, and selected
  and keyboard-focus states use one restrained left-edge accent rather than
  stacked all-side outlines.
- The physical and visual ball radius is `2.0 m`. Mesh, collider, muzzle,
  trajectory, goal containment, and construction clearance share that value.
  Existing goal radii remain unchanged; plate walls and incoming openings retain
  enough physical height and width for the larger sphere.
- High-oblique zoom has twelve equal control steps from default to a `14 m`
  focus-to-camera close-inspection distance on every course and six steps from
  default to the complete-course overview. The distance response is logarithmic.
- The overview camera samples a small footprint around every desired and
  interpolated pose and stays at least `2.0 m` above the highest available
  prepared-terrain sample. Cannon view, pan, orbit, reset, Shot Follow, and fire
  independence remain unchanged.

### D-038 — Use collision-boom overview, cannon first-person, and automatic follow

- Status: accepted on 2026-08-15; supersedes D-029's explicit-only follow,
  D-034's behind-cannon/end-point-lift clauses, and D-037's `14 m` overview
  endpoint and fire-independence clauses.
- Camera states are overview, cannon first-person, and transient Shot Follow.
  Overview owns bounded pan, orbit, zoom, and reset. Cannon first-person stays
  at the selected source and looks along its real launch direction; it never
  frames a target or next goal.
- Overview uses a terrain-safe pivot and a swept camera boom. Ten logarithmic
  zoom-in actions reach a `28 m` desired minimum; six zoom-out actions reach the
  complete-course fit. A blocked boom shortens or preserves its last valid pose
  and never resolves by lifting the camera into the sky.
- Fire immediately follows the newest ball. The first follow stores the exact
  preceding overview or cannon state; later shots retarget without overwriting
  it. `Tab` and direct view selection restore planning, and resolved shots return
  automatically after a short result hold.
- White or near-white world-ground patches are retired. The physical goal flag
  remains at each plate. A separate thick matte downward 3D arrow replaces only
  the thin cyan airborne stem/diamond and hides after confirmation.

### D-039 — Separate horizontal course scale, readable object scale, and ballistic reach

- Status: accepted on 2026-08-15; supersedes D-035's horizontal-scale sequence
  and D-028's `28..120 m/s` speed range. It does not change D-035's relief
  sequence or D-037's `2.0 m` ball radius.
- Stretch the ten current courses horizontally by `1.5` without multiplying
  height. Their explicit horizontal scales are
  `1.50, 1.50, 1.58, 1.65, 1.73, 1.80, 1.92, 2.03, 2.13, 2.25`; minimum relief
  remains `60, 65, 80, 90, 100, 112, 124, 136, 148, 160` metres. The larger
  horizontal run makes the same height hierarchy less steep.
- Multiply canonical launch-speed endpoints by `sqrt(1.5)`, to approximately
  `34.3..147.0 m/s`, so an equivalent power percentage retains comparable
  horizontal reach. Keep ball radius at `2.0 m`; increase only the cannon's
  visual scale from `1.6` to `2.0` for overview readability without moving its
  physical launch origin.
- Replace the launcher-attached direction wedge with an aim halo that floats
  slightly above the base. A horizontal ring and perimeter tick show yaw; a
  laterally offset dotted vertical arc and bead show elevation. The halo remains
  visible in overview/planning and cannon first-person view and must not create a
  second-barrel silhouette.

### D-040 — Separate settlement candidacy, live-ball resolution, and terrain slope limits

- Status: accepted on 2026-08-15; clarifies D-010 and D-011 and supersedes
  D-039's halo-hiding clause and its assumption that horizontal stretch alone
  makes every local landform acceptably gentle.
- Goal overlap is a settlement candidate. Exiting before confirmation clears the
  candidate, its dwell, and temporary settlement drag but leaves the ball live;
  it may enter the same or another incomplete goal later.
- Resolve a live ball on confirmed settlement, explicit out-of-bounds, manual
  retry/reset, or two continuous real seconds of stable rest outside every
  incomplete goal. A 15-second leak guard applies only before the first valid
  surface contact. A contacted ball has no absolute lifetime timeout.
- Keep the floating yaw-and-elevation halo visible in both planning views. Its
  geometry is unshaded, high contrast, shadow-free, and thick enough in ordinary
  captures; a narrow no-depth-tested accent may preserve readability.
- Keep D-039's horizontal extents, object scale, and ballistic range. Instead of
  another global expansion, widen semantic landform footprints with course
  scale, remove hard multi-metre terrace quantization, constrain filtering around
  start/goal supports, and certify the final shared render/collision height array.
  Each course must have p95 adjacent-sample slope at most `42` degrees, maximum
  slope at most `60` degrees, no more than `3%` of samples over `45` degrees, and
  relief within its D-039 target through `target + 16` metres.
- D-024's original two-course whole-mountain admission is not a hard generation
  gate for the enlarged prepared catalog. Record every visible terrain point as
  admitted, launcher-excluded, or unadmitted diagnostic evidence without
  pretending launcher/goal samples represent the whole map. Every authored
  launcher-to-goal corridor retains the full range, yaw, and height guards.

### D-041 — Remove directional blind sectors and simultaneous-ball limits

- Status: accepted on 2026-08-15; supersedes D-023's player-facing aim bounds,
  D-026's two-ball concurrency limit and intermediate-confirmation cleanup, and
  AC-8's third-shot block.
- Horizontal aim wraps through a complete 360-degree circle. Existing authored
  and saved values in `0..100` retain the established `-80..+80` degree mapping
  around the course shot axis; continued adjustment beyond that interval reaches
  every bearing without disabling either horizontal step control.
- Vertical aim covers the complete non-duplicated directional range from
  straight down at `-90` degrees through straight up at `+90` degrees. Power
  remains bounded at `10..100` because it is launch strength, not direction.
- Fire is unavailable only after course clear or while a separate modal state
  owns input. Active unconfirmed ball count never disables Fire. Every accepted
  Fire input creates a new ball, and each live ball keeps its own source, setup,
  settlement, and resolution state.
- On a multi-goal course, confirming one ball freezes and retains that ball but
  does not remove other live balls. Completing the final goal may clean up
  remaining unconfirmed balls as part of ending the course.

### D-042 — Finish the basic terrain and camera foundation before devices

- Status: accepted on 2026-08-15; clarifies the implementation sequence for
  D-014 through D-016 without removing those later product requirements.
- The current foundation phase is limited to making the connected-heightfield
  course catalog meaningfully varied and making overview, cannon first-person,
  Shot Follow, and their transitions coherent in ordinary play.
- Do not begin bounce-pad implementation until that terrain and camera
  foundation is accepted. Damping pads, airflow devices, and gravity zones
  remain later expansion work after the core bounce-pad progression.
- Deferred devices must not be used to explain, hide, or compensate for weak
  basic terrain composition or camera behavior.

### D-043 — Stabilize goal confirmation and strengthen pace and aim feedback

- Status: accepted on 2026-08-15; supersedes D-028 and D-039's prior launch-speed
  values and D-038's short result hold for confirmed goals. It strengthens the
  halo readability clauses in D-039 and D-040.
- Ball motion uses a `4.0` local time scale, twice the pace of the preceding
  build. Legal speed is approximately `68.6..293.9 m/s`; gravity, damping, and
  motion thresholds derive from the same owner. The wall-clock analytic horizon
  is halved and its substep is normalized to the `2.0` course-authoring scale,
  so prepared spatial routes stay exact without rebaking. Engine time and the
  real-second settlement, outside-rest, and pre-contact safety rules do not change.
- Confirming any goal freezes and retains its ball, preserves all other live
  balls on an intermediate result, and immediately restores the exact stored
  planning pose. Confirmation never retargets or holds Shot Follow at the goal
  plate and never moves the cannon.
- The final stage-clear panel uses the viewport center at every supported size;
  the existing action, focus, copy, theme, and modal ownership remain unchanged.
- In aerial planning, the yaw-and-elevation halo is a large deep-navy
  world-space instrument clearly above the launcher. The full dotted elevation
  scale remains above local ground, while narrow no-depth accents keep both axes
  readable over terrain. Cannon first-person uses a compact forward presentation
  of the same two-axis instrument. Exact vertical cannon aim uses a stable
  horizontal look-at reference rather than a colinear world-up vector. Neither
  presentation draws a trajectory, center-origin wedge, or second-barrel silhouette.

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
- New reference images must demonstrate oblique, cannon, or mixed planning rather than
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
