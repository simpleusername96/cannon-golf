---
type: plan
status: done
created: 2026-08-14
scope: Replace terrain-owned goal pits with visible physical goal plates, enlarge and darken the ball, and progressively widen and deepen the ten-course terrain catalog
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - .agents/execplans/2026-08-14-camera-navigation-goal-visibility.md
  - .agents/execplans/2026-08-14-terrain-contrast-height-contract.md
---

# Goal Plates and Progressive Terrain - Execution Contract

The current ten-course build puts every settlement target at the bottom of a
terrain-owned basin. Large airborne markers locate those basins, but the actual
landing surface remains hard to see and the cannon view can face surrounding
walls. The accepted target image instead shows shallow, physical landing plates
on ordinary connected terrain. This contract makes that model authoritative,
preserves dwell-based settlement, enlarges and darkens the physical ball, and
scales later courses to substantially wider terrain and twice the former late
catalog relief without adding HUD or authored devices.

## Purpose

- Objective: make every goal a readable surface landing facility while making
  later courses materially wider and more vertically dramatic.
- Deliverable: updated product rules, one physical goal-plate owner, revised
  constructive terrain shaping, ten migrated course recipes and prepared
  artifacts, larger dark ball presentation, and final runtime/performance/render
  evidence.
- Completion state: all ten courses start from prepared artifacts generated in
  under 60 seconds each; no goal uses a deep terrain pit; each plate has a
  visible floor, low retaining wall, broad incoming opening, marker, and
  one-second safe-settlement rule; course 10 spans approximately `315 x 480`
  metres with at least `160` metres of playable relief.

## Scope and Boundaries

In scope:

- Goal floor, wall, entry opening, collision, visual state, containment, and
  dwell contract.
- The small terrain support footprint below and around each goal plate.
- Physical and visual ball radius, material color, roughness, and every directly
  dependent ballistic clearance.
- Progressive horizontal scale and relief thresholds across the existing ten
  courses.
- Existing overview/cannon framing and airborne markers only where their inputs
  must follow the new plate geometry.
- Canonical product and design documents plus task-local tests and captures.

Out of scope:

- New courses, bounce-pad gameplay, scoring, lives, timers, trajectory preview,
  a minimap, new HUD panels, or a new camera interaction model.
- Exact solution certification or a broad physics-search campaign.
- Changing aim ranges, power ranges, gravity, motion time scale, cannon size,
  device placement, or prepared terrain geometry beyond the completed support
  correction.

Constraints and invariants:

- `CannonGolfSettlementGoal` owns the physical plate floor and wall, settlement
  containment, one-second dwell, visual marker, and state rhythm.
- The terrain generator owns only a connected support surface beneath the plate;
  it must not create a terrain wall or recessed bowl as goal collision.
- The plate floor is `0.18 m` above its terrain support. Its wall is
  `0.9-1.3 m` tall and skips a broad approximately `67.5 degree` incoming arc.
- The complete physical ball radius becomes `1.0 m`; mesh and collider remain
  identical. The ball uses a dark navy material with low metallic response and
  moderate roughness.
- Settlement requires containment, existing safe linear/angular motion, and
  `1.0` continuous second. Contact followed by escape remains `bounced_out`.
- Every incomplete plate can confirm in any order. Confirmation unlocks but
  never auto-selects that plate as a cannon source. The player chooses the
  original start or a completed plate; confirmed balls remain frozen there.
- Each source uses a stable course-center base yaw and starts at `50 / 50 / 50`.
  Source selection may occur during flight; each live shot records its source
  and setup so retry is exact.
- Course horizontal scales by catalog index are locked to
  `1.00, 1.00, 1.05, 1.10, 1.15, 1.20, 1.28, 1.35, 1.42, 1.50`.
- Minimum relief by catalog index is locked to
  `60, 65, 80, 90, 100, 112, 124, 136, 148, 160` metres. Relief belongs to
  macro peaks, shelves, ridges, and valleys, not local goal excavation.
- Existing triangle budgets and prepared-artifact loading remain unchanged.
- UI and performance validation run only after all implementation and artifact
  work is complete.

Destructive or irreversible actions:

- None. Prepared `.res` artifacts are reproducible outputs.

Exact actions requiring owner or user approval:

- Stop and ask before continuing if the same correction/validation loop would
  be attempted a sixth time, if any single test or validation reaches ten
  minutes, or if meeting the locked size/relief targets requires changing
  physics, aim ranges, the 60-second per-course generation limit, or course
  count.

