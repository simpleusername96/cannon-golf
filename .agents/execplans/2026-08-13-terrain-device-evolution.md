---
type: plan
status: done
created: 2026-08-13
outcome: Decision-ready terrain-family and player-placed-device direction beyond the connected relay mountain
scope: Research and owner-decision checklist; not an implementation contract
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
  - project-specs/cannon-golf/OPEN_QUESTIONS.md
---

# Terrain and Device Evolution Study

## Purpose

Define a varied but coherent course vocabulary beyond the current single
connected ridge, and describe how player-placed bounce pads can become the next
playable vertical slice. This study separates recommendations from accepted
product decisions. It does not authorize implementation while the owner choices
listed below remain open.

## Scope and Evidence Contract

This study covers terrain families, course authoring, surface-device placement,
bounce behavior, data ownership, camera implications, and validation. It keeps
the accepted rule that authored courses contain terrain, launchers, and goals;
route-changing devices are placed by the player.

Local evidence inspected:

- `src/cannon_golf/course_terrain_factory.gd` and the retained Paint Mountain
  generator: one connected sampled top, one primary route, one render/collision
  product, and goal carving applied before geometry build.
- `src/cannon_golf/course_data.gd`, `src/cannon_golf/course_leg_data.gd`, and
  `resources/cannon_golf/courses/deep_relay.tres`: route-zero and sequential-leg
  assumptions are suitable for one ridge but do not yet express branches or
  device inventories.
- Current camera, solution replay, range admission, course-build, and relay
  tests: each new family must remain inspectable and must ship with a real
  physics witness rather than visual plausibility alone.

Primary technical evidence:

- Godot's [ArrayMesh procedural geometry guide](https://docs.godotengine.org/en/4.7/tutorials/3d/procedural_geometry/arraymesh.html)
  supports keeping canonical terrain samples separate from the generated render
  arrays.
- Godot's [collision-shape guidance](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html)
  favors concave collision for static level geometry and simple primitive or
  convex shapes for moving or interactive bodies.
- Godot's [ray-casting guide](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html)
  provides the terrain hit position and normal needed for a placement preview;
  physics-space queries belong in the physics step.
