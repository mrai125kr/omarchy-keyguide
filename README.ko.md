# Omarchy Keyguide

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

> 공개 저장소: <https://github.com/mrai125kr/omarchy-keyguide>

Omarchy Keyguide는 Omarchy용 단축키 안내 HUD와 안전 범위가 제한된 단축키
편집기입니다. `Super`와 `Ctrl`·`Shift`·`Alt`의 8개 조합을 누르면 현재 활성
단축키만 입력을 가로채지 않는 HUD로 보여 줍니다. 키 입력을 잡거나 소비하거나
재생성하지 않으며, Omarchy의 사용자 `bindings.lua`를 직접 수정하지 않습니다.

## 주요 기능

- HUD 위치, 크기, 투명도, 테마 연동, 표시 그룹과 개별 행 설정
- 빈 키는 중앙 팝업에서 등록하고, 기존 키는 해당 행 옆 팝업에서 변경하거나 제거
- 일반 액션·설치된 프로그램·명령을 한 검색창에서 찾아 등록
- 영어(기본), 한국어, 일본어, 중국어 간체, 스페인어로 설정창과 HUD 표시
- 메뉴에 보이지 않는 Hyprland 런타임 바인딩까지 포함한 중복 검사
- 현재 XKB 키보드 배열을 이용한 물리 `code:` 키 충돌 검사
- Keyguide가 이동한 키는 원래 위치로, 새로 만든 키는 제거하는 전체 초기화
- 충돌·동시 변경·재로드 불일치 시 후보를 남기지 않는 정확한 롤백

전체 설정 화면에는 수정 키 그룹별 현재 바인딩이 표시됩니다. 키 선택기에서 빈
키를 고르면 중앙에 등록 팝업이 열리고, 기존 행의 `Change`를 누르면 같은 편집
팝업이 해당 행 가까이에 열립니다. 각 키는 `Free` 또는 `Assigned — <제목>`으로
표시됩니다. 할당된 키에는 편집 가능한 제목, 동작 종류와 인수, `Current key`,
`Omarchy default` 또는 `Managed by Keyguide` 상태가 나타납니다. 각 행의
`Shown`/`Hidden`, `Change`, `Remove`(`제거`)는 서로 독립적으로 작동합니다.
`제거`하면 해당 조합은 빈 키가 되며, 복원 가능한 원래 바인딩은 `전체 초기화`로
되돌릴 수 있습니다.

빈 키에는 한 검색창에서 안전하게 복원할 수 있는 Omarchy 액션, 설치된 그래픽
프로그램 또는 실행 명령을 선택할 수 있습니다. 일반 액션은 선택한 언어와 영어
이름 모두로 검색됩니다. 프로그램 행 앞에는 데스크톱 아이콘이 표시되고 명령은
`(CMD)`로 구분됩니다. 선택창이 열려 있는 동안 설치·제거된 프로그램과 명령이
자동으로 갱신되며, 선택 인수 입력란은 명령에만 표시됩니다. 기존 액션을 등록하면
복제하지 않고 현재 키에서 새 키로 이동합니다. 이미 할당된 키를 바꿀 때는 제거될
액션 이름을 보여 주고 두 번째 확인을 요구합니다.

변경할 수 없는 바인딩도 표시 여부는 따로 조절할 수 있고, 일반적인 읽기 전용
문구 대신 정확한 사유를 표시합니다. 가능한 사유는 다음과 같습니다.

- `Mouse binding`, `Duplicate chord`, `Unsupported key`
- `Action cannot be reconstructed`
- `Ambiguous action metadata`, `Malformed action record`
- `Unsupported action kind`

이미 사용 중인 키는 오류를 표시하고 등록하지 않습니다. 저장 직전과 Hyprland
재로드 후에도 같은 키를 다시 확인하므로, 작업 중 외부 설정이 바뀌어도 중복
상태를 성공으로 처리하지 않습니다. 안전하게 해석할 수 없는 물리 키가 있으면
편집을 차단합니다.

`Reset all`(`전체 초기화`)은 Keyguide의 최초 기본 설정으로 되돌립니다.
Keyguide가 이동하거나 교체한 기존 단축키와 제목을 복원하고 Keyguide가 추가한
단축키를 제거하며 HUD 표시 설정을 초기값으로 바꿉니다. 다른 Omarchy·Hyprland
설정이나 다른 플러그인 설정은 초기화하지 않습니다.

## 호환성과 설치 준비

대상 환경은 Omarchy `4.0.0-1`, Hyprland `0.56.2` 이상입니다. Python 3,
`xkbcli`, 읽을 수 있는 키보드 이벤트 장치가 필요하며 소스 또는 Git 플러그인
설치에는 C 컴파일러(Arch Linux의 `base-devel`)가 필요합니다.

다음 명령으로 GitHub에서 직접 설치할 수 있습니다.

```sh
omarchy plugin add https://github.com/mrai125kr/omarchy-keyguide.git --enable
```

Git 플러그인 업데이트는 `omarchy plugin update mrai.keyguide --yes`, 제거는
`omarchy plugin remove mrai.keyguide`를 사용합니다. 소스 트리에서 검증하려면
`make test`, 설치하려면 `make install`, 제거는 `make uninstall`을 사용합니다.

## 안전 원칙

- `/usr/share/omarchy/`와 `~/.config/hypr/bindings.lua`를 수정하지 않습니다.
- 생성 단축키는 사용자 상태 디렉터리의 Keyguide 전용 Lua 모듈 하나에만
  원자적으로 저장합니다.
- 일반 제거는 사용자 표시 설정과 별도 관리 단축키를 보존합니다.
- 설치 제거는 인증된 소유 파일 목록만 다루며 사용자 설정을 재귀 삭제하지
  않습니다.

MIT 라이선스입니다. 자세한 내용은 [LICENSE](LICENSE)와 [NOTICE](NOTICE)를
참조하세요.
