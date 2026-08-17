# Cannon Golf

`Cannon Golf` is a provisional working title for a playable Godot 4 3D physics
puzzle prototype derived from the Paint Mountain runtime.

The app now opens at a main menu and provides a live two-course selection,
persistent settings, gameplay pause/return navigation, and two introductory
direct-shot courses. Adjust horizontal aim, vertical angle, and power, launch a
rebound-capable ball, learn from first-contact marks, and settle it safely
inside the goal. Retry is unlimited. High-oblique and side planning views
preserve the complete launch setup, exploration state, and impact history.
Firing leaves the current camera exactly where the player put it; the follow
icon explicitly enters ball follow when wanted. The controls remain available
and the player can keep launching immediately. At most four unconfirmed balls
remain in active simulation; a fifth launch replaces only the oldest unresolved
ball and keeps its impact mark. In planning, left-drag orbits around a fixed
course focus, the wheel zooms, and clicks without dragging do not jump the camera
pivot.

Both courses call Paint Mountain's retained route-graph mountain synthesizer,
then use its topology and geometry builders for the rendered and colliding
faceted mountain. The two courses retain the original `210 x 120` metre
horizontal extent, use `0.45` vertical scale, and place the cannon 75 metres
behind the route. Generation fails if any playable top or visible support-shell
point falls outside the legal real-ballistics envelope and its safety margins.
Cannon Golf lowers samples around the selected high point into a 10 metre,
3.5 metre-deep concave basin whose center is lowest. The terrain itself owns all
goal collision; the ring and enlarged flag are non-colliding markers. The game
and menu preview share the retained panorama, open-ground material, daylight
palette, and restrained low-poly nature props.

Horizontal aim, vertical angle, and power all visibly start at `50`. That
`50 / 50 / 50` setup intentionally misses. Each course stores a separate
three-value solution witness that is replayed against the real rigid-body
simulation by the focused test suite. Normal play shows no trajectory, landing
prediction, range dome, course prose, progress card, or permanently open help.
The `?` camera-dock action opens the complete shortcut panel when needed.

Controls:

- `Q` / `E`: horizontal aim
- `W` / `S`: elevation angle
- `A` / `D`: power
- Each launch axis also has hold-repeat `−` / `+` buttons and a direct slider
- `Space`: fire without changing the current camera
- `1` / `2`: high-oblique / side view
- `Tab`: return immediately from ball follow to the stored planning view
- Follow icon: enter or leave follow for the newest live ball
- Left-drag terrain: orbit around the fixed planning focus
- Arrow keys: pan across the course
- Mouse wheel or the compact `+` / `−` actions: planning zoom
- `Home` or the compact center camera action: restore the authored planning view
- `R`: while a shot is active, replace only the newest ball and immediately relaunch
  with the same setup; camera state and impact marks remain
- `Shift` + `R`: reset the current course and impact history
- `Esc`: pause or resume
- `?` icon: open the shortcut explanation panel; `Esc` closes it before pausing

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
