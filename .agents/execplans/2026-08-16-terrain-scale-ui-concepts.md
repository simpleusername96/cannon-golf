---
type: plan
status: done
created: 2026-08-16
scope: Research and decide terrain scale, difficulty progression, and in-game UI/UX concept directions without changing game code
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Terrain Scale and UI Concepts - Research Checklist

## Purpose

- Decision or research question: How should Cannon Golf make terrain visually smoother, courses materially larger, goal spacing more legible, difficulty more intentional, and the live HUD easier to use?
- Why it matters: Terrain generation, ballistic reach, camera fit, goal readability, and HUD hierarchy currently affect each other and cannot be designed independently.
- Decision owner: User.
- Final output: A Korean HTML report with current-state evidence, external primary-source evidence, three independent visual directions, trade-offs, and one recommended implementation direction.

## Scope and Evidence Contract

- In scope: Current prepared-course generation, terrain mesh/material presentation, goal spacing, camera framing constraints, difficulty progression, live HUD, and three image-based concepts.
- Out of scope: Editing gameplay, generator, camera, HUD, scene, resource, or prepared-course production code; implementing pads, airflow, damping, or gravity mechanics.
- Destructive or irreversible actions: None.
- Approval required before: Any later production implementation.
- Search budget or reassessment point: Stop after current owners and representative renders are inspected and each decision criterion has at least one relevant primary or authoritative source.
- Conflict-resolution rule: Current user direction and canonical project specifications override inherited behavior and generic genre convention.
- Stop rule for unproductive exploration: Exclude a source when it cannot change terrain sampling, course scale, difficulty structure, camera framing, goal readability, or HUD hierarchy.

| Evidence category | Primary source | Freshness requirement | What it must establish | Sufficient evidence |
| --- | --- | --- | --- | --- |
| Product intent | Canonical Cannon Golf specifications and decisions | Current worktree | Required player experience and non-scope | Relevant terrain, camera, difficulty, and HUD rules traced |
| Current implementation | Godot scenes, scripts, shaders, resources, tests, and fresh rendered captures | Current worktree | Actual owners, dimensions, constraints, and visible problems | Representative early, middle, and late course evidence |
| Terrain methods | Official engine docs and primary technical literature | Current or method-stable | Practical smoothing and scale controls without removing landform identity | Mesh, heightfield, normal, and constraint approaches compared |
| Game readability | Platform and accessibility guidance plus established game UX references | Current where applicable | HUD hierarchy, target readability, input affordance, and camera safe-area principles | Each recommendation tied to an observable problem |
| Concept directions | Three independent Image Gen outputs grounded in current captures | Current task | Meaningfully different terrain, difficulty, and HUD strategies | Exactly three readable 16:9 in-game concepts |

## Viable Options

| Option | Why materially viable | Decision criteria | Disqualifier |
| --- | --- | --- | --- |
| Scenic fairway | Smooth broad landforms and restrained edge HUD preserve a calm miniature-golf read | Terrain legibility, low HUD obstruction, implementation continuity | Becomes too flat or hides meaningful elevation |
| Surveyed expedition | Stronger depth cues and explicit route context support long goal-to-goal distances | Distance judgment, multi-goal planning, camera clarity | Adds persistent explanatory UI or route prediction |
| Minimal instrument | Very low HUD footprint gives the enlarged world maximum visual priority | Fast aiming, world visibility, input clarity | Removes necessary numeric control or goal/source state |

## Tasks

### Phase 1: Establish current truth

- [x] Read and verify the bounded specification, source, resource, history, and existing plan set.
- [x] Capture and inspect fresh representative in-game frames.
- [x] Record current terrain, scale, camera, difficulty, goal, and HUD constraints.

Phase gate:

- Every surviving option is materially viable and every current-state claim has inspected evidence.

### Phase 2: Gather decisive evidence

- [x] Inspect primary or authoritative sources for smooth terrain construction and normal treatment.
- [x] Inspect primary or authoritative sources for course scale, camera framing, spatial readability, and game HUD hierarchy.
- [x] Convert evidence into explicit generator, difficulty, and UI criteria.

Phase gate:

- Each decision criterion has enough evidence, or one exact missing input or authority is identified.

### Phase 3: Decide and record

- [x] Generate and inspect exactly three independent 16:9 concept images grounded in current game captures.
- [x] Compare the concepts against the same criteria and select a recommended synthesis.
- [x] Produce and integrity-check the Korean HTML report with at least three images, citations, limits, and an implementation outline.

Phase gate:

- The recommendation is made, the report is readable, and no implementation readiness is implied beyond the stated next planning boundary.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this checklist.
- Current phase: Complete.
- Next task: Await the user's visual-direction decision before creating a Mode 3 implementation contract.
- Last completed gate: Three grounded directions were compared, a recommended synthesis was recorded, and the Korean HTML report passed local asset and structural integrity checks. Automated browser rendering of the local file was blocked by the browser URL policy, so no browser-render claim is made.
- Update rule: Check an item only when its evidence exists, and do not repeat a completed search unless its freshness boundary or a decision-changing input changes.

## Completion and Stop Conditions

Complete when:

- Current implementation claims are supported by source and fresh renders.
- Each recommendation is supported by project evidence or an external source.
- Three independent concept images are present and compared consistently.
- The Korean HTML report is structurally checked, all local images resolve, and the three concept images are visually inspected. A browser render is preferred when the local-file policy permits it.
- Frontmatter status is changed to `done` after the recommendation is recorded.

Escalate when:

- A representative gameplay state cannot be captured.
- Current sources materially contradict the canonical product documents.
- Image generation cannot receive the current game capture as grounding.

If implementation follows, invoke the planning skill again in Mode 3. Do not extend this checklist into implementation while visual direction or material course-scale decisions remain open.
