---
type: spec
status: active
created: 2026-08-12
last_reviewed: 2026-08-17
canonical_for: Current visual composition and UI direction for the provisional Cannon Golf project
scope: Camera, terrain readability, impact marks, settlement goals, devices, HUD, and visual hierarchy
source: Paint Mountain design system plus user direction recorded on 2026-08-12
related:
  - PRD.md
  - ../../.agents/research/cannon-golf/RESEARCH.md
  - assets/paint-mountain-hud-comparator.png
  - assets/paint-mountain-world-comparator.png
---

# Cannon Golf Design Rules

## Purpose

Preserve the useful visual discipline of Paint Mountain while preventing its
frontal mountain-coverage composition from becoming the default for the new
game.

## Scope

These rules govern planning and shot cameras, terrain presentation, settlement
goals, impact-history marks, placeable devices, course mechanisms, overlay HUD,
typography, color, and information hierarchy. They do not decide physics
coefficients, stage data formats, or code ownership.

## Requirements

### Product read

- The world must read as a 3D golf puzzle first and an artillery launcher
  second.
- A stage is a physical course with one or more settlement goals, not a
  paintable target surface. A goal may be a hole or a small bounded landing zone.
- The cannon, current ball, goals, settled balls, recent impact history, and
  selected device are the only persistent gameplay accents.

### Immediate screen direction

![Cannon Golf screen direction storyboard](assets/cannon-golf-screen-direction-storyboard.png)

- File: `assets/cannon-golf-screen-direction-storyboard.png`
- SHA-256: `5FFFD31293C3643190C8EF9F2EBFF9BAB1F98BF5EF321470CE27E37BFC2672EF`
- This is the current visual explanation of the immediate screen change, not a
  runtime screenshot, pixel contract, final stage layout, or claim that every
  shown mechanism appears in one stage.
- The large left panel establishes the high-oblique planning composition. The
  upper-right panel is retained only as a historical height-reading reference;
  the runtime alternate is now the per-leg cannon view. The lower-right panel
  demonstrates temporary ball follow.
- Preserve the quiet warm HUD language, but replace coverage, timer, remaining
  balls, and remaining shots with three compact launch-control modules and one
  primary Fire action. Each module pairs a prominent current value and key hint
  with direct decrement, slider, and increment input. Overview, cannon view, ball
  follow, quick retry, pause, camera controls, and on-demand shortcut help remain
  small icon actions with accessible names.
- The combined board deliberately shows player-placed bounce, damping, airflow,
  and gravity in one frame so their visual roles can be compared. It does not
  set content order or inventory limits.

### Camera grammar

- Do not treat the inherited frontal Aim View as the default composition.
- Use a top or high-oblique planning view to explain lateral alignment, goal
  distribution, branch choice, and device placement.
- Use a fixed rear-upper perspective at the selected cannon source. Keep the
  physical cannon, nearby terrain, and selected direction in one frame by
  looking toward a near point on the real launch ray. Draw one large, thin,
  deep-navy world-space
  curve from a raised point above the launcher through only the first capped portion
  of the current ballistic motion. Connect a thick amber arrowhead to the final
  curve tangent. The curve must not reach a goal or show a landing/impact point.
  Keep the curve depth-tested and shadow-free; only the compact arrowhead may
  bypass depth testing. Uniformly reduce the same guide in cannon perspective so
  its connected arrow stays compact near the camera; keep the physical barrel
  and small center reticle. Exact vertical cannon aim must keep a finite, stable
  camera basis without reducing the legal elevation range.
- Use an oblique three-quarter view when both axes must remain readable.
- In overview, left-drag pans, right-drag orbits around the bounded course
  focus, the wheel changes distance, and arrow keys pan. A click without drag
  must not refocus or jump the pivot. Direct overview interaction during Shot
  Follow restores the stored overview before applying the input.
- Keep zoom bounded but materially useful in both directions. A compact reset
  action restores the authored high-oblique view, zero pan, and default distance.
  One wheel notch or compact zoom action must visibly change planning distance;
  do not require several repeated inputs before the course scale changes.
  Ten equal zoom-in actions reach a `28 m` desired minimum distance, while six
  zoom-out actions reach the complete-course fit. Keep the response logarithmic.
