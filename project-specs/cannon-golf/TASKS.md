---
type: plan
status: draft
created: 2026-08-12
scope: Provisional implementation-oriented task breakdown derived from PRD.md
related:
  - PRD.md
  - DESIGN_RULES.md
  - OPEN_QUESTIONS.md
---

# Cannon Golf Draft Tasks

## Purpose

Show the likely implementation sequence without authorizing code changes. This
is a draft planning aid, not an active execution contract. Material questions
in `OPEN_QUESTIONS.md` must be resolved before the affected task is promoted to
an active plan.

## Tasks

### 1. Close the camera and aiming brief

- [ ] Decide Q-01 through Q-04.
- [ ] Produce one graybox camera storyboard of the same stage from top,
  high-oblique, side, near-profile, temporary cannon, and shot-follow views.
- [ ] Select the planning-camera grammar and record it in `DECISIONS.md` and
  `DESIGN_RULES.md`.

### 2. Define the new domain boundaries

- [ ] Decide Q-05 through Q-11 and Q-14.
- [ ] Specify `ImpactHistory`, `GoalHole`, `GoalSet`, `BouncePadPlacement`, and
  stage-result invariants without reusing paint/coverage terminology.
- [ ] Map every accepted PRD requirement to a current Paint Mountain owner that
  will be reused, adapted, or retired.

### 3. Establish one direct-hole vertical slice

- [ ] Replace coverage-based completion with one physical settled-hole goal in
  a test stage.
- [ ] Replace continuous paint behavior with one first-contact history mark per
  launch.
- [ ] Remove exact landing guidance from normal play while preserving accessible
  angle and power controls.
- [ ] Validate rapid retry and repeated-shot determinism.

### 4. Establish planning views

- [ ] Implement the selected top/oblique and side/profile planning views.
- [ ] Preserve launch setup across view changes and Shot Follow.
- [ ] Recompose inherited HUD elements around the selected views; remove
  coverage and paint-specific UI.

### 5. Add the first bounce-pad course

- [ ] Implement legal placement, orientation, invalid state, edit rules, and
  deterministic collision response for one pad family.
- [ ] Build one two-hole graybox with a certified device-dependent solution.
- [ ] Prevent pad placement from creating trivial out-of-bounds or overlapping
  solutions.

### 6. Validate the product loop

- [ ] Run the prototype comprehension targets in `PRD.md`.
- [ ] Verify newest-to-oldest impact ordering in lit and shaded terrain.
- [ ] Verify goal and selected-pad readability in every planning view.
- [ ] Decide whether the build case remains strong before expanding stage or
  device count.

## Progress

- [x] Created a separate Git repository at `D:/npjt/cannon-golf`.
- [x] Copied the Paint Mountain runtime baseline without code edits.
- [x] Separated current product design from Paint Mountain product briefs.
- [x] Saved external research and local visual comparators.
- [ ] No gameplay, UI, scene, resource, test, script, project setting, or export
  setting has been modified for the new product.

## Next Steps

- Resolve the camera and aiming questions first.
- Create a low-cost multi-view graybox storyboard before any gameplay rewrite.
- Convert only the first closed task group into an active execution contract.

## Verification

- Confirm copied runtime files match Paint Mountain commit `32c0b33` before any
  future implementation commit.
- Validate Markdown lifecycle metadata, local links, and `git diff --check`.
- Do not run or claim new gameplay validation while the runtime remains the
  unchanged Paint Mountain baseline.

## Risks

- Executing this draft as if decisions were closed would allow the inherited
  target solver, coverage state, and frontal camera to choose the product.
- Building multiple devices before one direct-hole loop is proven would expand
  scope before the core learning signal is validated.
