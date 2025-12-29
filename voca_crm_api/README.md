# VocaCRM API - Spring Boot REST API

VocaCRM 모바일 애플리케이션의 백엔드 API 서버입니다.

## 주요 기능

- **인증**: JWT + OAuth2 (Google, Kakao, Apple), Token Rotation
- **회원 관리**: Soft Delete, 등급 관리, 검색
- **메모/방문/예약**: 고객 이력 관리
- **사업장**: 다중 사업장, 역할 관리 (OWNER/ADMIN/MEMBER)
- **음성 명령**: Ollama AI + DeepL 번역 연동
- **알림**: FCM 푸시 알림
- **보안**: Rate Limiting, 감사 로그 (AOP)

## 기술 스택

- **Framework**: Spring Boot 3.x
- **Language**: Java 17
- **Database**: PostgreSQL + Flyway
- **Cache**: Redis (세션, Rate Limiting, AI 사용량)
- **AI**: Ollama + DeepL API

## 프로젝트 구조

```
src/main/java/com/vocacrm/api/
├── controller/    # REST 컨트롤러 (13개)
├── service/       # 비즈니스 로직 (19개)
├── model/         # JPA 엔티티 (18개)
├── repository/    # Spring Data JPA (17개)
├── filter/        # Security, Rate Limiting, JWT (3개)
├── aspect/        # 감사 로깅 AOP
└── config/        # 설정 (6개)
```

## 시작하기

### 환경 설정

`.env` 파일 생성:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=voca_crm
DB_USERNAME=postgres
DB_PASSWORD=your_password
JWT_SECRET=your_jwt_secret
REDIS_HOST=localhost
REDIS_PORT=6379
```

### 실행

```bash
# 빌드
./gradlew build

# 실행
./gradlew bootRun

# 테스트
./gradlew test
```

서버: `http://localhost:8080`

## Rate Limiting

| 엔드포인트 | 제한 |
|-----------|------|
| 인증 (로그인/회원가입) | 10회/분 |
| 일반 API | 300회/분 |
| 검색 | 100회/분 |
| 음성 AI | 5회/분 |

## 환경 요구사항

- Java 17+
- PostgreSQL 12+
- Redis 6+

---

상세 문서는 `/docs/API_PROJECT_STRUCTURE.md` 참조