- Terrain collision shortens the camera boom. It must not lift the camera into
  a sky-dominant jump or let the near plane enter a cliff.
- Cannon perspective is a selectable, subject-centered orbit viewer. Its stable
  initial interest is the selected cannon's authored anchor, not a point along
  the changing launch ray. Left-drag orbits continuously around that interest,
  right-drag and arrow keys pan it across the prepared course, and the wheel
  changes camera-to-interest distance. Keep vertical orbit short of inversion,
  keep camera placement terrain safe, and apply direct manipulation without
  trailing interpolation. Aim changes move the barrel and cues, not the camera.
  This state remains independent from Overview; only the explicit Overview
  action opens the top/complete-course camera.
- Shot Follow reveals cause and effect without locking input. Fire follows the
  newest ball automatically; `Tab`, overview, or cannon view returns to the
  exact stored pre-follow state. A confirmed goal also returns there immediately
  and never flies or holds the camera at its plate. Aim and Fire remain usable
  while a ball lives.
- Camera changes must preserve stage identity, selected cannon source, selected
  device, and launch parameters.
- Whatever exploration controls are selected must not move gameplay objects,
  clear selection, alter aim, or invalidate confirmed goals. Returning to
  planning must restore a readable course framing.
- The high-oblique reset frames the complete course. The cannon reset returns
  to the selected source's authored rear-upper orbit pose. Overview pan, orbit,
  and bounded zoom expose the full course; Cannon pan remains within prepared
  course bounds while preserving its perspective orbit model. The course
  selection preview frames the course's full depth.
- Avoid wide frontal terrain silhouettes that flatten front-to-back distance.

### Terrain language

- Favor courses that extend through depth or vertical sequence rather than
  filling the frame as one broad facade.
- Viable families include a stacked quarry, a chain of crater bowls, a slot
  canyon, terraced switchbacks, and compact ridge shelves.
- Terrain must have visible thickness, contact shadows, clear walkable or
  rollable faces, and legible gaps. It must not look like a card, backdrop, or
  flat height strip.
- The first two courses use a `315 x 180` metre generated mountain
  extent and must fit inside the real three-parameter launch envelope. Do not
  shrink or clip the mountain to make a shot appear feasible, and do not draw
  the envelope in normal play.
- Keep the active mountain footprint compact enough for one high-oblique reset
  view. Progression comes from more elevation tiers, branching ridges, shelves,
  and valleys, not from an increasingly empty rectangular map.
- Preserve a terrain-clear channel along the existing camera boom. Its
  generator check must begin at the same terrain-safe surface pivot used by the
  runtime camera, so a central ridge or summit is not flattened into an
  artificial reset valley. Do not rewrite the camera controller for this rule.
- Use `assets/terrain-progression-early.png`, `terrain-progression-mid.png`, and
  `terrain-progression-late.png` as the visual family contract. Early terrain
  has one dominant mountain relationship and few broad levels; middle terrain
  introduces distinct plateau branches and a valley; late terrain uses several
  connected ridge and shelf branches at clearly different elevations.
- Steep escarpments may separate shelves and may form the irregular outside
  shell. The launcher support, every basin approach, and every intended
  launcher-to-goal flight corridor remain explicit protected constraints.
  Do not globally smooth away the reference structure or create an isolated
  spike merely to increase a numeric relief value.
- Expand the physical terrain envelope to `1.35` times the authored route
  domain on both horizontal axes while keeping route stations unchanged. At
  least `1.08` authored rectangles of active terrain must remain connected.
  No adjacent active internal heightfield edge may exceed `50°`; the vertical
  outside skirt is not an internal landform slope.
- A goal basin is a shallow recess inside a local summit or ridge, not a hole at
  the bottom of surrounding terrain. The final goal is a summit. Earlier goals
  may be summits or ridge centers according to the admitted flight and overview
  channels; ridge orientation is not fixed to the shot axis.
- Each stage needs a readable direct route or a readable reason why a device is
  necessary.
- Decorative rocks and trees may communicate scale but must not hide goals,
  impact marks, balls, or pad faces.

### Settlement goals and resolved balls