- [ShapeCast3D](https://docs.godotengine.org/en/4.7/classes/class_shapecast3d.html)
  can validate a pad footprint and instant overlap, but it is more costly than a
  ray and should be limited to the selected preview or commit check.
- [Area3D](https://docs.godotengine.org/en/4.7/classes/class_area3d.html) is a
  natural later boundary for authored-volume-free airflow and gravity effects.
- [RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html)
  exposes force and impulse behavior without teleporting the ball.
- The official [Bridge Constructor Portal listing](https://store.steampowered.com/app/684410/Bridge_Constructor_Portal/)
  is useful precedent for a small construction vocabulary followed by physical
  testing, but Cannon Golf must keep aiming and settlement as the primary loop.

## Terrain Families Explored

| Family | Player reading and device use | Fit with current generator | Main risk |
| --- | --- | --- | --- |
| Terraced switchback | A long route wraps around several height bands. Broad shelves teach one pad, then pad chains, while cliffs make side view valuable. | Strong. It remains one connected sampled top and can be expressed by route anchors plus shelf shaping. | Shelves can look repetitive or make the solution too obvious. |
| Crater-bowl chain | Several concave bowls are separated by rims and saddles. Pads launch out of one bowl or redirect into the next. | Strong. It extends the existing goal-carving language without requiring overhangs. | Non-goal bowls must not look like goals; rim silhouettes need distinct treatment. |
| Stacked quarry | Offset plateaus and steep cut faces create deliberate landing and redirection tiers. | Strong to moderate. It needs more explicit terrace masks but no new topology. | It can look artificial unless the low-poly erosion pass softens authored bands. |
| Connected ridge shelves | Two or more shelves diverge around a peak and reconnect. The player chooses a pad route based on angle, height, and stock. | Moderate. Geometry fits, but course data and camera framing need real route identifiers instead of the current route-zero assumption. | A visually open branch may accidentally allow a direct ballistic shortcut. |
| Heightfield slot canyon | A winding trench constrains lateral error; pads use banks and canyon-floor contacts. | Moderate. A deep trench is possible if every vertical line still intersects the top once. | No true overhangs; narrow walls can occlude goals and make placement frustrating. |
| Basin plateau | Large high shelves contain shallow safe regions and one or more deep goals. Damping pads later help on otherwise flat approaches. | Strong. It uses current connected topology and is a good bridge from direct shots to devices. | Too much flat area reduces three-dimensional course reading. |
| Separated mesas or islands | Gaps make device dependency explicit and allow dramatic silhouettes. | Weak without a new topology. Separate chunks, bounds, camera traversal, admission, and solver ownership are required. | Players may read empty space as out-of-bounds, and arbitrary gaps increase solution search. |
| Arches, caves, and overhangs | Pads can redirect through tunnels or under ledges. | Not supported by a heightfield-like top. Requires arbitrary mesh chunks and new placement-normal and occlusion rules. | High camera, collision, authoring, and certification cost before the core pad loop is proven. |

## Recommended Direction

Use a **solution-first authored skeleton with procedural surface synthesis**, not
pure procedural level generation. A designer or data resource should define:

1. launcher and ordered goal anchors;
2. one or more intended route curves and height bands;
3. broad landing or pad-placement zones;
4. legal device inventory and placement bounds; and
5. at least one saved shot-and-placement solution witness.

The generator should then synthesize the low-poly mountain around that semantic
skeleton, carve goals into suitable sampled terrain, and reject a course when
the certified route, camera framing, placement clearance, or ballistic admission
fails. Random seeds may vary surface character, but must not invent the puzzle's
required interaction.

Start with three families inside the current connected-topology boundary:

1. **Terraced switchback** for the first one-pad course.
2. **Crater-bowl chain** for rebound-to-settlement teaching.
3. **Connected ridge shelves** for later route choice and multi-pad escalation.

Keep stacked quarry, slot canyon, and basin plateau as variants of that grammar.
Defer disconnected islands, caves, and overhangs until device placement and
solution replay are stable. Their visual novelty does not justify changing the
terrain representation yet.

## Bounce-Pad Vertical Slice

### Player interaction

- Placement is available during planning, not while an active ball is being
  simulated.
- Selecting the pad shows one translucent ghost under the pointer. A camera ray
  resolves terrain position and normal; the ghost snaps flush to the surface.
- The player rotates the selected pad around its surface normal. The exact key
  binding is an owner decision because current aiming already owns `Q/E` and
  other compact shortcuts.
- Valid placement uses the normal quiet material plus a restrained outline;
  invalid placement uses one clear error state. Commit is atomic: an invalid
  ghost never becomes a physics object.
- A placed pad can be selected, rotated, moved, or removed before a shot.
  Placements persist across ordinary retries and relay checkpoints and clear only
  on an explicit course reset or stage exit.
- The HUD adds one compact device-stock control only when the current course
  supplies pads. It does not add instructions or a second permanent panel.

### Placement validation

The placement validator must reject a pad unless all checks pass:

1. the pointer ray hits canonical playable terrain;
2. the entire pad footprint has support, not only its center;
3. sampled support normals and height variation stay within the authored slope
   and flushness limits;
4. a footprint shape cast has no terrain, launcher, goal, confirmed-ball, or
   other-device overlap;
5. the pad keeps an authored clearance from edges, goals, and launcher bases;
6. the pad lies inside the course's legal placement region and remaining stock;
7. the resulting transform is finite and can be serialized deterministically.

Do not use the render mesh as the sole truth. Expose a canonical terrain surface
query that rendering, collision generation, placement, and tests can share.

### Physics recommendation

Prototype **fixed response strength plus player-controlled orientation**. On the
first valid ball contact, the pad should apply one deterministic velocity change
relative to its normal and then debounce that ball until contact ends. Do not
teleport the ball or rewrite its transform every frame. Fixed strength makes one
pad teach direction before later stages add pad count; unrestricted strength
would duplicate the cannon power control and enlarge the search space.

This is a recommendation, not an accepted Q-14 decision. Compare it against a
pure reflection model using the same one-pad test course before freezing the
contract.

## Proposed Ownership Boundaries

- **Terrain recipe/data** owns route anchors, terrain-family parameters, legal
  placement regions, device stock, and solution witness references.
- **Terrain factory** owns canonical surface samples and generated static
  render/collision products. It does not own input or device runtime behavior.
- **Placement controller** owns preview selection, pointer interaction, and
  commit/cancel orchestration.
- **Placement validator** owns pure legality checks against canonical course and
  terrain data.
- **Device runtime nodes** own contact response and readable visuals. Each
  instance is recreated from a serializable placement record.
- **Course state** owns inventory and persistence across retry, checkpoint, reset,
  and stage exit.
- **Solution replay** owns certified launch parameters and placed-device records;
  it must replay the same state transitions as normal play.

Do not add a Godot editor plugin first. Begin with resource-authored recipes and
debug overlays. Build an editor tool only after at least three courses expose the
same repeated authoring pain.

## Staged Implementation Roadmap

1. **Terrain grammar foundation** — add a terrain-family recipe and canonical
   surface-query boundary; reproduce all three current courses unchanged before
   adding a new family.
2. **One-pad playable slice** — build one terraced-switchback course, the planning
   placement interaction, placement validation, deterministic pad response,
   persistence, and one tolerant solution witness.
3. **Family expansion** — add crater-bowl and ridge-shelf courses using the same
   runtime owners; add route identifiers only when the first real branch needs
   them.
4. **Difficulty progression** — certify two one-pad courses, then increase stock
   and required interactions across five multi-pad courses. Every pad-dependent
   goal must reject the permitted direct-shot search space.
5. **Later devices** — reuse the placement-record and validation boundary for a
   flat-only damping pad. Use bounded `Area3D` volumes for airflow and local
   gravity only after surface placement is stable.
6. **Topology decision gate** — prototype one disconnected-mesa course outside
   production only if connected families cannot support the desired route
   variety. Accept arbitrary mesh chunks only with new camera, collision,
   placement, bounds, and solution-certification evidence.

## Validation Gates

- Existing terrain, relay, camera, UI, range, solution, and performance contracts
  remain green after the terrain recipe boundary is introduced.
- Each family has readable default, overview, side, and bounded exploration
  frames without clipping or a fixed pivot that prevents inspection.
- Placement tests cover unsupported edges, excessive slope, overlap, inventory,
  goal/launcher exclusion, move/remove, retry persistence, and reset clearing.
- Physics tests prove one contact produces one response, later bounces remain
  ordinary ball physics, and identical inputs reproduce materially similar first
  contacts.
- Every shipping course has a saved witness that succeeds under small launch and
  placement perturbations. Exact tolerance remains an owner/tuning decision.
- A performance gate measures the selected-preview shape cast, static terrain
  collision, and multiple placed pads on the target Windows build.

## Tasks and Progress

- [x] Trace the current connected terrain, route, goal, camera, and test
  assumptions.
- [x] Compare terrain families that fit the current heightfield-like topology
  with families that require arbitrary mesh topology.
- [x] Research Godot's supported surface-query, overlap-check, collision, force,
  and volume-effect boundaries from primary documentation.
- [x] Define a recommended solution-first authoring workflow, placement loop,
  ownership split, staged roadmap, and evidence gates.
- [x] Record the exact owner decisions that block an execution contract.

## Owner Decisions Required Before an Execution Contract

1. Accept connected, heightfield-like terrain as the production boundary for the
   bounce-pad progression, with islands/caves/overhangs deferred.
2. Choose fixed-strength oriented bounce as the prototype response, or request a
   direct comparison with pure reflection or adjustable strength.
3. Confirm that devices may be edited only during planning and persist across
   retry and relay checkpoints.
4. Set the minimum launch-position, pad-position, and pad-rotation perturbation
   tolerance for a certified solution, or authorize prototype-derived values.

## Completion and Next Step

The research checklist is complete. Implementation is deliberately blocked on
the four owner decisions above. Once they are accepted, replace this study with
one decision-complete execution contract for the terrain recipe boundary and
the single terraced-switchback bounce-pad vertical slice; do not implement all
terrain families or later devices in that first contract.
