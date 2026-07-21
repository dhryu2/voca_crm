# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important Rules

- `.claude/`, `.planning/`은 로컬 작업 도구 설정/메모라 git에 추적·커밋하지 않는다(`.gitignore` 처리됨).
- 코드 수정 전 변경 계획(대상 파일·변경 내용)을 먼저 제시하고, 명시적 지시 없이 파일을 수정하지 않는다. 논의 단계에서는 코드 탐색도 최소화하고 대화에 집중한다.

## Project Overview

VocaCRM is a bilingual (Korean/English) CRM application centered on voice-based customer search with biometric authentication. It spans a Flutter mobile app, a Spring Boot backend API, and a React admin web.

## Project Structure

This is a monorepo containing three projects:

- **voca_crm/** — Flutter mobile application (iOS/Android)
- **voca_crm_api/** — Spring Boot backend API (Java 17)
- **voca_crm_web/** — React + Vite + TypeScript admin web

## Flutter Application (voca_crm/)

### Development Commands

```bash
cd voca_crm
flutter pub get            # Install dependencies
flutter run                # Run (dev). Use -d android / -d ios for a platform
flutter test               # Run tests
flutter analyze            # Static analysis
flutter build apk          # Android release
flutter build ios          # iOS release
```

### Architecture

Clean architecture, with Provider/ChangeNotifier for state and `get_it` for DI:

- `lib/core/` — cross-cutting infra: network (`api_client.dart`), auth/token, error handling (Result/AppException), session, DI (`injection_container.dart`), utils (incl. `date_parser.dart`), theme
- `lib/data/` — `datasource/*_service.dart` (HTTP services), `model/` (JSON models), `repository/` (repository implementations)
- `lib/domain/` — `entity/`, `repository/` (interfaces), `usecase/`
- `lib/presentation/` — `screens/`, `viewmodels/` (ChangeNotifier), `widgets/`

API base URL is configured in `lib/core/constants/api_constants.dart`. Models are hand-written (no codegen); responses are parsed manually via `fromJson`.

### UI Patterns

Responsive sizing via MediaQuery (`screenWidth * factor`, `screenHeight * factor`), with sizing variables computed at the top of `build`. Theme colors are centralized in `lib/core/theme/theme_color.dart` (primary purple `#1c06b1`). Korean font: NotoSansKR.

## Spring Boot Backend (voca_crm_api/)

### Development Commands

```bash
cd voca_crm_api
./gradlew build            # Build + assemble (currently no backend tests)
./gradlew bootRun          # Run server on http://localhost:8080
./gradlew compileJava      # Compile main sources only
./gradlew clean
```

### Architecture

- Spring Boot 4.0.0 / Java 17 / PostgreSQL / JPA-Hibernate / Lombok
- Layered: `controller/` → `service/` → `repository/` → `model/` (JPA entities). DTOs in `dto/`, config in `config/`, request filters in `filter/` (JWT auth, rate limiting, security headers)
- Domains: Member, Memo, BusinessPlace, Reservation, Visit, Auth/User, Notice, Notification, AuditLog, ErrorLog, Statistics, VoiceCommand, Admin
- Auth: JWT (Bearer) via filters; `userId` / `businessPlaceId` are resolved from token claims and exposed as request attributes
- JSON: a custom `ObjectMapper` bean in `WebConfig` handles serialization. **Note:** because this bean exists, `spring.jackson.date-format` in `application.yaml` is ignored — `LocalDateTime` serializes with `T` (no zone) and `LocalDate` serializes date-only (`yyyy-MM-dd`)
- DB: PostgreSQL; host/port/credentials via env vars, config in `src/main/resources/application.yaml`
- CORS: `/api/**`, configured in `WebConfig`

The full endpoint/field contract lives in the controllers — treat the controller + DTO source as the source of truth rather than this file. The backend currently has no test suite.

## React Web (voca_crm_web/)

```bash
cd voca_crm_web
npm run dev                # Vite dev server
npm run build              # tsc -b && vite build
```

Hand-written API client in `src/lib/api.ts` / `apiClient.ts` (no codegen); global stores in `src/stores/`; pages in `src/pages/`.

## Language & Localization

- User-facing UI text and error messages: Korean
- Code identifiers: English
- Commit messages and developer-facing docs: Korean (technical terms may remain English, e.g. JWT, DTO, OAuth)

---

## Coding Principles

Behavioral guidelines to reduce common LLM coding mistakes. Tradeoff: these guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Common Pitfalls (공통 함정)

위 Coding Principles는 일반 행동 원칙이고, 아래는 어느 프로젝트에나 적용되는 필수 안티패턴 회피 규칙이다.

### 1. 추측 금지 — 코드 확인 후 호출/접근/설명

메서드 시그니처, 클래스/DTO 필드명, API 계약, 호출 흐름 등 모든 것을 추측하지 않고 실제 정의를 grep/read로 확인한다. 특히 **API ↔ Flutter/Web 계약**(경로·파라미터·요청 바디·응답 키·타입)은 양쪽 코드를 직접 대조해 확인한다.

### 2. 변경 영향 전수 검색

함수/엔드포인트/필드를 리네임·삭제하거나 시그니처(파라미터·반환값)를 바꿀 때 모든 호출 위치를 검색해 함께 수정한다. API를 바꾸면 백엔드뿐 아니라 Flutter `data/datasource/*_service.dart`와 Web `src/lib`까지 전수 확인한다.

### 3. 설정값 하드코딩 금지

모든 설정값/상수는 중앙 정의를 참조한다 (Flutter: `ApiConstants`/`ThemeColor`, Spring: `application.yaml`/`@Value`/환경변수). fallback으로 매직 넘버를 하드코딩하지 않는다.

### 4. Fail-fast — 방어 코드가 에러를 숨기면 안 됨

`try-catch`로 에러를 삼키고 기본값/빈 값을 반환해 실패를 은폐하지 않는다. *불가능한* 시나리오엔 핸들링을 추가하지 않고, *실제* 에러는 숨기지 않고 throw/raise 한다.

### 5. DB 쿼리는 실제 스키마 기준

SQL/JPA 작성·수정 시 실제 엔티티 정의와 마이그레이션에서 컬럼명·타입·제약을 확인한다. 추측 금지.

### 6. 동시성 — 멱등성 보장

여러 경로(콜백·스케줄러·재시도)에서 호출될 수 있는 처리는 중복 실행 방지 장치를 둔다(처리 완료 추적 후 early return).

### 7. 민감정보(시크릿) 절대 노출 금지 — CRITICAL

비밀번호·API 키·토큰·DB 자격증명 등 모든 민감정보는 환경변수/시크릿 저장소에만 둔다. 소스 코드·문서·커밋 메시지·주석·로그·서브에이전트 지시문에 실제 값을 절대 쓰지 않는다(예시는 `<your-secret>` 같은 placeholder 사용). 한 번 커밋되면 git 이력에 영구히 남고, push되면 회복 불가능하게 노출된다.

### 8. 외부 API 수동 호출 — 쿼터/비용 주의 — CRITICAL

운영과 공유되는 외부 API(예: AI 서버, 번역, OAuth, 푸시)를 테스트·검증·backfill 목적으로 남발하지 않는다. 최소 표본으로만 실측하고, 이미 적재된 값은 재호출 대신 DB/캐시에서 읽는다. rate-limit/쿼터 초과 에러가 한 번 뜨면 즉시 멈추고 회복을 기다린다(재시도 남발 금지).

## Verification

중요한 변경 후에는 `/bx-review` 등 bx 검증 스킬로 의도-구현 정합을 점검한다.