- A goal is a smooth basin formed directly in the connected render/collision
  heightfield. Its near-flat floor and broad gradual shoulder must be visible
  from the authored overview.
- Do not add a separate physical plate floor, low fence, retaining wall, raised
  lip, or state-dependent boundary. Tint the terrain surface inside the scoring
  region blue so it cannot disappear below the heightfield. A flush
  non-colliding disc and fixed flag may reinforce the scoring floor.
- The basin must be shallow relative to the macro terrain and wide enough to
  read as normal landform shaping rather than a locally cut crater or cliff.
- Entering a goal is not enough: a ball that bounces out before settlement must
  remain visibly unresolved and live. Exiting cancels only that settlement
  candidate; it must not delete the ball or prevent later re-entry.
- A confirmed goal removes its resolved ball after completed-goal state and the
  existing first-contact impact mark are secure. Later shots cannot invalidate it.
- All incomplete goals share the same blue flag and marker rhythm. Completion
  changes only that flag material to the accepted completed-goal gold; it must
  not change the basin, disc, pole or flag transform, collision, boundary
  geometry, or airborne locator.
  Keep the fixed flag as the local landing cue. Add a thick matte 3D
  downward arrow above the local skyline for course-scale location; do not use
  a thin emissive stem or diamond.
  One small edge-aligned tally may show completed goals over total goals, such as
  `1 / 2`; it must not become a progress card or central status panel. The tally
  and source selector carry completed state after the ball is removed.
- A compact edge-aligned cannon-source selector lists `Start` plus completed
  goal numbers only. It is a location choice, not a target selector. Selecting
  a completed goal moves the cannon to that basin-floor center and resets that source
  to `50 / 50 / 50`; confirmation never selects it automatically.
- The current-catalog ball uses one `2.0 m` physical and visual radius plus a
  dark navy, low-gloss material so it remains readable over the enlarged pale
  terrain without becoming a non-physical screen-space marker.
- The existing compact completed-goals tally remains the non-world redundant
  status cue; the local goal itself changes only its flag color.

### Impact-history marks

- Call the feature an `impact mark`, `impact history`, or `first-contact mark`.
  Do not call it surface paint, coverage, paint payload, or trail in product
  documents.
- Stamp one mark at the first valid terrain contact only.
- The newest mark is darkest, sharpest, and highest contrast. Each retained older
  mark is progressively lighter and visually quieter.
- Do not add splashes along the subsequent route, a painted wake, a coverage
  meter, a predicted impact ring, a floating label, or a numbered pin.
- Marks must remain legible against both lit and shaded terrain without using
  emission or a large glow.

### Devices and course mechanisms

- A bounce pad must sit on or conform to a physical surface and expose its
  outgoing direction through shape and orientation, not color alone.
- A damping pad must sit flat on a fully level legal surface. Its face and
  material must communicate grip and energy absorption rather than reflection;
  a flat bounded landing goal may contain it without hiding the goal boundary.
- An airflow device may be suspended in a valid air-placement volume. Show a
  short, restrained stream whose direction and affected width are legible, but
  do not draw an exact resulting trajectory.
- A gravity zone is placed by the player in a valid air volume. Its bounded
  volume and downward action must remain readable without implying that global
  gravity changed.
- Placement mode must show the legal surface or air volume, current orientation,
  stock, and invalid state without covering the route. The device tray must show
  only mechanisms the player can place in the current stage.
- Use top/oblique or per-leg cannon composition for placement; do not require the
  player to infer a wall normal from a frontal view.
- Bounce, damping, airflow, and gravity must have distinct silhouettes and
  motion cues in grayscale; color is supporting information only.
- Before player placement, the visible course contains no pad, fan, field, gate,
  or other route-changing mechanism. Terrain shape and goals must explain the
  problem without decorative fake mechanisms.

### Overlay HUD to reuse

- Preserve the rendered world as the dominant surface. Normal play uses navy
  typography and controls directly over the world, with no persistent white or
  cream panel, dashboard card, or mobile-style directional pad. Use a local
  outline, shadow, or restrained low-alpha line only when a reachable world
  value would otherwise reduce contrast.
