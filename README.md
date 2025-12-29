# VocaCRM

음성 기반 고객 관계 관리(CRM) 시스템입니다. Flutter 모바일 앱과 Spring Boot API 서버로 구성된 모노레포입니다.

## 프로젝트 구조

```
voca_crm/
├── voca_crm/          # Flutter 모바일 앱 (iOS/Android)
├── voca_crm_api/      # Spring Boot REST API 서버
```

## 주요 기능

| 기능 | 설명 |
|------|------|
| 음성 검색 | AI 기반 음성 명령 처리 (Ollama + DeepL) |
| 인증 | OAuth2 (Google, Kakao, Apple) + 생체 인증 |
| 회원 관리 | 등급 관리, Soft Delete, 검색 |
| 메모/방문/예약 | 고객별 이력 관리 |
| 사업장 | 다중 사업장, 역할 기반 접근 제어 |
| 알림 | FCM 푸시 알림 |
| 보안 | JWT Token Rotation, Rate Limiting, 감사 로그 |

## 기술 스택

### Frontend (voca_crm)
- Flutter 3.32.0+ / Dart 3.8.0+
- Clean Architecture
- Provider + GetIt

### Backend (voca_crm_api)
- Spring Boot 3.x / Java 17
- PostgreSQL + Flyway
- Redis (세션, Rate Limiting)
- Ollama + DeepL API

## 시작하기

### 1. API 서버 실행

```bash
cd voca_crm_api

# 환경 변수 설정
cp .env.example .env
# .env 파일 수정

# 실행
./gradlew bootRun
```

### 2. Flutter 앱 실행

```bash
cd voca_crm

# 의존성 설치
flutter pub get

# 실행
flutter run
```

## 환경 요구사항

- **API**: Java 17+, PostgreSQL 12+, Redis 6+
- **App**: Flutter 3.32.0+, Dart 3.8.0+
- **AI**: Ollama (선택), DeepL API Key (선택)

## 문서

- [Flutter 프로젝트 구조](docs/FLUTTER_PROJECT_STRUCTURE.md)
- [API 프로젝트 구조](docs/API_PROJECT_STRUCTURE.md)

## 라이선스

Private
