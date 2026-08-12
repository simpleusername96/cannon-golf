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
| Q-01 | Does the player set raw yaw, elevation, and power; click a target; or combine both? | Determines input, solver, preview, HUD, accessibility, and camera ownership | Do not reuse the target-click inverse solver as the product decision |
| Q-02 | Which view is the default planning view, and how do top, side, oblique, cannon, and follow views transition? | Determines stage composition, occlusion rules, controls, and UI safe areas | Treat frontal-only planning as rejected |
| Q-03 | Do impact marks fade by shot order, real time, stage time, or a fixed retained count? | Determines data model, shader/decal lifecycle, replay, and readability | Preserve only the rule that newest is darkest and older is lighter |
| Q-04 | How many prior impact marks remain visible? | Too many create noise; too few weaken correction | Make the count a stage-independent tuning decision before content production |
| Q-05 | Does a ball remain physically in a completed hole, become locked/non-colliding, or disappear after confirmation? | Changes multi-ball collision, state, visuals, and clear logic | A completed hole must remain visibly occupied or unmistakably complete |
| Q-06 | Is the player given a shot limit, ball stock, timer, score, or only a retry count? | Changes failure, pacing, HUD, save data, and level balance | Do not carry Paint Mountain's shot/time rules automatically |
| Q-07 | Can pads be placed only before the first shot, between shots, or while balls are moving? | Changes state machine, undo, simulation determinism, and camera needs | No placement during live simulation unless explicitly approved later |
| Q-08 | Can a placed pad be moved, rotated, removed, or reused after a shot? | Changes interaction model and whether trial history remains comparable | Require explicit placement and orientation state in replays |
| Q-09 | What surface area and orientation constraints make pad placement legal? | Determines collision, UI feedback, trivial solutions, and level certification | Keep pads flush to valid terrain and visibly oriented |
| Q-10 | Are goals attempted in any order or assigned one at a time? | Changes planning, HUD, ball stock, and stage solution space | PRD currently allows any order but does not lock it |
| Q-11 | Must all balls remain settled simultaneously? | Changes whether later shots may knock out earlier successes | Do not certify multi-hole stages until this is decided |
| Q-12 | Which terrain family leads the first slice: quarry, crater chain, slot canyon, switchback, or another course? | Determines generator reuse, camera framing, art direction, and collision proof | Compare with a small graybox storyboard before selecting |
| Q-13 | Is `Cannon Golf` only an internal slug or a candidate public title? | Changes visible copy, package identity, save paths, and export naming | Keep it internal and do not rename runtime identifiers yet |
| Q-14 | Should a bounce pad use a fixed reflection, authored impulse, controllable strength, or only orientation? | Determines whether placement remains understandable and deterministic | Start comparison with fixed strength plus orientation, but treat it as unapproved |
| Q-15 | Which additional device, if any, is valuable after bounce is proven? | Changes stage vocabulary and UI inventory | Do not implement or display another device in the first slice |

## Recommendations

- Resolve Q-01 through Q-05 before camera/input/domain implementation.
- Resolve Q-06 through Q-11 before multi-hole stage state and UI work.
- Resolve Q-12 with a low-cost camera storyboard using the same simple graybox.
- Defer Q-15 until a bounce-pad stage is demonstrably fun and readable.

## Limitations

- The table does not select answers on the user's behalf.
- Defaults described as safe boundaries prevent premature code decisions; they
  are not accepted product behavior unless moved to `DECISIONS.md`.