- Keep the course center open. Put the compact level/goal tally and cannon-source
  selector at the upper-left, routine view/retry/help/pause actions at the
  upper-right, and horizontal aim, elevation, power, and Fire on one continuous
  transparent bottom rail. The setup groups share a baseline instead of owning
  detached modules. The help icon may open one concise shortcut panel at the
  upper-right edge; it stays collapsed by default and manages keyboard focus.
  Put full course reset, settings, course selection, and main-menu navigation in
  the pause overlay.
- Fire is the sole primary action during setup. Present it as a compact filled
  amber horizontal action with a restrained projectile cue at the far-right end
  of the bottom rail, not a saturated blue rectangle or the circular Start
  shape. Amber also marks current selection; reserve cyan for trajectory and
  incomplete-goal semantics already present in the world.
- Course selection keeps one direct, transparent scrolling list beside the
  unchanged real course preview. Unselected rows have no filled surface. The
  selected row uses stronger type plus a short amber edge mark and shows goal
  count once. Opening or changing selection must scroll the selected row into
  view. Do not add a list card, vertical section divider, difficulty label,
  stars, score, or duplicated level metadata. Back remains a surface-free text
  action. Start is a compact horizontal amber action that names the selected
  level and uses a forward cue; do not roll it back while refining Fire.
- Use one primary action per state. During launch setup, that action is Fire.
- After the final goal confirms, place the existing stage-clear panel at the
  viewport center and focus its one primary result action.
- Horizontal aim, vertical angle, power, device stock, the goal tally, and menu
  are valid only when they support a current decision. Do not persist course
  prose, a progress card, camera-state labels, feedback copy, permanently
  expanded shortcut legends, time, lives, finite ball stock, or remaining shots
  over normal play.
- Remove coverage rails, coverage percentages, paint icons, paint-result copy,
  and any control that implies terrain painting.
- Do not add dashboard cards, decorative borders, multiple shortcut owners,
  detached shortcut tiles, filler explanations, or duplicated state.

### Color and materials

- Preserve a restrained warm off-white and cool-gray world with continuous
  landform shading and soft daylight. Use slow macro-scale tonal variation;
  do not expose the regular collision grid through random per-triangle color
  or one face normal per triangle.
- Reserve saturated colors for the current ball, newest impact, selected device,
  primary action, and semantic state.
- Older impact marks should lose contrast and saturation while remaining
  distinguishable from terrain shading.
- Goal boundaries and pads must remain distinct when viewed in grayscale through
  shape, depth, and orientation.

## Acceptance Criteria

- A still from a planning state reads as 3D golf without explanatory copy.
- At least one top/high-oblique and one per-leg cannon view show every
  required goal and the selected pad without persistent HUD obstruction.
- Firing, switching views, exploring the course, quick retry, and returning from
  Shot Follow retain horizontal aim, vertical angle, power, impact history,
  placements, selection, and confirmed goals without clipping or invalid
  framing. The planning controls and next launch remain available while a prior
  ball is live, up to the prototype's simultaneous-ball limit.
- Three retained impact marks can be ordered newest to oldest from appearance
  alone.
- No normal gameplay capture shows surface coverage, continuous paint, an exact
  impact predictor, or a frontal-only planning composition.
- Korean labels fit without clipping at the 1280x720 logical baseline and at a
  wider desktop aspect ratio.
- The visible pad face, goal boundary, safe-settlement state, and occupied-goal
  state remain readable without depending on hue alone.
- A still distinguishes the angled bounce face, flat damping surface, suspended
  airflow source and stream, and bounded downward gravity field by shape and
  orientation rather than labels alone.

## Non-Goals

- Pixel-for-pixel reuse of a Paint Mountain screenshot.
- A photoreal golf course, sports broadcast presentation, or character avatar.
- A large device toolbar before the bounce-pad loop is validated.
- Treating the exploratory images in `.agents/research/cannon-golf/RESEARCH.md`
  as approved camera targets.

## Related

- [`PRD.md`](PRD.md) owns product behavior.
- [`RESEARCH.md`](../../.agents/research/cannon-golf/RESEARCH.md) records source material and the limits of the
  current concept images.
- [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) owns unresolved camera and interaction
  choices.
