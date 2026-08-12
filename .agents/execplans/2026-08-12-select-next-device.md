---
type: plan
status: done
created: 2026-08-12
scope: Record newly accepted core rules and identify the next distinct device family for owner selection
related:
  - ../../project-specs/cannon-golf/PRD.md
  - ../../project-specs/cannon-golf/DECISIONS.md
  - ../../project-specs/cannon-golf/RESEARCH.md
  - ../../project-specs/cannon-golf/OPEN_QUESTIONS.md
---

# Select the Next Device Family - Research Checklist

## Purpose

- Decision or research question: which device family should be considered after
  the bounce-pad progression without diluting angle-and-power cannon golf?
- Why it matters: each device adds rules, placement UI, camera requirements, and
  content cost; a duplicate trajectory modifier would add complexity without a
  new puzzle verb.
- Decision owner: the user.
- Final output: synchronized accepted rules, an unranked device portfolio, and a
  provisional first addition for the user to accept or reject.

## Scope and Evidence Contract

- In scope: accepted settlement, retry, camera stability, baseline bounce, and
  initial stage-sequence rules; device families that act deterministically and
  remain readable without an exact trajectory preview.
- Out of scope: runtime implementation, exact physics coefficients, final camera
  controls, device art, public naming, and acceptance of another device family.
- Destructive or irreversible actions: none.
- Approval required before: promoting any additional device into `PRD.md` or
  visible MVP inventory.
- Search budget or reassessment point: inspect the current project authority and
  a bounded set of direct physics-puzzle precedents; stop after at least five
  mechanically distinct eligible families or when new results repeat them.
- Conflict-resolution rule: current user decisions and project specifications
  override inherited runtime behavior and external precedent.
- Stop rule for unproductive exploration: stop when another candidate changes
  only presentation rather than the force, energy, topology, or settlement verb.

| Evidence category | Primary source | Freshness requirement | What it must establish | Sufficient evidence |
| --- | --- | --- | --- | --- |
| Current product rules | `PRD.md`, `DECISIONS.md`, `OPEN_QUESTIONS.md`, `DESIGN_RULES.md` | Current worktree | Existing loop, authority, constraints, and unresolved choices | All affected rules traced to an owner |
| Runtime affordances | Relevant `src/`, `resources/`, and tests | Current worktree | Whether bounce, camera, or mechanism boundaries are inherited inputs only | Candidate owners identified without treating them as accepted design |
| Device precedent | Official developer, manual, or storefront descriptions | Current enough to resolve the described shipped mechanic | A device adds a distinct physical relationship | At least one direct source for each cited precedent family |
| Fit and risk | Project constraints plus mechanics evidence | Current decision | Readability, determinism, overlap, and UI/camera cost | Every option has one explicit value path and material risk |

## Viable Options

| Option | Why materially viable | Decision criteria | Disqualifier |
| --- | --- | --- | --- |
| Damping or brake pad | Adds energy removal and controlled settlement instead of redirection | Supports small safe zones, readable contact, deterministic response | Makes goals automatic or duplicates ordinary terrain friction |
| Directional air jet | Adds visible continuous mid-air force without another collision surface | Fixed direction/strength, readable volume, stable simulation | Requires exact prediction or real-time control to understand |
| Magnetic field | Adds curved attraction or repulsion | Clear polarity, bounded range, deterministic falloff | Trajectory becomes opaque or demands constant player input |
| Transport beam | Adds a guided movement volume that suppresses other forces | Visible entry/exit relation and fixed direction | Removes too much angle-and-power agency |
| Portal pair | Adds route topology while preserving entry state | Both endpoints visible and camera traversal remains stable | Disorientation or placement freedom trivializes courses |
| Conveyor or speed strip | Adds post-contact energy and direction change along a surface | Fixed flow and clear surface language | Mechanically collapses into a bounce pad or uncontrolled rolling |
| Ball-triggered gate or latch | Adds route ordering rather than another trajectory modifier | Persistent state is visible and retry reset semantics are explicit | Becomes a generic key-and-lock puzzle or conflicts with confirmed-goal persistence |
| Local gravity change | Adds a bounded change to the meaning of down | Camera and physics remain predictable across the boundary | Invalidates the golf metaphor or ordinary ballistic assumptions |

## Tasks

### Phase 1: Establish current truth

- [x] Read and verify the bounded project sources.
- [x] Record accepted rules, remaining open decisions, and authority boundaries.
- [x] Remove options that violate unlimited retry, deterministic correction, or
  no-exact-prediction constraints.

Phase gate:

- Every surviving option is materially viable and every current-state claim has
  inspected evidence.

### Phase 2: Gather decisive evidence

- [x] Inspect bounded direct precedents for distinct device relationships.
- [x] Record source, observed mechanic, transfer limit, and confidence in
  `RESEARCH.md`.
- [x] Stop or narrow the search when the evidence contract is satisfied.

Phase gate:

- Each decision criterion has enough evidence, or one exact missing input or
  authority is identified.

### Phase 3: Decide and record

- [x] Synchronize accepted user decisions into the owning project documents.
- [x] Freeze the eligible device portfolio without promoting a new device.
- [x] Record a provisional recommendation and the exact user decision still
  required.
- [x] Validate lifecycle values, local links, and patch hygiene.

Phase gate:

- Accepted rules are current, the portfolio is preserved, and device selection
  remains explicitly owned by the user.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this checklist.
- Current phase: complete.
- Next task: obtain the user's device selection only when the bounce-pad course
  has demonstrated a missing puzzle verb.
- Last completed gate: accepted rules synchronized, candidate portfolio frozen,
  and recommendation left provisional.
- Evidence: current authority documents and runtime boundaries were inspected;
  direct references covered energy/friction differences, fixed airflow,
  activation chains, magnetic force, guided transport, portals, and gravity.
- Validation: known lifecycle values, required document headings, local Markdown
  links, and `git diff --check` passed on 2026-08-12.
- Update rule: check an item only when its evidence exists, and do not repeat a
  completed search unless its freshness boundary or a decision-changing input
  changes.

## Completion and Stop Conditions

Complete when:

- Current project sources and the bounded precedent sources are inspected.
- Every surviving option has a distinct puzzle verb, fit boundary, and named
  risk.
- Accepted user rules are recorded in their owners.
- The next-device recommendation and the user's remaining selection authority
  are explicit.
- Frontmatter status is changed to `done`.

Escalate when:

- Primary sources materially conflict with the user's constraints.
- Device acceptance is required to proceed beyond a recommendation.

If implementation follows, invoke `$goal-checklist-builder` again in Mode 3. Do
not extend this checklist into implementation while device selection remains
open.
