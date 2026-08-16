---
type: evidence
status: active
created: 2026-08-16
topic: Cannon Golf HUD and in-game UI/UX references
scope: Reference synthesis and concept constraints; consult-only and not a product specification
related:
  - ../../../project-specs/cannon-golf/PRD.md
  - ../../../project-specs/cannon-golf/DESIGN_RULES.md
  - RESEARCH.md
---

# Cannon Golf HUD·UIUX 레퍼런스 조사

## Purpose

현재 Cannon Golf의 HUD가 실제 플레이 화면을 가리고 조작 관계를 불명확하게 만드는 원인을 확인하고, 외부 사례에서 재사용할 원칙과 배제할 패턴을 정리한다. 이 문서는 참고 근거이며 제품 사양을 대체하지 않는다.

## Sources

### 로컬 구현과 화면

- `scenes/cannon_golf/cannon_golf_hud.tscn`
- `src/cannon_golf/cannon_golf_hud.gd`
- `resources/ui/paint_mountain_theme.tres`
- `.godot/capture-temp/hud-audit/current-lv5.png`
- `.godot/capture-temp/hud-audit/current-lv5-cannon.png`
- `.godot/capture-temp/hud-audit/current-lv5-shortcuts.png`
- `project-specs/cannon-golf/assets/hud-concepts-2026-08-16/`
- `.agents/evidence/cannon-golf/hud-references-2026-08-16/nintendo-mario-golf-shot-screen.jpg`
- `.agents/evidence/cannon-golf/hud-references-2026-08-16/nintendo-mario-golf-terrain-scan.jpg`
- `.agents/evidence/cannon-golf/hud-references-2026-08-16/playstation-returnal-hud.jpg`
- `.agents/evidence/cannon-golf/hud-references-2026-08-16/wot-modern-armor-aim-reticle.jpg`

### 외부 자료

