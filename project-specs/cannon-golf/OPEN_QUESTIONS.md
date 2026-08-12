---
type: evidence
status: active
created: 2026-08-12
topic: Product decisions that materially affect Cannon Golf implementation
scope: Questions to resolve before implementation planning becomes an execution contract
source: Gaps identified while drafting PRD.md on 2026-08-12
related:
  - PRD.md
  - DESIGN_RULES.md
  - DECISIONS.md
  - TASKS.md
---

# Cannon Golf Open Questions

## Purpose

Keep material ambiguity out of implementation tasks. These questions are not a
request to decide everything now; they define what must be resolved before the
affected code path is designed.

## Sources

- User direction recorded on 2026-08-12.
- Accepted decisions in [`DECISIONS.md`](DECISIONS.md).
- Reference gaps in [`RESEARCH.md`](RESEARCH.md).
- Conflicts between the copied Paint Mountain runtime and [`PRD.md`](PRD.md).

## Findings

| ID | Open question | Why it changes implementation | Current safe boundary |
| --- | --- | --- | --- |
| Q-01 | How does the player set the accepted angle-and-power variables: raw yaw/elevation controls, a target-assisted control, or a combination? | Determines input, solver, HUD, accessibility, and camera ownership | Angle and power remain player-controlled; do not reuse the target-click inverse solver as the product decision |
| Q-02 | Which view is the default planning view, and how do top, side, oblique, cannon, and follow views transition? | Determines stage composition, occlusion rules, controls, and UI safe areas | Treat frontal-only planning as rejected; every transition and exploration mode must preserve planning state and return to valid framing |
| Q-03 | Do impact marks fade by shot order, real time, stage time, or a fixed retained count? | Determines data model, shader/decal lifecycle, replay, and readability | Preserve only the rule that newest is darkest and older is lighter |
| Q-04 | How many prior impact marks remain visible? | Too many create noise; too few weaken correction | Make the count a stage-independent tuning decision before content production |
| Q-07 | Can player-placeable devices be edited only before the first shot, between shots, or while balls are moving? | Changes state machine, undo, simulation determinism, and camera needs | No placement during live simulation unless explicitly approved later |
| Q-08 | Can a placed device be moved, rotated, removed, or reused after a shot? | Changes interaction model and whether trial history remains comparable | Require explicit placement and orientation state in replays |
| Q-09 | What surface and empty-air constraints make pad and airflow placement legal? | Determines collision, UI feedback, trivial solutions, and level certification | Keep surface pads flush to valid terrain, restrict damping to fully flat surfaces, and require an explicit unobstructed airflow volume |
| Q-10 | Are goals attempted in any order or assigned one at a time? | Changes planning, HUD, completion state, and stage solution space | PRD currently allows any order but does not lock it |
| Q-12 | Which terrain family leads the first slice: quarry, crater chain, slot canyon, switchback, or another course? | Determines generator reuse, camera framing, art direction, and collision proof | Compare with a small graybox storyboard before selecting |
| Q-13 | Is `Cannon Golf` only an internal slug or a candidate public title? | Changes visible copy, package identity, save paths, and export naming | Keep it internal and do not rename runtime identifiers yet |
| Q-14 | Should a bounce pad use a fixed reflection, authored impulse, controllable strength, or only orientation? | Determines whether placement remains understandable and deterministic | Start comparison with fixed strength plus orientation, but treat it as unapproved |
| Q-16 | When should damping, airflow, and gravity-zone stages enter after or around the core eleven-stage progression? | Changes teaching order, total content count, and when the device tray expands | Keep the accepted eleven-stage bounce progression intact until an expansion sequence is explicitly set |
| Q-18 | What exact damping, airflow, and gravity values and inventory limits remain understandable without prediction? | Changes physics tuning, readability, and solution tolerance | Keep damping strong but non-sticky, airflow modest and bounded, and gravity local and sharply downward; exact values remain tuning decisions |
| Q-19 | Which terrain topology is allowed: heightfield-only winding ground, disconnected islands, caves, bridges, overhangs, or some bounded subset? | Changes mesh representation, camera occlusion, placement normals, generator capability, and solver search space | Start with one connected heightfield-like course that bends laterally and changes elevation; do not accept overhangs or caves without a separate decision |
| Q-20 | What minimum solution tolerance must a certified stage have around launch and placement values? | Distinguishes a learnable puzzle from a pixel-perfect or numerically fragile solution | Require replay under small perturbations, but set the actual angle, power, position, and rotation tolerances after the physics prototype |
| Q-21 | Which authoring actions recur enough to justify a Godot editor plugin: route sketching, terrain regeneration, goal placement, stock editing, placement-volume preview, witness recording, or batch validation? | Determines whether a custom editor pays for itself and prevents premature tool scope | Author several stages with Resources and ordinary editor controls first, then build only the repeated high-cost actions into a plugin |
| Q-22 | What is the final authoring balance between hand-authored terrain, generator-assisted variants, and fully procedural stages? | Changes tool scope, content review cost, reproducibility, and how solvability is established | Start with human-authored intended solutions plus automated replay validation; do not treat procedural generation alone as proof of quality |

## Resolved Questions

| ID | Resolution | Owner |
| --- | --- | --- |
| Q-05 | A goal counts only after safe settlement. The confirmed ball stays visible and cannot be displaced; exact collision treatment is an implementation detail. | `DECISIONS.md` D-010 |
| Q-06 | Retries are unlimited. There is no timer, lives, finite ball stock, or shot limit that can fail the stage. | `DECISIONS.md` D-011 |
| Q-11 | Confirmed goals persist and later shots cannot invalidate them, so multi-goal completion does not require several still-dynamic balls to remain settled simultaneously. | `DECISIONS.md` D-010 and D-011 |
| Q-15 | The selected additional vocabulary is a flat-surface damping pad, a mid-air placeable airflow device, and a bounded gravity-drop zone. | `DECISIONS.md` D-015 |
| Q-17 | Gravity zones, like every other route-changing mechanism, are placed by the player. | `DECISIONS.md` D-015 and D-016 |

## Recommendations

- Resolve Q-01 through Q-04 before final camera/input implementation.
- Resolve Q-07 through Q-10 and Q-14 before bounce-pad placement and multi-goal
  state become an execution contract.
- Use the saved screen-direction storyboard as the visual brief, then resolve
  Q-12 with a runtime-feasible graybox of the same camera families.
- Resolve Q-16 and Q-18 through Q-22 before expansion-mechanic implementation or stage
  production becomes an execution contract.

## Limitations

- The table does not select answers on the user's behalf.
- Defaults described as safe boundaries prevent premature code decisions; they
  are not accepted product behavior unless moved to `DECISIONS.md`.
