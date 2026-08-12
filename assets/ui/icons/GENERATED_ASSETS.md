---
type: record
status: active
created: 2026-08-10
last_reviewed: 2026-08-10
source: ../../../docs/reports/screen-audit-2026-08-10/assets/refined/08-settings-refined.png
related:
  - ../../../docs/reports/screen-audit-2026-08-10/assets/refined/02-stage-select-refined.png
  - ../../../.agents/execplans/2026-08-10-approved-image-fidelity-correction.md
  - ../../../.agents/execplans/2026-08-10-essential-ui-fidelity.md
---

# Generated UI Asset Record

## Context

The approved Stage Select, Settings, and Timeout Result images contain a
selected-card badge, seven semantic setting icons, full-size switch states, a
slider grabber, and a timeout clock that did not exist in the repository. Text
symbols, emoji, handcrafted SVG, and code-drawn stand-ins were excluded by the
fidelity contracts.

## Decision

The built-in ImageGen path generated each raster asset separately, using the
matching approved refined screen as the sole visual reference. Each prompt
requested a crisp flat Paint Mountain UI asset in the existing navy/blue/neutral
palette on a solid green chroma background. The installed image-generation
helper removed that background, and ImageMagick performed deterministic native
size and padding normalization.

| Asset | Runtime role | SHA-256 |
| --- | --- | --- |
| `stage_check.png` | selected-stage check badge | `CF6DA16BE61AEAFF059BE1CA970D9B0F4F45F7DFB9F1688D0C285E838E261919` |
| `settings/volume_master.png` | master volume speaker | `DF0D4DCDED2A627979FE1449D469988A255ADE2BEDB65583DDB6CF2A3B92D25D` |
| `settings/volume_music.png` | music note | `910E92E16939E60D755230159C131C467A7AB00AB48884A346D9C5593314A05E` |
| `settings/volume_sfx.png` | sound-effects waveform | `F74FF7E7372CF64D4B7C801BC0A207922EDAA86F599167C2917C0B458D6D5CF9` |
| `settings/display.png` | display/fullscreen monitor | `4D36B4506652DC894EFB3D4F976A0D374E488EE64B77414CC0108D0E3B2247A5` |
| `settings/camera_shake.png` | camera shake | `DE5506A88A4D7498AE43E1F37BC82F418AC42A4777498EE61E7F7858C80FBE27` |
| `settings/reduced_motion.png` | reduced motion | `279E07612602A2B93BDE8D519C44D1719EEC48EDFA58D549B3E57D29F490C239` |
| `settings/trajectory.png` | trajectory preview | `D388DF8624C2F7FB91D28B058BAFAF8FA8BEEFA63EEFC9C3E5AB6A4D42DFE790` |
| `settings/switch_on.png` | checked switch, 52 by 28 px | `1DA9556E45B9573FD77D98F5DB60D8505428D13EDC67D08E793F1794EAC17D31` |
| `settings/switch_off.png` | unchecked switch, 52 by 28 px | `F88FA1F4128E33E5AA51A7F4BA7D5EF35DD3243F5D55DB953DA1D8FA0584A7B8` |
| `settings/slider_grabber.png` | audio slider grabber, 18 px | `C7A6A29AC44DD7283AAD6923D53EA3B3E397E9FA47DBB0A9341EA37EAC327E72` |
| `result_timeout_clock.png` | timeout-result clock | `A2D4B6D57114BB3236413D10598D553301EF92102C1E0B8EA81AF1375F175E46` |

## Rationale

Separate generation kept each icon legible at its real slot and avoided a
cropped sprite sheet. The approved images already fixed the desired family,
palette, and density, so the prompts did not introduce another icon direction.
The assets supplement visible text labels and do not replace accessible names.

## Consequences

- Runtime scenes may use these project-generated files without a third-party
  license or external package.
- The PNG source plus committed Godot import metadata is the editable runtime
  boundary; generated working files outside the repository are not required.
- Any later replacement must preserve semantic meaning, native-size clarity,
  transparency, and the Quiet Context palette.