- [Nintendo — Planning your shot in Mario Golf: Super Rush](https://www.nintendo.com/us/whatsnew/planning-your-shot-in-mario-golf-super-rush/)
- [Nintendo — Mario Golf: Super Rush](https://www.nintendo.com/au/games/nintendo-switch/mario-golf-super-rush/)
- [PGA TOUR 2K23 PC manual](https://assets.2k.com/1a6ngf98576c/3guOTy0PZbaDMW5SVxuRPY/cff247d63d276d816644329aaf09745c/2KSWIN_PGA2K23_PC_Online_Manual_ENG.pdf)
- [Team17 — Worms W.M.D. Mobilize](https://www.team17.com/news/worms-w-md-mobilize-out-now-on-apple-android) — 페이지에 제공된 이미지는 플레이 HUD가 아니어서 시각 근거에서 제외
- [Poly Bridge manual](https://cdn.steamstatic.com/steam/apps/367450/manuals/ManualPFDable.pdf?t=1567634023)
- [PlayStation Blog — Returnal UX design](https://blog.playstation.com/2021/05/11/unpacking-returnals-ux-design-gameplay-first-ui-retro-futuristic-tech-and-accessibility/)
- [EA — Star Wars: Squadrons gameplay settings](https://www.ea.com/able/resources/star-wars/star-wars-squadrons/xbox-one/gameplay-settings)
- [EA — F1 22 on-screen display](https://www.ea.com/able/resources/f1-22/ps5/on-screen)
- [Epic Games — HUD Controller](https://dev.epicgames.com/documentation/en-us/fortnite/using-hud-controller-devices-in-fortnite-creative)
- [Microsoft — Xbox Accessibility Guideline 101: Text display](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
- [Microsoft — Xbox Accessibility Guideline 102: Contrast](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102)
- [Microsoft — Xbox Accessibility Guideline 107: Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)
- [Microsoft — Xbox Accessibility Guideline 117: Visual distractions and motion](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117)

## Findings

### 현재 화면에서 확인한 문제

- 1280×720 기준 조준 패널은 폭 792px, 높이 94px이며 화면 아래 중앙까지 침범한다. 대포 시점에서는 대포와 발사 방향이 있는 중심부를 직접 가린다.
- 상단의 진행 정보는 높이 42px인데 대포 위치 선택기는 높이 68px이다. 한 줄처럼 보이지만 기준선과 밀도가 다르다.
- 카메라, 따라가기, 재발사 버튼이 Unicode 기호만 사용한다. 서로 다른 기능의 의미를 화면만 보고 안정적으로 구분하기 어렵다.
- 카메라 dock, action dock, 조준 패널이 서로 다른 크기와 정렬 규칙을 사용한다. 사용자는 기능 관계보다 독립된 흰 상자 여러 개를 먼저 인식한다.
- 조작법 패널은 필요한 정보를 제공하지만 356×422px로 크고, 열린 상태에서 지형과 목표를 가린다.
- 이전 세 시안도 같은 문제를 완전히 벗어나지 못했다. 실제 조작 위계를 다시 설계하기보다 기존 상자를 화면 가장자리에 재배치했고, 일부 안은 큰 좌측 패널이나 넓은 하단 띠를 새로 만들었다.

### 외부 사례에서 활용할 원칙

| 원칙 | 외부 근거 | 이 프로젝트에 적용하는 방식 |
| --- | --- | --- |
| 플레이 화면이 1순위다 | Returnal은 핵심 정보만 시선 중심 근처에 두고 비핵심 정보는 주변부로 보낸다. Poly Bridge는 물리 결과 단계에서 제작 UI를 걷어낸다. | 지형, 대포, 짧은 조준 곡선이 HUD보다 먼저 보이게 한다. 패널을 화면 중앙에 걸치지 않는다. |
| 조준과 발사는 하나의 읽기 흐름이다 | Mario Golf와 PGA TOUR 2K는 방향·강도 조절과 shot action을 하나의 준비 흐름으로 묶는다. Worms는 aim–power–fire 순서를 명확히 한다. | `좌우 → 상하 → 파워 → 발사`의 순서를 정렬과 강조로 표현한다. Fire만 주 CTA로 유지한다. |
| 카메라 상태가 UI 밀도를 결정한다 | F1 22와 Squadrons는 뷰나 플레이 상태에 따라 HUD 요소를 선택적으로 표시한다. Epic HUD Controller도 contextual display를 지원한다. | Overview에는 탐색 도구를, Cannon에는 조준 도구를 우선한다. Follow 중에는 결과 관찰을 방해하는 보조 조작을 줄인다. |
| 중요한 표시는 움직이는 배경과 독립적으로 읽혀야 한다 | XAG 101/102는 HUD 텍스트와 비텍스트 표시에 충분한 크기·대비·윤곽을 요구한다. | 따뜻한 불투명도 높은 표면, navy 텍스트, blue 상태색, 명확한 외곽선과 focus 상태를 사용한다. 색만으로 선택 상태를 전달하지 않는다. |
| 입력 방식이 달라도 같은 값에 접근할 수 있어야 한다 | XAG 107은 대체 입력과 single-press 조정을 권장한다. | 각 조준값의 `− / slider / +`와 키보드 조작을 유지한다. drag-only·hold-only 조작은 사용하지 않는다. |
| 카메라는 플레이어가 복귀시킬 수 있어야 한다 | XAG 117은 비의도적 자동 카메라 움직임과 모션 조절을 점검한다. PGA TOUR 2K는 별도 camera/map 입력을 둔다. | Follow에서 Overview/Cannon으로 즉시 복귀할 수 있게 하고, HUD가 자동 retarget을 암시하지 않게 한다. |

### 실제 레퍼런스 이미지 확인 결과

- Mario Golf shot 화면은 캐릭터 주변의 중앙 플레이 공간을 유지하면서 상태를 좌상단, power/club 계기를 오른쪽 가장자리에 둔다. 다만 미니맵, 스코어, 바람, 클럽 목록, 거리 수치가 동시에 보여 Cannon Golf에 그대로 적용하면 과밀하다.
- Mario Golf terrain scan은 별도 분석 화면으로 전환해 고저차를 읽게 한다. 이 분리는 참고할 수 있지만, 정확한 거리·고도 격자는 Cannon Golf의 추정 플레이와 충돌하므로 사용하지 않는다.
- Returnal 화면은 작은 reticle 주변에 즉시 필요한 정보만 두고, 체력·상태·맵을 하단 모서리로 밀어 중앙 전투 공간을 비운다. 시각 스타일은 맞지 않지만 중심/주변부 위계는 유효하다.
- World of Tanks 화면도 reticle과 포신의 중앙 축을 비우고 상태를 가장자리로 보낸다. 하지만 미니맵, 체력, 탄약, 팀 상태는 모두 비차용 대상이다. 공식 가이드 이미지의 큰 빨간 화살표는 설명용 주석이지 실제 HUD가 아니므로 참고하지 않는다.
- Team17 페이지의 확인 가능한 이미지는 training/campaign 메뉴다. 포병 게임이라는 장르 유사성만으로 HUD 근거로 사용하면 안 되므로 이미지 시안 입력에서 제외한다.

### 배제할 레퍼런스 패턴

- Mario Golf와 PGA TOUR의 정확한 예상 착지점, 거리 링, 상세 고저차 그래프는 사용하지 않는다. Cannon Golf의 반복 관찰 학습을 약화한다.
- 전투 게임의 미니맵, 체력, 탄약, 목표 로그, 적 방향 표시는 사용하지 않는다.
- F1·Squadrons의 광범위한 HUD 사용자 설정을 현재 범위에 추가하지 않는다. 우선 기본 HUD 한 벌이 정상적으로 작동해야 한다.
- Poly Bridge의 제작 툴바나 Kerbal 계열의 항공 계기는 현재 세 개의 조준값보다 많은 정보를 요구하므로 사용하지 않는다.
- 정확한 trajectory, landing marker, 목표를 향한 waypoint는 제품 사양과 직접 충돌한다.
- 색만으로 goal 완료나 선택 상태를 표현하는 패턴은 사용하지 않는다.

## Recommendations

세 시안은 같은 기능 계약과 같은 1280×720 대포 시점을 사용하되, 다음 배치 전략만 다르게 탐색한다. 실제 외부 이미지를 확인하기 전에 만든 초안은 근거 부족으로 채택 후보에서 제외했다.

1. Right-edge shot meter: 모든 조준값과 Fire를 오른쪽 가장자리에 모아 대포와 중앙 조준축을 비운다.
2. Upper instrument ribbon: 세 조준값을 지형선 위의 얇은 상단 띠에 놓고 하단은 Fire 외에 모두 비운다.
3. Split periphery controls: 좌하단에는 좌우·상하, 우하단에는 파워·시점·Fire를 두고 대포 주변을 넓게 비운다.

모든 시안은 다음 조건을 공유한다.

- 현재 warm paper-white, navy, blue-accent 시각 언어를 유지한다.
- `LV 5 · 골 0 / 3`, 대포 위치 selector, 좌우·상하·파워, Overview·Cannon·Follow·Retry·Pause·Help, Fire만 표시한다.
- 중앙 reticle, 물리 대포, 지형, goal marker, 짧은 partial aim arc를 가리지 않는다.
- full trajectory, landing prediction, minimap, course prose, progress card를 만들지 않는다.
- 아이콘은 실제 도형과 짧은 한국어 라벨을 조합하고 Unicode 장식 기호에 의존하지 않는다.

생성 결과는 다음 경로에 보존한다.

- `.agents/evidence/cannon-golf/hud-concepts-2026-08-16/hud-concept-01-right-edge.png`
- `.agents/evidence/cannon-golf/hud-concepts-2026-08-16/hud-concept-02-upper-ribbon.png`
- `.agents/evidence/cannon-golf/hud-concepts-2026-08-16/hud-concept-03-split-periphery.png`

## 프로젝트 구조 변화 평가

기준점은 이전 HUD 시안을 기록한 `d49e2e5`이며 현재 비교 대상은 `f0cba67`이다.

- 제품 권위 문서는 계속 `project-specs/cannon-golf/`에 있다.
- `2031a22`에서 `RESEARCH.md`와 camera/world readability 자료가 `.agents/research/cannon-golf/`로 이동했다. 제품 사양과 자문 자료의 권위가 분리된 점은 개선이다.
- `0f1247a`와 `f0cba67`은 `.agents/PLANS.md`와 문서 배치 지침을 정리했다. 계획, 연구, 증거의 저장 위치가 전보다 분명하다.
- `d49e2e5..f0cba67` 사이에 커밋된 런타임 scene/script/resource/test 구조 변화는 없다. 이번 비교에서 보이는 구조 변화는 문서 거버넌스가 중심이다.
- 현재 `.agents/evidence/`는 지침에 정의됐지만 아직 존재하지 않는다. 이번 시안부터 그 위치를 사용하면 새 증거의 위치가 제품 asset과 섞이지 않는다.
- 현재 worktree에는 이 작업과 무관한 UI·terrain·test·prepared artifact 변경이 있다. 새 문서와 시안만 별도로 커밋해야 한다.

## Limitations

- Nintendo 미국 planning 문서는 이 환경에서 직접 열 때 406을 반환했다. 공식 검색 결과의 설명을 Nintendo AU 공식 페이지와 교차 확인했으며, 세부 픽셀 배치는 근거로 사용하지 않았다.
- 외부 사례는 기능과 배치 원칙만 참고했다. 해당 게임의 시각 스타일이나 HUD 구성을 복제하지 않는다.
- 생성 이미지의 한국어 글자는 개념 표현용이다. 실제 구현 시 현재 Godot 테마, 폰트, focus 상태, 1280×720과 지원 해상도에서 다시 검증해야 한다.
