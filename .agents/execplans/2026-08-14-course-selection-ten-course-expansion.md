---
type: plan
status: done
created: 2026-08-14
scope: Course-selection responsiveness and a decision-ready first batch of ten varied multi-goal courses
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
  - .agents/execplans/2026-08-13-terrain-device-evolution.md
  - project-specs/cannon-golf/assets/course-select-double-state-evidence.png
  - project-specs/cannon-golf/assets/terrain-progression-early.png
  - project-specs/cannon-golf/assets/terrain-progression-mid.png
  - project-specs/cannon-golf/assets/terrain-progression-late.png
---

# Course Selection and Ten-Course Expansion - Research Checklist

## Purpose

- Decision: define a responsive course-selection delivery model and a concrete
  ten-course terrain/goal progression without pretending the current special
  two-leg generator can already produce it.
- Why it matters: the current selection input can show two blue states and
  blocks the main thread while it generates a new course. Ten larger courses
  would multiply that problem and would remain visually repetitive without a
  semantic landform grammar.
- Decision owner: the user owns the remaining product choices listed below.
- Final output: one recommended implementation sequence, a ten-course content
  matrix, visual direction references, acceptance gates, and exact blockers.

## Scope and Evidence Contract

- In scope: selection/focus/loading states, preview preparation, generated
  terrain delivery, goal-count progression, non-monotonic goal elevation,
  recognizable connected landforms, camera/range/solution implications, and
  concept imagery.
- Out of scope: implementing the fixes, authoring the ten production resources,
  accepting final bounce-pad physics, disconnected islands, caves, overhangs,
  and a custom Godot editor plugin.
- Destructive or irreversible actions: none.
- Approval required before: changing the accepted eleven-stage target or
  implementing pad-dependent courses before Q-07 through Q-09 and Q-14 close.
- Search budget: current Cannon Golf source/spec/test owners, the retained
  cooperative geometry path, three rendered concept directions, and primary
  Godot/landform references. Stop when the runtime cause, viable delivery model,
  course matrix, schema gaps, and owner blockers are known.
- Conflict rule: current code proves behavior; active PRD/design rules define
  desired behavior; accepted decisions outrank a plan; the latest explicit user
  requirement outranks conflicting older guidance once recorded by its owner.

| Evidence category | Primary source | What it must establish | Sufficient evidence |
| --- | --- | --- | --- |
| Selection state | `src/cannon_golf/app/cannon_golf_course_select.gd`, theme, capture | Which states look selected and who owns them | Event sequence plus rendered focus/pressed evidence |
| Stall cause | app, preview, builder, terrain factory, geometry factory | Whether work blocks the input frame | Complete synchronous call path and cache behavior |
| Delivery option | current generated product and retained progressive job | A safe preparation boundary for ten courses | One architecture that avoids runtime generation on selection |
| Terrain feasibility | course schema, route profiles, synthesizer, topology | Which natural forms fit connected terrain and what schema is missing | Ten-course matrix plus exact gaps |
| Visual direction | current runtime capture plus generated concept images | Whether peak, shelf, saddle, valley, cirque, basin, and plateau read clearly | Early, middle, and late overview images |

## Viable Options

| Option | Why materially viable | Decision criteria | Disqualifier |
| --- | --- | --- | --- |
| Keep synchronous generation and add a loading overlay | Small code change and truthful feedback | Only viable if input-frame work is already short | Still freezes animation/input for seconds; rejected |
| Defer the same synchronous build to the next frame | Lets the pressed state draw once | Very small transition patch | Moves the freeze by one frame; rejected |
| Cooperatively build every selected preview at runtime | Reuses `TerrainGeometryBuildJob` and can cap per-frame geometry work | No offline artifacts required | Route synthesis, goal carving, admission, topology, and resource creation still need progressive owners; selection churn wastes work |
| Bake canonical course artifacts offline and load/swap them asynchronously | Removes generation and certification from the selection path; the same artifact can serve preview and gameplay | Identity checks, bounded cache, explicit loading/error states | Requires a Cannon Golf bake format and build command; selected |