## Discovery Closure

| Requirement or concern | Verified current owner and behavior | Evidence | Locked decision | Task IDs |
| --- | --- | --- | --- | --- |
| Goals are deep and hidden | `_carve_goal()` lowers the center by the authored `3.5-4.5 m` recess and builds surrounding terrain to the retaining lip | `src/cannon_golf/trajectory_course_generator.gd`; rendered courses 1, 5, and 10 | Replace the bowl carve with a flat support `0.18 m` below the plate, a `24 m` smooth blend, and a `36 m` incoming-side blend; terrain provides no goal wall | 1.1, 3.1 |
| Goal collision has no owner | `CannonGolfSettlementGoal` currently asserts no `StaticBody3D`; terrain supplies all floor/wall collision | `src/cannon_golf/settlement_goal.gd`; `tests/cannon_golf_goal_test.gd` | Goal owner creates a cylinder floor plus segmented low wall colliders with an incoming gap and retains marker/state responsibilities | 2.1, 2.2 |
| Dwell behavior already exists | Game accumulates safe contained time and rejects bounced-out balls, but effective dwell is time-scaled below one second | `CannonGolfGame._update_live_ball()` and goal constants | Preserve the state machine and use exactly one real second of continuous safe containment | 2.2 |
| Ball is hard to read | Physical/visual radius is `0.75 m`; material is bright `#2584FF`, metallic `0.16`, roughness `0.24` | `cannon_golf_ballistics.gd`, `golf_ball.gd`, rendered evidence | Use radius `1.0 m`, dark navy `#0B2D5C`, metallic `0.04`, roughness `0.58`; never decouple visual and physical size | 2.3 |
| Later terrain is not large or dramatic enough | Courses 4-10 share a `210 x 320 m` profile and most enforce only `80 m` relief | course resources, profile, generator | Apply the locked per-course horizontal scales and relief schedule; keep mesh cell/triangle counts fixed | 3.2 |
| Sequential gameplay contradicts the puzzle | Runtime checks only `CourseBuilder.goal`, advances `active_leg_index`, moves the cannon automatically, and hides future goals | `cannon_golf_game.gd`, `course_builder.gd`, relay/multi-goal tests; user correction on 2026-08-14 | Treat goal index as identity only; accept any incomplete goal, preserve every confirmed ball, unlock its plate as an optional source, and clear only when all goals complete | 4.1 |
| Cannon view implies a target | Camera context stores an active leg and the in-progress correction attempted to frame its launcher-to-goal bounds | `course_camera_rig.gd`; rendered cannon captures; user correction on 2026-08-14 | Restore a local source-only cannon pose based on the selected launcher's stable course-center base yaw; never pass or infer a target goal | 4.2 |
| Launcher choice has no HUD owner | HUD exposes tally and camera controls but no source selector | `cannon_golf_hud.gd`, `cannon_golf_hud.tscn` | Add one compact top-left `OptionButton`: Start plus completed goal numbers; normal focus, Korean/English labels, no target semantics | 4.2 |
| Height must not become goal occlusion | Existing relief scaling and local bowl carve can put maximum slopes directly around a goal | generator order and current screenshots | Apply macro relief first, then bounded support conditioning; keep the incoming support blend longer than other sides and preserve airborne markers | 3.1, 3.2, 4.2 |
| UI must remain restrained | Current HUD already contains the accepted tally and controls | PRD FR-9 and current HUD | Add only the compact launcher-source selector; do not add target, next-goal, or central instruction UI | 4.2 |

Readiness statement:

- Every material product, architecture, dependency, data, UX, ownership,
  safety, and validation decision is closed.
- Godot 4.7.1 and the storage-safe validation wrapper are present. The bake,
  focused test, startup smoke, performance test, and background capture entry
  points were verified in the current PowerShell worktree.
- Remaining unknowns are implementation-local and cannot change this contract.

## Tasks

### Phase 1: Make the goal-plate model authoritative

Goal: remove active product requirements that make terrain pits the goal owner.

Source owners: `project-specs/cannon-golf/PRD.md`,
`project-specs/cannon-golf/DESIGN_RULES.md`,
`project-specs/cannon-golf/DECISIONS.md`

