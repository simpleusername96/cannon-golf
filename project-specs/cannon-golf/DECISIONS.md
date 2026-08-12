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
- An unsuccessful ball leaves the active simulation before the next launch;
  only confirmed settled balls persist between launches.
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

- Status: accepted for the two-course prototype under the owner's delegated
  implementation authority on 2026-08-12.
- Each introductory course points the stationary cannon down its authored shot
  axis. The player adjusts elevation angle and power in one-degree and
  one-percent steps; there is no horizontal aim control or exact trajectory
  preview in this slice.
- This keeps the first lesson to the two variables the owner named. Later
  courses may reopen horizontal aiming only if their topology requires it.

### D-018 — High-oblique is the default planning view

- Status: accepted for the two-course prototype.
- A whole-course high-oblique view is the default. A true side/profile view is
  the alternate. Arrow keys pan, the mouse wheel changes planning distance, and
  Shot Follow returns to the same stored view, pan, zoom, angle, and power.
- The prototype does not include a separate behind-cannon planning mode.

### D-019 — Retain five impact marks by launch order

- Status: accepted for the two-course prototype.
- Retain at most five first-contact marks. Their visual priority depends only on
  launch order: the newest is darkest and each older retained mark is lighter.
- Marks do not fade with wall-clock time and do not label or predict a landing.

### D-020 — Begin with manually authored terraced shelf courses

- Status: accepted for the two-course prototype.
- The first two courses use connected, heightfield-like terraced shelves built
  from editor-readable resource data. They may bend laterally and change height
  but do not use caves, bridges, overhangs, disconnected islands, or devices.
- Human-authored direct-solution witnesses are verified through the real rigid
  body simulation. A custom level editor remains deferred until repeated manual
  authoring work justifies it.

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