## Findings

### Selection state and freeze

The rendered evidence at
`project-specs/cannon-golf/assets/course-select-double-state-evidence.png` shows
two different states, not evidence of two true selections: course 1 retains the
blue focus border while course 2 owns the blue pressed fill. Both colors come
from the shared theme, so they read as two selected cards.

The blocking path is:

`Button.pressed` → `CannonGolfCourseSelect.select_course()` →
`CannonGolfApp._on_course_selection_changed()` →
`CannonGolfPreviewWorld.show_course()` → `CannonGolfCourseBuilder.build()` →
`CannonGolfCourseTerrainFactory.build()` → route/height synthesis, goal carving,
topology, admission, `TerrainGeometryFactory.build()`, collision, material, and
dressing construction.

`TerrainGeometryFactory.build()` drains an existing cooperative build job in a
tight loop. The first selection of another course is a cache miss; later
selection is faster only because the in-memory cache now exists. There is no
five-second timer. The transition animation itself lasts only 0.16 seconds.
Cold full-process captures took about 6.1 seconds for the default course, 7.5
seconds for course 2, and 8.2 seconds for the larger relay on the inspected
machine. These totals include process startup, so they establish relative cost,
not an input-callback latency budget.

Godot's official [background-loading guide](https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html)
confirms that synchronous loading blocks the calling thread and recommends
polling threaded-load status across frames before retrieving the resource.

### Current terrain capability

The current heightfield-like topology can represent recognizable connected
peaks, ridges, saddles, passes, valleys, broad basins, plateaus, and terraces.
This is consistent with public landform definitions: USGS describes a ridge as
a narrow elongated crest and recognizes ridge/valley systems, while NPS
describes a cirque as a bowl-shaped amphitheater cut into a mountain wall.

It cannot represent true caves, overhangs, bridges, or separated islands. Those
remain outside this batch.

The present multi-goal branch is not generic:

- every goal resolves on route 0;
- `CourseLegData` has no route index, landform anchor, or intended elevation
  band;
- explicit generation requires exactly the deep relay's upward pattern through
  at least 25 metres of rise per leg and at least 80 metres of overall relief;
- corridor admission samples a straight launcher-to-goal line, which is weak for
  switchbacks and curved valleys;
- tests hard-code three courses and treat `deep_relay` as the only two-leg case.

## Decision and Recommended Architecture

### 1. Make selection immediate and unambiguous

- `selected_course_index` remains the selection truth. ButtonGroup handles
  exclusivity; refresh code must not create a competing toggle owner.
- Any mouse, keyboard, or programmatic selection moves focus to the selected
  card. Focus remains visible for accessibility but must use a neutral/dashed or
  otherwise distinct treatment from the filled selected state.
- Exactly one button may be pressed after any selection, language refresh, or
  screen reopen.
- Selecting a card updates its state in the same frame, disables Start, changes
  Start copy to the localized equivalent of `준비 중…`, and requests the
  artifact. The old preview may remain visible but is visually restrained until
  the requested preview swaps in atomically.
- A newer selection cancels or supersedes an older request. A stale completion
  never replaces the latest preview. Failure enables no Start action and shows
  one concise local error; retrying the same card requests the canonical
  artifact again.

### 2. Bake once, reuse for preview and gameplay

Create a Cannon Golf-owned serializable course artifact containing:

- course/profile/seed/schema identity and integrity signature;
- canonical generated layout/topology data;
- render mesh and static collision shapes;
- generated leg positions, rims, launcher poses, frame bounds, and admission
  metrics;
- whole-course content/play bounds and certified solution metadata.

An offline repository command generates and validates all artifacts. Shipping
runtime never synthesizes a catalog course after a selection click. A small
repository uses `ResourceLoader.load_threaded_request`, polls status across
frames, validates full identity before acceptance, and keeps a bounded LRU cache
of three artifacts. Preview uses the render mesh and marker data without static
collision bodies; gameplay instantiates collision from the same artifact. This
preserves exact terrain parity without rebuilding it twice.

