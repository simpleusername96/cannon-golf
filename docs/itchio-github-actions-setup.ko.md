# Cannon Golf itch.io Web 자동 배포

이 저장소의 `main` 브랜치에 게임 변경을 push하면 GitHub Actions가 Godot
4.7.1 Web 빌드를 검증하고 itch.io에 자동 배포한다.

## 고정 대상

- GitHub: `https://github.com/simpleusername96/cannon-golf`
- itch.io: `https://itchioprofile1351321.itch.io/cannon-golf`
- Butler 채널: `itchioprofile1351321/cannon-golf:html5`
- GitHub Actions Secret: `BUTLER_API_KEY`

API 키 값은 비밀번호와 같다. 채팅, 문서, 코드, 커밋, 로그에 기록하지
않는다. GitHub에는 저장된 값이 다시 표시되지 않는 것이 정상이다.

## 자동 흐름

```text
main에 게임 변경 push
→ itch API로 정확한 프로젝트 URL과 키 소유자 확인
→ Godot import·startup 검증과 Cannon Golf 테스트
→ 단일 스레드 Web export
→ itch 파일·용량·경로·참조 검사와 Butler 검사
→ html5 채널에 alpha.<실행 번호>+<커밋 7자리> 업로드
```

문서나 에이전트 기록만 바뀐 push는 자동 배포하지 않는다. 짧은 시간에
여러 push가 발생하면 이전 실행을 취소하고 최신 실행만 계속한다. 검증이
실패하면 업로드 단계는 실행되지 않는다.

Actions 화면의 `Run workflow`로 수동 실행할 수도 있다. `publish=false`는
검증과 빌드만 수행하고, `publish=true`는 검증된 빌드를 itch.io에 올린다.

## itch.io 최초 채널 설정

Butler가 `html5` 채널을 처음 만든 뒤 itch.io의 `Edit game`에서 해당
업로드를 `This file will be played in the browser`로 지정한다. 실행 방식은
`Click to launch in fullscreen`으로 두고 `Fullscreen button`을 켠다. 이
설정은 업로드 분류만 바꾸며 현재 `Public`, `In development`, `No payments`
상태는 바꾸지 않는다.

## 실패 시 확인 순서

1. Actions에서 첫 번째 실패 step과 로그를 확인한다.
2. `BUTLER_API_KEY` 누락이면 저장소의 Actions secret을 등록하거나 교체한다.
3. 프로젝트 URL/소유자 검사가 실패하면 itch 페이지나 키를 임의로 바꾸지
   말고 계정과 대상 URL을 확인한다.
4. export 또는 테스트가 실패하면 같은 커밋을 재실행하지 말고 원인을 고친
   새 커밋을 push한다.
5. 업로드는 성공했지만 실행되지 않으면 itch 업로드의 browser-playable
   체크와 embed 설정을 먼저 확인한다.

Godot, Butler, GitHub Actions 버전과 다운로드 체크섬은 workflow에 고정되어
있다. 실패를 통과시키기 위해 체크섬, 테스트, 용량 제한을 제거하지 않는다.