- [x] **1.1** Record the physical goal-plate and progressive-terrain contract.
  - Change: specify surface plate geometry, incoming opening, one-second dwell,
    larger dark ball, separate macro relief, and the late-course size/relief
    progression; preserve old terrain-basin decisions only as superseded
    history.
  - Accept: active canonical text no longer requires a terrain-owned basin for
    the current ten-course catalog and does not describe the `0.75 m` ball as
    current behavior.

### Phase 2: Build the physical plate and readable ball

Goal: implement the new world objects independently of terrain generation.

Preconditions:

- Phase 1 is complete.

Source owners: `src/cannon_golf/settlement_goal.gd`,
`src/cannon_golf/course_builder.gd`,
`src/cannon_golf/cannon_golf_ballistics.gd`,
`src/cannon_golf/golf_ball.gd`, `tests/cannon_golf_goal_test.gd`,
`tests/cannon_golf_ballistics_test.gd`

- [x] **2.1** Build one visible colliding goal plate.
  - Change: create a thin physical floor and segmented low wall using the
    prepared floor/wall heights and incoming shot axis; leave a three-segment
    opening toward the prior launcher; retain state-dependent wall/rim rhythm,
    flag, and airborne marker.
  - Accept: goal tests find one plate body, floor collision, wall collision,
    incoming opening, and no deep goal-owned geometry; active/future/confirmed
    visual states remain distinct.
- [x] **2.2** Enforce plate containment for one continuous second.
  - Change: align vertical containment with the plate floor/wall and set dwell
    to `1.0 s`; preserve bounce-out and safe-motion gates.
  - Accept: a slow contained ball settles only after one second; a fast or
    escaping ball does not confirm; relay activation still centers the launcher
    on the completed floor.
- [x] **2.3** Enlarge and darken the physical ball.
  - Change: update the shared radius and material while preserving collider/mesh
    equality and ballistic consumers.
  - Accept: source and ballistics checks report a `1.0 m` matching mesh/collider
    radius and the dark low-gloss material.

### Phase 3: Replace goal excavation and rebuild progressive terrain

Goal: produce ordinary connected terrain beneath visible plates and scale later
courses without changing runtime generation behavior.

Preconditions:

- Phase 2 source and focused logic checks pass.

Source owners: `src/cannon_golf/trajectory_course_generator.gd`,
`src/cannon_golf/prepared_course.gd`, `src/cannon_golf/course_leg_data.gd`,
`resources/cannon_golf/courses/*.tres`,
`resources/cannon_golf/prepared/*.res`, `tests/cannon_golf_terrain_test.gd`

- [x] **3.1** Replace the terrain bowl with a plate support footprint.
  - Change: seal goal floor/rim at the plate surface, keep only the wall height
    above it, flatten terrain to `floor - 0.18 m` under the plate, blend to
    natural terrain over `24 m`, and use `36 m` on the incoming side. Remove the
    inner concave bowl and discontinuous visibility cap.
  - Accept: prepared samples under every plate remain within `0.08 m` of the
    support height; no terrain sample acts as a retaining wall; the support
    blend joins the surrounding heightfield without a step.
- [x] **3.2** Apply the locked width and relief progression.
  - Change: migrate course scales, drive minimum relief from the catalog
    schedule, and strengthen macro height synthesis only as needed outside goal
    support footprints.
  - Accept: every prepared extent equals its scaled profile; every course meets
    its indexed relief threshold; multi-goal courses retain at least one
    descending leg; course 10 reaches approximately `315 x 480 m` and `160 m`
    relief within the existing triangle budget.
- [x] **3.3** Rebuild the ten prepared artifacts once.
  - Change: bump construction/generator identity and run the storage-safe bake
    only after tasks 3.1-3.2 settle.
  - Accept: every course seals and saves in less than 60 seconds; the wrapper
    reports zero persistent-log growth and zero task-owned processes.

### Phase 4: Make multi-goal play player-directed

Goal: remove ordered checkpoint behavior and expose cannon-source choice without
adding target selection.

Preconditions:

- Phases 1-3 remain complete.
- D-036 is accepted and active product documents no longer require ordered play.

Source owners: `src/cannon_golf/cannon_golf_game.gd`,
`src/cannon_golf/live_shot_state.gd`, `src/cannon_golf/course_builder.gd`,
`src/cannon_golf/course_camera_rig.gd`, `src/cannon_golf/cannon_golf_hud.gd`,
`scenes/cannon_golf/cannon_golf_hud.tscn`