The current uncached generation path remains an authoring/bake owner and a test
oracle, not a production selection fallback. Missing, stale, or invalid baked
data fails closed with the local error state; it must not silently trigger a
multi-second runtime build.

### 3. Add a semantic connected-landform recipe

Generalize explicit courses from the special longitudinal relay into N ordered
legs. Add authored fields for route index, feature anchor or placement region,
and intended goal-rim elevation band. Add a course-level landform recipe with
bounded features such as:

- summit or rounded peak;
- ridge/spur and saddle/pass;
- broad plateau or shelf with a maximum slope/normal-variance contract;
- valley line or U-shaped valley;
- broad basin/cirque and local goal recess;
- terrace bands and switchback route anchors.

Human-authored intended solution and feature anchors define the puzzle.
Seeded synthesis supplies faceted surface variation around them. Generation must
reject missing peaks, flat zones, saddles, valley depth, goal clearance, camera
visibility, or solution witnesses. Goal order constrains state progression, not
elevation direction.

## Ten-Course Content Matrix

`L/M/H` are relative **goal-rim** bands within a course. They are constraints,
not exact metre values. Counts increase in steps so terrain and shot planning,
not goal quantity alone, controls difficulty.

| # | Goals | Rim order | Recognizable terrain | Intended lesson/device boundary |
| ---: | ---: | --- | --- | --- |
| 1 | 1 | L | Compact ridge shelf and one rounded peak shoulder | Direct angle/power |
| 2 | 1 | H | Main summit, lower peak, clear saddle, broad start shelf | Direct shot with stronger vertical read |
| 3 | 2 | H → L | Stacked quarry shelves descending into a valley | Two direct settlements; introduces downhill relay |
| 4 | 2 | L → H | Linked crater bowls separated by a saddle | Two direct settlements; current `deep_relay` may be reshaped into this slot rather than deleted |
| 5 | 3 | H → L → M | Terraced switchback around a dominant peak | First bounce-pad course after pad contract closes |
| 6 | 3 | L → H → L | U-shaped valley, high cirque rim, low valley bench | One-pad variation; strong non-monotonic height lesson |
| 7 | 4 | H → L → H → M | Twin peaks, quarry terraces, central saddle | Multi-pad chain and recovery shelf |
| 8 | 4 | L → M → L → H | Basin garden linked by ridges and valley floors | Multi-pad placement on flat and sloped candidates |
| 9 | 5 | H → L → M → H → L | Three connected ridge shelves with alternate routes | Route reading and several pad interactions |
| 10 | 6 | L → H → M → H → L → H | Deep mountain complex: horn, plateau, saddles, cirque, valley, terraces | Final batch course; highest multi-pad complexity |

Courses 1–4 remain device-free. Courses 5–10 reserve broad placement surfaces
but must not ship as pad-dependent until the bounce behavior and placement rules
are accepted. If that decision remains open, those six courses can be authored
and certified only as terrain/goal prototypes, not final gameplay content.

## Visual Direction

The concept images are planning references, not runtime screenshots or approved
exact layouts:

1. `project-specs/cannon-golf/assets/terrain-progression-early.png` — two peaks,
   saddle, broad shelves, and two goals at different heights.
2. `project-specs/cannon-golf/assets/terrain-progression-mid.png` — U-shaped
   valley, cirque, valley bench, ridge, and three non-monotonic goals.
3. `project-specs/cannon-golf/assets/terrain-progression-late.png` — horn summit,
   plateau, multiple ridges/saddles/terraces, central basin, and five goals at
   alternating elevations.

All three use the current snapshot only as a style reference: pale faceted
triangulated terrain, soft sky, warm ground, cyan flags, high-oblique course
reading, no UI, no trajectory, and no preinstalled device.

## Tasks

### Phase 1: Establish current truth

- [x] Trace selection state, focus, preview build, cache, and transition owners.
- [x] Capture the apparent double-selection state and distinguish focus from
  pressed state.
