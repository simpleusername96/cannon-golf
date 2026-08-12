---
type: record
status: active
created: 2026-08-03
last_reviewed: 2026-08-11
scope: approved third-party runtime assets, provenance, hashes, licenses, and uses
related:
  - ../.agents/Plan.md
  - ../assets/licenses/Kenney-Nature-Kit-CC0.txt
  - ../assets/licenses/Kenney-Game-Icons-CC0.txt
  - ../assets/licenses/Kenney-Particle-Pack-CC0.txt
  - ../assets/licenses/Kenney-Skyboxes-CC0.txt
  - ../assets/licenses/ambientCG-Ground003-CC0.txt
  - ../assets/licenses/Pretendard-OFL-1.1.txt
---

# Third-party asset ledger

Only the files listed below are approved and bundled. Runtime loading is entirely local; the game does not download assets or contact these sources.

## Source archives

| Package | Version/source date | License | Official archive | Archive SHA-256 |
| --- | --- | --- | --- | --- |
| Kenney Nature Kit | official archive retrieved 2026-08-03 | CC0 1.0 | `https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip` | `FA7974A0D342BFE63C38664BA9F8EC1A4AAB8EA25F099BDC56870E33588C4D9D` |
| Kenney Game Icons | official archive retrieved 2026-08-03 | CC0 1.0 | `https://kenney.nl/media/pages/assets/game-icons/1ebf9c14af-1677661579/kenney_game-icons.zip` | `7A86D8D58E0B851E22004B3C70BF90B003632BBF9AC633424DAA3BB17D9E7E4E` |
| Kenney Particle Pack | official archive retrieved 2026-08-03 | CC0 1.0 | `https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip` | `B631D4B07F7002549FDCF155F01141AD482F79F3440E4E301EED49CE5F1D8958` |
| Kenney Skyboxes | official archive retrieved 2026-08-11 | CC0 1.0 | `https://kenney.nl/media/pages/assets/skyboxes/6736ff5c10-1784123473/kenney_skyboxes.zip` | `FF339713105FE1B777ECAFA0B66094E8FB1431CFCF88DF761B9AD015AADF4028` |
| ambientCG Ground 003 | official 1K JPG archive retrieved 2026-08-11 | CC0 1.0 | `https://ambientcg.com/get?file=Ground003_1K-JPG.zip` | `ADCA98D94C5934F9DE184712540A51AF2591194B6C020F3831CA6B788388CE11` |
| Kenney UI Pack | 2.0, 2024-06-12; retrieved 2026-08-08 | CC0 1.0 | `https://kenney.nl/media/pages/assets/ui-pack/f651646eab-1718203990/kenney_ui-pack.zip` | `A8A14A234911EB648C062622915C93E79E94E97CB7F9F375A70F6617F1174318` |
| Pretendard | 1.3.9 | SIL Open Font License 1.1 | `https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip` | `04BE351A74D6BF7D60C480A3087E51D185485D35A52023142AF1DF19EB8C428A` |

## Bundled files