- [x] **4.1** Let any incomplete goal confirm.
  - Change: track a goal index per live shot; test containment against every
    incomplete plate; preserve confirmed balls and completed indices; remove
    automatic leg advance, future-goal rejection, and automatic cannon move.
  - Accept: multi-goal runtime coverage confirms goals in a non-numeric order,
    keeps their balls, leaves the cannon source unchanged after each success,
    and clears only after the final incomplete goal confirms.
- [x] **4.2** Add explicit launcher-source selection and a source-only camera.
  - Change: let the builder place the reusable cannon at the original start or
    a completed plate center with a stable map-center base yaw; add a compact
    localized OptionButton below the tally; reset a newly selected source to
    `50 / 50 / 50`; restore the cannon camera's bounded local pose without any
    goal input. Record source and setup per live shot so retry remains exact
    across later source changes.
  - Accept: only Start and completed goals appear; selecting a locked goal is
    rejected; selecting an unlocked goal moves the existing cannon to its exact
    center, updates the local cannon view, and resets the controls; keyboard
    focus, visible selection, Korean/English copy, and exact retry all pass.

### Phase 5: Final integration, performance, and rendered UI gate

Goal: validate the completed system once, after all development and artifacts
are final.

Preconditions:

- Phases 1-3 are complete and no implementation input remains unsettled.

Source owners: task-owned tests, `tests/capture_cannon_golf_frame.gd`, this
contract

- [x] **5.1** Run the final focused gameplay and catalog checks.
  - Change: run goal, ballistics, terrain, build, relay, and startup/catalog
    checks through the storage-safe wrapper. Do not run solution certification
    or a broad inherited Paint Mountain suite.
  - Accept: all named focused checks pass once; no individual check approaches
    ten minutes.
- [x] **5.2** Run performance and UI/render evidence last.
  - Change: run the prepared-selection performance check, then capture courses
    1, 5, and 10 at `1280 x 720` in overview and cannon views. Inspect actual
    pixels for plate floors/openings, ball contrast, goal count, camera safety,
    HUD clipping, and macro relief.
  - Accept: selection remains within one 60 Hz frame without generation; the
    restrained HUD and source selector are unclipped; airborne markers make
    incomplete plates discoverable through the free camera; the source-only
    cannon view shows the current local `50 / 50 / 50` direction without
    choosing a goal; the ball has a dark clear silhouette; and later maps are
    visibly wider/deeper than early maps.
  - Render discovery: the first final capture showed that the original
    `24/36 m` blend still left the physical plate at the bottom of a local
    terrain cut, and that the cannon preset framed only the first `8 m` of the
    shot. Replace that insufficient local blend with a flat terrain shoulder
    outside the plate plus a broad transition. The later user correction
    rejects target framing: the cannon preset now stays local to the selected
    source and follows only the current horizontal aim. This is a correction of
    the locked visible outcome, not a change to goal physics.
- [x] **5.3** Audit, close the contract, and commit.
  - Change: run the diff-scoped quality audit, remove stale bowl-language from
    touched active paths, record evidence here, set status `done`, and commit
    only task-owned files.
  - Accept: no competing goal/terrain owner, debug path, task-owned process,
    persistent log growth, unrelated change, or active unchecked task remains.

## Validation and Rework Controls

| Cadence | Exact check | Run when | Do not rerun until |
| --- | --- | --- | --- |
| Inner loop | `git diff --check` plus wrapper `-CheckOnly` for the changed source owner | A source owner is syntactically complete | That source changes |
| Phase 2 logic | `tests/cannon_golf_goal_test.gd` and `tests/cannon_golf_ballistics_test.gd` | Plate and ball source settle | Plate/ball behavior changes |
| Bake gate | `scripts/bake_cannon_golf_courses.gd`, 60-second wrapper limit | All generator/resource changes settle | Generator identity, course resources, or prepared schema changes |
| Final gameplay gate | Named focused checks in task 4.1 | All development and baking are complete | A reached gameplay input changes |
| Final performance/render gate | Performance test and background captures in task 4.2 | Task 4.1 passes | Performance, UI, camera, plate, ball, terrain, or artifact input changes |

Validation rules:

- Run the narrowest check that proves the current task.
- Do not run performance or UI/render validation before Phase 4.
- Do not run physics certification, solution search, or a broad suite.
- Run a passing check once per declared cadence; rerun only after a relevant
  change.
- Count materially equivalent fix/test cycles. Stop before a sixth cycle and
  ask the user whether to continue.
- Stop any single test or validation at ten minutes and ask the user before
  increasing its limit or splitting it into repeated attempts.
