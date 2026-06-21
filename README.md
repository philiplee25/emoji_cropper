# emoji_cropper

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# emoji_cropper


## 📝 Git Commit 규칙

효율적인 협업과 히스토리 관리를 위해 다음의 커밋 메시지 규칙을 준수합니다.

### 1. 커밋 타입 (Type)
메시지의 가장 앞에 태그를 명시합니다.

| 태그 | 설명 |
| :--- | :--- |
| `FEAT` | 새로운 기능 추가 |
| `FIX` | 버그 수정 |
| `DOCS` | 문서 수정 및 추가 |
| `STYLE` | 코드 스타일 관련 변경 (포매팅, 세미콜론 누락 등) |
| `REFACTOR` | 코드 리팩토링 (기능 변경 없음) |
| `TEST` | 테스트 코드, 리팩토링 테스트 코드 추가 |
| `CHORE` | 빌드 task 수정, 패키지 매니저 수정 (.gitignore 등) |

### 2. 작성 규칙 (Format)

1. **제목과 본문 분리**: 제목과 본문 사이에는 반드시 **빈 행(Blank Line)**을 한 줄 둡니다.
2. **제목 길이 제한**: 제목 행은 **50자** 이내로 작성합니다.
3. **대문자 시작**: 제목의 첫 글자는 대문자로 시작합니다.
    - `read the docs` ❌
    - `Read the docs` 🟢
4. **마침표 금지**: 제목 행 끝에 마침표(.)를 찍지 않습니다.
    - `Read the docs.` ❌
    - `Read the docs` 🟢
5. **명령형 작성**: 제목은 과거형이 아닌 **명령형**으로 작성합니다.
    - `Docs are ready` ❌
    - `Read the docs` 🟢

### 3. 본문 작성 가이드 (Body)
- **내용**: 무엇을 추가/변경했는지, 그리고 **'왜(Why)'** 변경했는지를 적습니다.
- **지양**: '어떻게(How)' 코드를 짰는지는 지양합니다. (코드로 확인 가능)

### 4. 커밋 메시지 예시
```text
FEAT: Add fortune cookie selection logic

메인 화면에서 쿠키를 선택했을 때 ID 값을 기반으로
상세 화면으로 이동하는 로직 추가.

기존의 정적 이미지 표시에서 인터랙티브한 요소로 변경하기 위함.