| Local file | SHA-256 | Runtime use |
| --- | --- | --- |
| `assets/nature/kenney/tree_pineSmallA.glb` | `BE1A438BBB2E157266C1FB093B775BFF8CE3E29A4C8F04AAF9D44C7A4E1F1FF0` | small pine variant A |
| `assets/nature/kenney/tree_pineSmallB.glb` | `59392AA6604ADB9DCCD4FB76DF5ED12AE8AC7D7391EB7E04BC84FFFE9F9B36C8` | small pine variant B |
| `assets/nature/kenney/tree_pineTallA.glb` | `E0A56EB196D8A64BA86C7304D607136E17E6F9AD748DFFCF86BD53B18B91B196` | tall pine |
| `assets/nature/kenney/rock_smallA.glb` | `DF9FFF9D711E61370E8DF0CAA2514C89B8F8A8DC6C6FAFAF4EB2EC79C5AE07C1` | small rock |
| `assets/nature/kenney/rock_largeA.glb` | `6DD15390FD96501DCD1454765A17BA61DBBD8D47705DFE5149C8DD92B353CE25` | large rock |
| `assets/environment/kenney/skybox-day.png` | `B7D98FE95157E74B3899A1DD468A1E478005BCD1F668B29B5B42A48CB5358FA2` | restrained daytime panorama sky |
| `assets/environment/ambientcg/Ground003_1K-JPG_Color.jpg` | `97849943AD98437D84FBB257A5D498134FBE52308EBB3985DAB6577514A86037` | muted open-ground color variation |
| `assets/ui/icons/target.png` | `AFD40325569FA91BFC690856DC4C70901BBD7C2E27DEDC9FE3847258C61BBC81` | aim mode |
| `assets/ui/icons/minus.png` | `5F4E70ADEA9061D0105DB1860108B669E348D0D99314542A77DD96F707800EC7` | decrease power |
| `assets/ui/icons/plus.png` | `DC5D564FFE3AE546F2E72CE19EA8349124CF48256418DE50BB045A5D97AB9872` | increase power |
| `assets/ui/icons/settings.png` | `50B313FFE97DB1733E529D5B0F5AC91EED5C0C8FFEE1034BBB7766508E4F720C` | settings |
| `assets/ui/external/kenney_ui_pack_2/panel_neutral_depth.png` | `7DE9BA1D4BCA313FD2C02E3595F3D699C1201D84D70A3C69828E56782D585CE7` | shared tactile neutral button/card edge |
| `assets/ui/external/kenney_ui_pack_2/panel_neutral_flat.png` | `C91EE37858BE6035143A8AE26588741E9350E5F42AED548E3EE00910092239E8` | shared neutral button/card surface |
| `assets/ui/external/kenney_ui_pack_2/button_primary_depth.png` | `6C709A45AAE0330FFFF5B060D9F14CC2297839F664E0A4C9E516D90AD085EC0B` | shared primary button normal state |
| `assets/ui/external/kenney_ui_pack_2/button_primary_flat.png` | `83084C953E57D7506F90600DF77F36A8C6156ABEA0B8EA0E4B3885A596CEE2C8` | shared primary button hover/pressed state |
| `assets/ui/external/kenney_ui_pack_2/button_danger_depth.png` | `8DD648EA9B80A780FB387C235D4F6BBDADD4F4768C663639EDB2C7E5174A69F0` | shared danger button state |
| `assets/vfx/kenney/muzzle_ring.png` | `4B2D03683BF0FE4A946567ADC3BD86B8BA045DA84CEE58DC2CF8AEF63BBFAA06` | muzzle ring |
| `assets/vfx/kenney/impact_ripple.png` | `742DA1A1B96B93AE446700F6085385D1F62844352DA870C89427307B7B7CF03B` | impact ripple |
| `assets/vfx/kenney/paint_mist.png` | `A71F8ABCAC64F8D73A94625CC9A10033DBEAFA7EAEA750560CBA0DAA73FE8752` | paint mist |
| `assets/vfx/kenney/glint.png` | `6485AC16C773663BD39346F3BEDAE04465AC14C661EB47CC5CFA935CDBF6C2EC` | mechanism and clear glint |
| `assets/fonts/pretendard/PretendardVariable.woff2` | `9599F12FD42FC0BCE1CD50B47A0C022E108D7AA64DD0D1BB0ED44F3282D900B4` | Korean/English UI font |

Upstream license texts are stored under `assets/licenses/` or beside their
tightly scoped imported subset. The UI Pack copy has whitespace-only
normalization; its archive hash identifies the byte-exact source package. No
unlisted member of the downloaded archives is committed.

## Project-generated UI assets

The Stage Select, Settings, and Timeout Result fidelity assets under `assets/ui/icons/` are
original project-generated raster files, not third-party package members. Their
generation source, runtime role, and SHA-256 values are recorded in
`assets/ui/icons/GENERATED_ASSETS.md`.
