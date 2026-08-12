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
- The player must settle balls in physical holes. Artillery supplies the launch
  method; golf supplies the objective and correction loop.

### D-003 — Impact history replaces explicit landing feedback

- Status: accepted.
- The newest impact mark is darkest and older marks are lighter. The terrain
  mark itself is the feedback; there is no separate prior-impact callout.

### D-004 — Stage complexity grows through hole count and reachability

- Status: accepted.
- Early content starts with one easy direct hole. Later content adds more holes,
  and some cannot be completed from the terrain and cannon alone.

### D-005 — The first placeable device is a bounce pad

- Status: accepted for the initial concept.
- The player places a pad to redirect a ball toward otherwise unreachable goals.
  Additional device families are not yet accepted.

### D-006 — Camera direction must move away from frontal-only planning

- Status: accepted.
- Top, side, and oblique planning compositions are required exploration areas.
  The existing frontal view and the three early concept images are only rough
  references.

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

## Rationale

- Separating impact memory from painting prevents the inherited coverage system
  from defining the new product by accident.
- The golf metaphor explains holes, settling, course reading, and iterative
  correction more directly than a shooter metaphor.
- Multiple planning angles are necessary because later solutions depend on both
  height and lateral pad orientation.
- An unchanged technical baseline makes later reuse decisions auditable: any
  runtime divergence will appear in future commits rather than being hidden in
  project creation.
- Excluding the old product briefs prevents competing canonical specifications.

## Consequences

- The current executable still behaves as Paint Mountain until future
  implementation is authorized.
- Paint, coverage, predicted-impact, terrain-generation, mechanism-placement,
  HUD, and stage-result owners must be classified as reuse, adaptation, or
  retirement before coding.
- Camera and input decisions must be resolved before the first gameplay rewrite;
  otherwise the copied frontal target solver may dictate the experience.
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