- [x] Trace the synchronous cold-build path and measure bounded comparative
  cold capture totals.
- [x] Map the current one-goal and special two-leg schemas, generator, camera,
  range, solution, and test assumptions.

### Phase 2: Gather decisive evidence

- [x] Compare overlay-only, deferred synchronous, progressive runtime, and
  offline baked-artifact delivery.
- [x] Select the baked-artifact path and its fail-closed runtime boundary.
- [x] Define a connected semantic landform vocabulary that fits current topology.
- [x] Generate and inspect early, middle, and late concept directions from the
  current game snapshot.
- [x] Define a ten-course goal/elevation/terrain matrix.

### Phase 3: Decide and record

- [x] Record the selected UI/preparation architecture and rejected alternatives.
- [x] Record the exact generator/schema/test changes a later execution contract
  must own.
- [x] Record the remaining user decisions that block implementation readiness.

## Validation Required by a Later Execution Contract

- Selection callback returns inside one frame budget on the target Windows
  release build; the exact release budget must be locked before implementation.
- After mouse, keyboard, programmatic selection, localization refresh, and screen
  reopen, exactly one card is pressed and focus identifies the same card.
- Start stays disabled until the latest requested artifact is identity-valid;
  stale completions cannot swap the preview or start the wrong course.
- First and cached selection timing, cancellation, bounded LRU behavior, invalid
  artifact error, and preview/gameplay geometry identity have automated tests.
- Every catalog artifact is produced by the repository bake command and passes
  schema/signature, finite-data, range, camera, and real-physics solution gates.
- Each terrain family proves its named peak/valley/basin/saddle/flat-zone
  measurements rather than relying on visual naming alone.
- Each course checks its authored goal-rim band sequence, goal non-overlap,
  N-leg transition, checkpoint persistence, complete-course exploration, and
  default setup miss.
- Rendered evidence covers course selection in default, focused-selected,
  loading, ready, error, and ten-course overflow/scroll states, plus default and
  overview frames for every terrain family.

## Progress and Next Steps

- Canonical progress: the task checkboxes in this checklist.
- Current phase: research complete; implementation contract blocked.
- Next task: obtain the four owner decisions below, then create one Mode 3
  contract in this order: selection/artifact delivery, generic N-leg terrain
  grammar, courses 1–4, bounce-pad vertical slice, courses 5–10.
- Update rule: do not repeat the completed search unless the code, accepted
  product decision, engine version, or target course count changes.

## Owner Decisions Required

1. Confirm whether ten courses replace the accepted eleven-stage target or are
   the first authored batch within it. Until then, Q-23 preserves the eleven
   target and treats this matrix as the first ten.
2. Accept offline baked course artifacts as mandatory shipping inputs, with no
   synchronous procedural-generation fallback in course selection.
3. Set the maximum release-build selection callback/frame time, or authorize a
   prototype-derived budget measured on the target Windows machine.
4. Close the bounce-pad response and placement rules before courses 5–10 become
   final pad-dependent gameplay rather than terrain/goal prototypes.

## Completion and Stop Conditions

This research checklist is complete: the runtime cause, selected delivery
architecture, terrain direction, content matrix, schema gaps, test gates, and
exact owner blockers are recorded. It does not authorize implementation.

Stop and revise before implementation if the owner chooses runtime-only course
generation, disconnected topology, unordered independent goals, a different
course count, or a different device teaching sequence. After the four decisions
close, invoke the planning skill again in Mode 3; do not implement from this
research artifact directly.

## Image Prompt Record

- Early: current screenshot style; connected low-poly miniature mountain with
  main/secondary peaks, saddle, broad shelves, two recessed goals, and no device.
- Middle: same style; U-shaped valley, high cirque, ridge/saddle, low flat bench,
  and three goals ordered high → low → medium.
- Late: same style; connected horn summit, plateau, ridges, saddles, basin,
  valley, terraces, and five goals at alternating elevations. A second edit pass
  changed only the unflagged central basin into the missing fifth goal.
