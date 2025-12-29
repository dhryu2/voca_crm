# VocaCRM - 음성 기반 CRM 모바일 애플리케이션

VocaCRM은 음성 인터랙션과 AI 명령 처리 기능을 갖춘 Flutter 기반 모바일 CRM 애플리케이션입니다.

## 주요 기능

- **음성 검색**: 한국어 TTS/STT 지원, AI 기반 음성 명령 처리
- **생체 인증**: 지문/Face ID 로그인
- **회원 관리**: 등급 관리 (VIP/GOLD/SILVER/BRONZE/GENERAL), Soft Delete
- **메모/방문/예약**: 고객별 이력 관리
- **사업장 관리**: 다중 사업장, 접근 코드 기반 등록 요청
- **알림**: FCM 푸시 알림

## 기술 스택

- **Framework**: Flutter 3.32.0+
- **Architecture**: Clean Architecture (Core/Data/Domain/Presentation)
- **State Management**: Provider + GetIt
- **Authentication**: JWT + OAuth2 (Google, Kakao, Apple)

## 프로젝트 구조

```
lib/
├── core/               # DI, Theme, Utils
├── data/               # Datasource (16개), Model, Repository 구현
├── domain/             # Entity (20개), Repository 인터페이스
└── presentation/       # Screens (23개), ViewModels, Widgets (24개)
```

## 시작하기

```bash
# 의존성 설치
flutter pub get

# 실행
flutter run

# 테스트
flutter test

# 코드 분석
flutter analyze
```

## 환경 요구사항

- Flutter SDK >=3.32.0
- Dart SDK >=3.8.0
- VocaCRM API 서버 실행 필요

## 플랫폼

- **Android**: 최소 SDK 21, 타겟 SDK 34
- **iOS**: 최소 iOS 12.0

---

상세 문서는 `/docs/FLUTTER_PROJECT_STRUCTURE.md` 참조
