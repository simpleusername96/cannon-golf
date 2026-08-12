---
type: spec
status: active
created: 2026-08-12
last_reviewed: 2026-08-12
canonical_for: Current visual composition and UI direction for the provisional Cannon Golf project
scope: Camera, terrain readability, impact marks, holes, devices, HUD, and visual hierarchy
source: Paint Mountain design system plus user direction recorded on 2026-08-12
related:
  - PRD.md
  - RESEARCH.md
  - assets/paint-mountain-hud-comparator.png
  - assets/paint-mountain-world-comparator.png
---

# Cannon Golf Design Rules

## Purpose

Preserve the useful visual discipline of Paint Mountain while preventing its
frontal mountain-coverage composition from becoming the default for the new
game.

## Scope

These rules govern planning and shot cameras, terrain presentation, physical
holes, impact-history marks, placeable devices, overlay HUD, typography, color,
and information hierarchy. They do not decide ball physics, stage data formats,
or code ownership.

## Requirements

### Product read

- The world must read as a 3D golf puzzle first and an artillery launcher
  second.
- A stage is a physical course with one or more holes, not a paintable target
  surface.
- The cannon, current ball, holes, settled balls, recent impact history, and
  selected device are the only persistent gameplay accents.

### Camera grammar

- Do not treat the inherited frontal Aim View as the default composition.
- Use a top or high-oblique planning view to explain lateral alignment, hole
  distribution, branch choice, and device placement.
- Use a side or near-profile planning view to explain height, launch elevation,
  ledges, gaps, and rebound direction.
- Use an oblique three-quarter view when both axes must remain readable.
- A behind-cannon view may be a temporary launch or local-aim view. It must not
  hide the course structure or become the only way to plan.
- Shot Follow should reveal cause and effect, then return to the prior planning
  context without changing the stored setup.
- Camera changes must preserve stage identity, selected hole, selected device,
  and launch parameters.
- Avoid wide frontal terrain silhouettes that flatten front-to-back distance.

### Terrain language

- Favor courses that extend through depth or vertical sequence rather than
  filling the frame as one broad facade.
- Viable families include a stacked quarry, a chain of crater bowls, a slot
  canyon, terraced switchbacks, and compact ridge shelves.
- Terrain must have visible thickness, contact shadows, clear walkable or
  rollable faces, and legible gaps. It must not look like a card, backdrop, or
  flat height strip.
- Each stage needs a readable direct route or a readable reason why a device is
  necessary.
- Decorative rocks and trees may communicate scale but must not hide holes,
  impact marks, balls, or pad faces.

### Holes and settled balls

- A goal is a real cup or recessed basin with visible inner depth, not a floating
  ring, target decal, or waypoint icon.
- Hole rims may use restrained material contrast, but the depression and shadow
  must carry the primary meaning.
- An occupied hole must show the settled ball clearly from every planning view.
- A completed state must not rely on color alone.

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

### Bounce pad

- A pad must sit on or conform to the physical surface and expose its outgoing
  direction through shape and orientation, not color alone.
- Placement mode must show the legal surface, current orientation, stock, and
  invalid state without covering the route.
- Use top/oblique or side/profile composition for placement; do not require the
  player to infer a wall normal from a frontal view.
- The MVP visual vocabulary contains one bounce-pad family. Other device types
  remain research, not visible inventory.

### Overlay HUD to reuse

- Retain Paint Mountain's Quiet Context qualities: warm paper-white surfaces,
  navy type, saturated blue for the sole primary action, Pretendard, Korean-first
  copy, edge alignment, generous padding, and minimal containment.
- Keep the course center open. Place persistent status and controls at safe
  edges and verify them against every supported planning view.
- Use one primary action per state. During launch setup, that action is Fire.
- Angle, power, goal progress, ball or shot stock, camera mode, device stock,
  and menu are valid only when they support a current decision.
- Remove coverage rails, coverage percentages, paint icons, paint-result copy,
  and any control that implies terrain painting.
- Do not add dashboard cards, decorative borders, detached shortcut tiles,
  filler explanations, or duplicated state.

### Color and materials

- Preserve a restrained warm off-white and cool-gray world with clear faceting
  and soft daylight.
- Reserve saturated colors for the current ball, newest impact, selected device,
  primary action, and semantic state.
- Older impact marks should lose contrast and saturation while remaining
  distinguishable from terrain shading.
- Hole rims and pads must remain distinct when viewed in grayscale through
  shape, depth, and orientation.

## Acceptance Criteria

- A still from a planning state reads as 3D golf without explanatory copy.
- At least one top/high-oblique and one side/near-profile view show every
  required hole and the selected pad without persistent HUD obstruction.
- Three retained impact marks can be ordered newest to oldest from appearance
  alone.
- No normal gameplay capture shows surface coverage, continuous paint, an exact
  impact predictor, or a frontal-only planning composition.
- Korean labels fit without clipping at the 1280x720 logical baseline and at a
  wider desktop aspect ratio.
- The visible pad face, goal recess, and occupied-hole state remain readable
  without depending on hue alone.

## Non-Goals

- Pixel-for-pixel reuse of a Paint Mountain screenshot.
- A photoreal golf course, sports broadcast presentation, or character avatar.
- A large device toolbar before the bounce-pad loop is validated.
- Treating the exploratory images in `RESEARCH.md` as approved camera targets.

## Related

- [`PRD.md`](PRD.md) owns product behavior.
- [`RESEARCH.md`](RESEARCH.md) records source material and the limits of the
  current concept images.
- [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) owns unresolved camera and interaction
  choices.