- Keep the existing 60-second per-course bake limit; never increase it.

## Predetermined Contingencies and Change Control

| Trigger | Required response | Boundary or escalation point |
| --- | --- | --- |
| A verified material fact contradicts this contract | Stop the affected branch and revise this contract before resuming | Do not improvise a different product, physics, goal, terrain, UI, or validation contract |
| A plate floats above or intersects terrain | Correct only the bounded support height and plate base offset, then rebake | Do not restore a recessed bowl or add per-frame terrain fitting |
| A wall opening faces away from the incoming leg | Correct the goal-local yaw conversion and its focused assertion | Do not rotate the authored route or launcher |
| Increased ball radius invalidates an analytical clearance | Recompute through the shared ballistics constant and constructive setup search | Do not use a visual-only radius or change gravity/power ranges |
| A late course cannot seal under the locked scale | Reduce only that course by one prior scale step and record the exception after one diagnostic cycle | Ask before any second reduction or physics/range change |
| Relief near a goal hides the plate | First add a bounded flat terrain shoulder outside the plate and a broad smooth transition; keep the relief target outside that footprint | Ask before lowering the catalog relief target or adding screen-space waypoints |
| Same loop would run a sixth time or one test reaches ten minutes | Stop all related work and report exact attempts/evidence | Resume only after user direction |

Implementation-local discoveries may be handled inside the locked contract when
they cannot change scope, visible behavior, ownership, architecture, safety, or
acceptance.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this contract.
- Current phase: complete.
- Next task: none.
- Phase 4 evidence: non-numeric completion orders `3,1,2` and
  `6,2,5,1,4,3` passed; `deep_relay` confirmed Goal 2 first, retained Start,
  unlocked and selected Goal 2, restored an exact retry after switching back to
  Start during flight, and cleared only after Goal 1. The ten-course builder
  placed the one reusable cannon at every goal center and restored Start. Each
  focused run completed in under four seconds with zero log growth.
- Change-control note: the user replaced the target-framed ordered relay model
  after the prior five-attempt camera stop. D-036 closes the new product
  contract, so Phase 4 begins a new bounded implementation loop rather than a
  sixth attempt at the rejected active-leg camera design.
- Final gate evidence: free-order completion, launcher-source selection, exact
  retry, course build, camera, UI contract, ten-course catalog smoke, terrain,
  ballistics, and prepared-selection performance checks passed. The final
  performance check completed in 2.5 seconds with zero persistent log growth
  and zero owned processes. Rendered courses 1, 5, and 10 confirmed the compact
  selector, open center HUD, airborne markers, dark ball, physical plates, and
  progressive relief. A direct final cannon capture confirmed the source-only
  over-shoulder view; it does not select or frame a goal.
- Terrain and artifact evidence: generator version 6 replaces excavation with
  the shallow plate support, wide shoulder, and incoming blend. All ten current
  prepared artifacts generate below the one-minute course limit (`110-743 ms`
  observed). The ten-course terrain contract passed, including indexed
  extents/relief, flat `0.18 m` supports, low plate walls, non-monotonic relay
  content, and triangle budgets. One class-cache test correction and one
  float-tolerance correction preceded the passing terrain run; zero log growth
  and zero owned processes were reported.
- Quality audit: gameplay coordinates completion and source choice; the builder
  owns placement; the camera rig owns the local pose; the HUD owns presentation;
  and live-shot state owns retry identity. The audit found and fixed one local
  retry-camera yaw omission and added UI signal/edge coverage. No competing
  normal-play goal-order owner remains; `activate_leg` and `active_leg_index`
  remain explicitly limited to offline certification compatibility.
- Update rule: after a checkpoint passes, record concise evidence, check the
  task, and advance this pointer in the same edit.

## Completion and Stop Conditions

Complete when:

- Every task acceptance check passes.
- Every named phase and final gate passes.
- The final rendered evidence matches the accepted surface-plate model and
  progressively larger terrain direction.
- Active specs and decisions contain the durable product changes.
- Frontmatter status is `done` and task-owned changes are committed.

Replan when:

- A material discovery invalidates the locked ownership, physics, terrain,
  progression, or validation contract.

Stop and ask when:

- A sixth materially equivalent loop would begin.
- Any individual test or validation reaches ten minutes.
- A predetermined contingency reaches its stated escalation point.

Do not replan or stop for:

- Implementation-local mechanics already contained by this contract.
- A passing check whose relevant inputs have not changed.
