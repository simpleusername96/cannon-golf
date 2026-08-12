# Cannon Golf

`Cannon Golf` is a provisional working title for a playable Godot 4 3D physics
puzzle prototype derived from the Paint Mountain runtime.

The app now opens at a main menu and provides a live two-course selection,
persistent settings, gameplay pause/return navigation, and two introductory
direct-shot courses. Adjust elevation and power, launch a rebound-capable ball,
learn from first-contact marks, and settle the ball safely inside the goal.
Retry is unlimited. High-oblique and side planning views preserve the current
launch setup and course state.

Both courses call Paint Mountain's retained route-graph mountain synthesizer,
then use its topology and geometry builders for the rendered and colliding
faceted mountain. Cannon Golf only scales that generated field and lowers the
samples around a selected high point into the shallow goal basin. The terrain
itself owns the goal floor and slope collision; the ring and flag are visual
markers. The game and menu preview share the retained panorama, open-ground
material, daylight palette, and restrained low-poly nature props.

The initial angle and power are intentionally not the solution. Each course
stores a separate solution witness that is replayed against the real rigid-body
simulation by the focused test suite.

Controls:

- `W` / `S`: elevation angle
- `A` / `D`: power
- `Space`: fire
- `1` / `2`: high-oblique / side view
- Arrow keys: explore the course
- Mouse wheel: planning zoom
- `R`: immediately relaunch with the current setup
- `Shift` + `R`: reset the current course and impact history
- `Esc`: pause or resume

Screen flow:

- Main menu -> Play or Course Select -> Gameplay
- Gameplay pause -> Settings, Course Select, or Main Menu
- Settings persist audio, reduced motion, display, quality, and language values

Run from the repository root with Godot 4.7.1:

```powershell
& 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64.exe' --path .
```

Focused validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-cannon-golf.ps1 -GodotPath 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
```

The retained `src/`, `scenes/`, `resources/`, and `tests/` Paint Mountain files
remain source-history material. The new main path is isolated under the
`cannon_golf` folders and does not use coverage, paint, exact prediction, finite
shots, or preinstalled mechanisms.

The current product definition lives in
[`project-specs/cannon-golf/PRD.md`](project-specs/cannon-golf/PRD.md). Visual
rules, research, decisions, open questions, and draft implementation tasks live
beside it. Do not infer later Cannon Golf behavior from legacy runtime names.
