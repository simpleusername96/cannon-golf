---
type: evidence
status: active
created: 2026-08-18
topic: Cannon perspective camera controls
scope: Comparable camera-control patterns and their applicability to Cannon Golf
related:
  - project-specs/cannon-golf/PRD.md
  - project-specs/cannon-golf/DESIGN_RULES.md
  - project-specs/cannon-golf/DECISIONS.md
---

# Cannon Perspective Camera Control References

## Purpose

This document compares established camera controls from vehicle combat, 3D
object inspection, and scene-navigation tools. It is consult-only evidence for
replacing Cannon Golf's current constrained local camera, not a product spec.

## Sources

- [World of Tanks controls](https://worldoftanks.com/en/content/guide/newcomers-guide/game_controls/): its behind-vehicle arcade camera lets the player look around without moving the gun, while artillery view is a separate explicit mode.
- [Godot 4.7 3D navigation](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html): its spatial viewport orbits around a stable screen center and provides configurable, established navigation schemes.
- [Godot EditorSettings navigation schemes](https://docs.godotengine.org/en/4.0/classes/class_editorsettings.html): Godot, Maya, and Modo schemes consistently separate orbit, pan, and wheel zoom; the same documentation notes that increased camera inertia adds latency.
- [Unity Scene view navigation](https://docs.unity3d.com/Manual/SceneViewNavigation.html): orbit acts around the current pivot, pan translates the view, wheel zoom changes distance, and an explicit command re-centers a selected object.
- [Autodesk MotionBuilder camera navigation](https://help.autodesk.com/cloudhelp/2026/ENU/MotionBuilder-Reference/files/MotionBuilder-Windows/Viewer-window/GUID-3009A4DD-DCFA-46E3-BC57-1344E8F9B7DA.html): orbit revolves a camera around its interest; travelling moves camera and interest together; dolly changes their separation.

## Findings

### Local implementation facts

- Cannon Golf currently looks at a synthetic point `12 m` along the launch ray,
  then rotates a camera offset around that point. The visible cannon is not the
  stable subject of the orbit.
- Left-drag pans and right-drag orbits. Cannon pan, yaw, pitch, and zoom each
  have unrelated hard limits. Increasing those limits made the camera travel
  farther but did not make its spatial model understandable.
- Input changes are eased by the regular planning-camera interpolation. During
  continuous manipulation, the rendered pose chases a moving target and reads
  as lag or shaking rather than direct control.
- Aim keys already occupy `WASD` and `Q/E`; copying a first-person or RTS
  keyboard camera would conflict with the primary launch controls.

### Cross-reference patterns

- Vehicle combat separates camera observation from weapon orientation. A look
  action should not rotate the cannon or edit the shot.
- Orbit viewers use a persistent subject or interest as their pivot. Pan moves
  that interest, and zoom changes camera-to-interest distance; those operations
  do not silently switch to a map camera.
- Full-map or artillery presentation is an explicit mode, not a side effect of
  dragging or zooming a local perspective.
- Direct manipulation benefits from low or no interpolation. Smoothing that
  continues after input adds latency and makes the camera feel detached.
- Horizontal orbit is normally continuous. Vertical orbit is clamped before
  the camera flips, while zoom is clamped before clipping through the subject.

## Recommendations

- Replace the current forward-ray local camera with a subject-centered orbit
  viewer. Use the selected cannon's authored anchor as the stable interest.
- Adopt a common two-button viewer mapping: left-drag orbits, right-drag pans,
  and the wheel dollies. Arrow keys remain a pan fallback because `WASD` and
  `Q/E` belong to aiming.
- Keep cannon orientation and launch setup independent from the camera. Aiming
  changes the barrel and aim cues only.
- Allow continuous `360°` horizontal orbit and a non-flipping vertical arc.
  Clamp pan to the prepared course bounds rather than an arbitrary small radius.
- Apply direct Cannon manipulation immediately. Preserve easing only for
  authored preset transitions and other camera families where it is useful.
- Keep Overview as an explicit button/shortcut. Cannon input must never select
  Overview, and Cannon orbit must never converge on Overview's authored pose.
- Reselecting Cannon, `Home`, or selecting another cannon source restores the
  authored rear-upper pose and clears its independent orbit-viewer state.

## Limitations

- The cited products have different goals and input densities. This proposal
  transfers their spatial model, not every shortcut or modifier.
- The project needs a ground-aware pan adaptation because unconstrained screen-
  plane pan can move the interest into the sky or below terrain.
- Final sensitivity, pitch, distance, and collision values still require a
  rendered check against Cannon Golf's prepared course extremes.
