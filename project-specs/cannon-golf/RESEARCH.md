---
type: evidence
status: active
created: 2026-08-12
topic: 3D cannon golf, planning cameras, impact history, and placeable trajectory devices
scope: Comparative product and visual references; consult only
source: Local Paint Mountain evidence and primary developer or storefront pages reviewed on 2026-08-12
related:
  - PRD.md
  - DESIGN_RULES.md
  - DECISIONS.md
---

# Cannon Golf Research

## Purpose

Record the closest reference games and local visual evidence without treating
any reference as the product specification. The build case is the combination:
no reviewed product joins 3D cannon estimation, multiple physical holes,
recency-ordered first-impact history, and player-placed bounce pads in the same
loop.

## Sources

### External product references

| Reference | Directly evidenced behavior | Useful lesson | Important gap |
| --- | --- | --- | --- |
| [Golf Peaks](https://store.steampowered.com/app/923260/Golf_Peaks/) | Isometric mountain golf puzzles; choose a stroke card and direction to reach a hole | High-oblique course readability, compact stages, gradual teaching | Turn-based card movement rather than physical cannon estimation |
| [Golf On Mars](https://store.steampowered.com/app/1340570/Golf_On_Mars/) | Side-view golf across long rocky terrain with altered gravity | Side/profile composition can make elevation and long-range correction readable | 2D, one-hole procedural golf; no devices or impact history |
| [Cannon Golf](https://jwd.itch.io/cannon-golf) | Cannon-launched golf across 54 holes with specialized shells | Cannon plus hole is an understandable product metaphor | 2D side view; no placeable devices or ordered impact memory |
| [Launch Ball](https://store.steampowered.com/app/3213560/Launch_Ball/) | Position a cannon and launch a ball at a target across authored physics puzzles | Minimal launch-correct-retry loop | 2D and box-targeted rather than multi-hole 3D golf |
| [Fantastic Contraption](https://store.steampowered.com/app/386690/Fantastic_Contraption/) | Build physical machines to carry a ball-like object to a distant goal | Player ownership of a physical route and readable device causality | Broad contraption building is much larger than the intended pad scope |
| [Crazy Machines 3](https://store.steampowered.com/app/351920/Crazy_Machines_3/) | Place missing pieces into physics chain reactions | Device placement should expose orientation and cause/effect before simulation | Rube Goldberg sandbox complexity would overwhelm the aiming loop |
| [Launchball](https://www.sciencemuseumgroup.org.uk/learning/resources/launchball-game/) | Thirty obstacle levels and a level creator built around springing a ball through a course | Small mechanical vocabulary can teach through authored obstacle stages | The official summary does not establish the exact desired cannon or multi-hole rules |
| [Aperture Tag](https://store.steampowered.com/app/280740/Aperture_Tag_The_Paint_Gun_Testing_Initiative/) | A first-person 3D paint gun applies movement-altering surface gels | A surface effect can communicate speed or rebound through material and shape | It is a player-navigation puzzle; paint changes mechanics and is not just impact memory |
| [Worms design comparison](https://www.team17.com/news/team17s-100-games-part-eighteen-2017-the-escapists-2-yooka-laylee-more) | Team17 describes Worms play in terms of power, angle, and wind | Result-based artillery correction remains legible without reflex control | Combat, destructible terrain, wind, and weapon variety are outside scope |

### Local Paint Mountain baseline

- Source repository: `D:/npjt/paint-mountain` at commit `32c0b33`.
- Copied unchanged: `assets/`, `resources/`, `scenes/`, `scripts/`, `src/`,
  `tests/`, `translations/`, Godot project/export files, editor attributes, and
  asset-license documentation.
- Deliberately not copied: Paint Mountain product briefs, historical evidence,
  screenshots as runtime deliverables, prototypes, root agent policy, and the
  itch.io deployment workflow.
- Candidate reusable boundaries include cannon ballistics, projectile contact,
  terrain collision, camera coordination, typed Resources, Korean-first UI,
  localization, persistence, and automated tests.
- Known conflicting boundaries include continuous paint/coverage, target masks,
  exact predicted impact, broad mountain generation, fixed generated mechanisms,
  and coverage-based stage results.

### Local visual references

#### HUD qualities to retain

![Paint Mountain HUD comparator](assets/paint-mountain-hud-comparator.png)

- File: `assets/paint-mountain-hud-comparator.png`
- SHA-256: `38F75235B126CC5995BA53E61665AEE9DCD397B27CA92939B08BE90ED10E76B1`
- Retain: Korean-first typography, warm paper-white field, navy hierarchy, blue
  primary action, edge alignment, restrained containment.
- Do not retain: coverage rail, paint iconography, exact predicted impact,
  broad frontal mountain, or the current world-camera relationship.

#### Paint Mountain world comparator

![Paint Mountain world comparator](assets/paint-mountain-world-comparator.png)

- File: `assets/paint-mountain-world-comparator.png`
- SHA-256: `1E32C82DF16DBE0809458DC7A7D9385C7EB3A61D0240BD8551B40F02190E4538`
- Retain: tactile low-poly depth, readable physical routes, sparse environment,
  strong gameplay accents.
- Do not retain: terrain coverage, continuous blue routes, fixed mechanisms,
  frontal-wide composition, or literal topology.

#### Early concept: ascending slot canyon

![Ascending slot canyon concept](assets/early-concept-ascending-slot-canyon.png)

- File: `assets/early-concept-ascending-slot-canyon.png`
- SHA-256: `47909C628FF0A00FA0655FD37F7658502C0AE21F17E2E5D8DBD7E08402FBCD8C`
- Useful: long course, physical holes, settled ball, ordered impact marks.
- Rejected as a camera target: still too frontal and compresses the route into a
  centered climb.

#### Early concept: stacked quarry spine

![Stacked quarry spine concept](assets/early-concept-stacked-quarry-spine.png)

- File: `assets/early-concept-stacked-quarry-spine.png`
- SHA-256: `6267464E038865B11C56425801A3127284458865719A0EC2EA645ADC56958616`
- Useful: strong vertical separation and readable pad orientation.
- Rejected as a camera target: still uses the inherited cannon-frontal hierarchy
  and does not demonstrate top or side planning.

#### Early concept: crater garden run

![Crater garden run concept](assets/early-concept-crater-garden-run.png)

- File: `assets/early-concept-crater-garden-run.png`
- SHA-256: `376CDD04BB784E56071967F81139535B8820710850655ABFD51E4C99717942DC`
- Useful: a non-mountain terrain family, recessed goals, and wall-mounted pads.
- Rejected as a camera target: the framing remains mostly frontal and the basins
  need plan/profile views to communicate their true shape.

## Findings

- `3D golf` is the clearest public-facing shorthand, while `artillery` explains
  the launch controls and repeated estimation.
- Golf Peaks demonstrates that a high-oblique view can make a whole compact
  course legible without a behind-ball camera.
- Golf On Mars and Cannon Golf demonstrate that a side view is strong for
  elevation and power correction.
- Contraption games demonstrate the appeal of authoring part of the route, but
  their tool breadth would dilute the current product. One pad is a better MVP.
- The early generated images capture holes, balls, marks, and pads but do not
  solve the user's camera concern. Their camera is evidence of what to change.
- Paint Mountain's HUD system is more reusable than its world composition or
  product semantics.
- This is not a weak build case: no reviewed reference supplies the complete
  combination, and the existing local runtime materially reduces technical
  startup cost.

## Recommendations

- Make the next visual study a camera storyboard, not another polished frontal
  gameplay mockup.
- Compare the same graybox from true top, high-oblique, true side, near-profile,
  and temporary launch-follow views.
- Keep only the bounce pad until the direct-shot and impact-history loop tests
  well.
- Audit candidate code owners against `PRD.md` before any rename or rewrite.

## Limitations

- Store pages describe marketed behavior, not full control details or physics
  tolerances.
- The local early concepts are generated illustrations, not feasible geometry,
  runtime screenshots, or approved layouts.
- No current image demonstrates the required final camera grammar.
- Exact aiming controls, camera transitions, mark retention, pad editing, and
  occupied-hole behavior still require owner decisions.
