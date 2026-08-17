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
- Reference gaps in [`RESEARCH.md`](../../.agents/research/cannon-golf/RESEARCH.md).
- Conflicts between the copied Paint Mountain runtime and [`PRD.md`](PRD.md).

## Findings

| ID | Open question | Why it changes implementation | Current safe boundary |
| --- | --- | --- | --- |
| Q-07 | Can player-placeable devices be edited only before the first shot, between shots, or while balls are moving? | Changes state machine, undo, simulation determinism, and camera needs | No placement during live simulation unless explicitly approved later |
| Q-08 | Can a placed device be moved, rotated, removed, or reused after a shot? | Changes interaction model and whether trial history remains comparable | Require explicit placement and orientation state in replays |
| Q-09 | What surface and empty-air constraints make pad and airflow placement legal? | Determines collision, UI feedback, trivial solutions, and level certification | Keep surface pads flush to valid terrain, restrict damping to fully flat surfaces, and require an explicit unobstructed airflow volume |
| Q-13 | Is `Cannon Golf` only an internal slug or a candidate public title? | Changes visible copy, package identity, save paths, and export naming | Keep it internal and do not rename runtime identifiers yet |
| Q-14 | Should a bounce pad use a fixed reflection, authored impulse, controllable strength, or only orientation? | Determines whether placement remains understandable and deterministic | Start comparison with fixed strength plus orientation, but treat it as unapproved |
| Q-16 | When should damping, airflow, and gravity-zone stages enter after or around the core eleven-stage progression? | Changes teaching order, total content count, and when the device tray expands | Keep the accepted eleven-stage bounce progression intact until an expansion sequence is explicitly set |
| Q-18 | What exact damping, airflow, and gravity values and inventory limits remain understandable without prediction? | Changes physics tuning, readability, and solution tolerance | Keep damping strong but non-sticky, airflow modest and bounded, and gravity local and sharply downward; exact values remain tuning decisions |
| Q-19 | Which terrain topology is allowed: heightfield-only winding ground, disconnected islands, caves, bridges, overhangs, or some bounded subset? | Changes mesh representation, camera occlusion, placement normals, generator capability, and solver search space | Start with one connected heightfield-like course that bends laterally and changes elevation; do not accept overhangs or caves without a separate decision |
| Q-21 | Which authoring actions recur enough to justify a Godot editor plugin: route sketching, terrain regeneration, goal placement, stock editing, placement-volume preview, witness recording, or batch validation? | Determines whether a custom editor pays for itself and prevents premature tool scope | Author several stages with Resources and ordinary editor controls first, then build only the repeated high-cost actions into a plugin |

## Resolved Questions

| ID | Resolution | Owner |
| --- | --- | --- |
| Q-05 | A goal counts only after safe settlement. D-044 supersedes retained-ball display: completion is stored as goal state and the resolved ball is removed while its first-contact mark remains. | `DECISIONS.md` D-010 and D-044 |
| Q-06 | Retries are unlimited. There is no timer, lives, finite ball stock, or shot limit that can fail the stage. | `DECISIONS.md` D-011 |
| Q-11 | Confirmed goals persist and later shots cannot invalidate them, so multi-goal completion does not require several still-dynamic balls to remain settled simultaneously. | `DECISIONS.md` D-010 and D-011 |
| Q-15 | The selected additional vocabulary is a flat-surface damping pad, a mid-air placeable airflow device, and a bounded gravity-drop zone. | `DECISIONS.md` D-015 |
| Q-17 | Gravity zones, like every other route-changing mechanism, are placed by the player. | `DECISIONS.md` D-015 and D-016 |
| Q-01 | The first two courses expose horizontal aim `0..100`; `50` follows the hidden generated shot axis and the endpoints map to `-80..+80` degrees. Vertical angle and power remain independent controls. | `DECISIONS.md` D-023 |
| Q-02 | High-oblique is the default, side/profile is the alternate, Fire preserves the current camera, and explicit Shot Follow restores the stored planning pose and setup. | `DECISIONS.md` D-018 and D-029 |
| Q-03 | Impact priority fades by retained launch order, not elapsed time. | `DECISIONS.md` D-019 |
| Q-04 | The prototype retains five first-contact marks. | `DECISIONS.md` D-019 |
| Q-12 | The initial two-course prototype uses deterministic Paint Mountain-generated, connected heightfield mountains at original horizontal scale. Each locally concave terrain goal and the complete visible terrain pass the accepted real-ballistics admission contract. | `DECISIONS.md` D-021, D-024, and D-025 |
| Q-10 | Relay history originally preserved confirmed balls. D-044 supersedes that detail: a completed basin remains an optional launcher source after the resolved ball is removed; intermediate confirmation preserves unrelated live balls and does not clear the course. | `DECISIONS.md` D-030, D-031, and D-044 |
| Q-20 | Direct-shot certification repeats the center twice and checks all six axial one-unit control neighbors. Center must pass twice; at least four neighbors pass with one on each axis. Placement tolerances remain open with their device rules. | `DECISIONS.md` D-032 |
| Q-22 | Authors provide bounded course intent; an offline constraint resolver chooses exact goals and terrain adjustments, and real Godot physics certifies the immutable prepared artifact. Runtime does not generate. | `DECISIONS.md` D-032 |
| Q-23 | The current terrain-and-camera foundation is a fifteen-course prepared catalog: the original ten plus five harder courses. This resolves the current catalog count without starting the deferred device progression. | `DECISIONS.md` D-049 |

## Recommendations

- Resolve Q-07 through Q-09 and Q-14 before device-assisted multi-goal
  placement becomes an execution contract.
- Use the saved screen-direction storyboard as the visual brief for runtime
  composition and compare the implemented high-oblique and side views against
  it before expanding course production.
- Resolve Q-16, Q-18, Q-19 and Q-21 before expansion-mechanic implementation or
  a custom authoring tool becomes an execution contract.

## Limitations

- The table does not select answers on the user's behalf.
- Defaults described as safe boundaries prevent premature code decisions; they
  are not accepted product behavior unless moved to `DECISIONS.md`.
