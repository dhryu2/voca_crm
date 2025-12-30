# VOCA CRM Web

VOCA CRM 웹 프론트엔드 프로젝트

## 기술 스택

- **Framework**: React 19 + TypeScript
- **Build Tool**: Vite (Rolldown)
- **Styling**: Tailwind CSS 4
- **State Management**: Zustand
- **Data Fetching**: TanStack React Query
- **Routing**: React Router DOM 7
- **Icons**: Lucide React

## 프로젝트 구조

```
src/
├── assets/       # 정적 리소스
├── components/   # 재사용 가능한 컴포넌트
├── lib/          # 유틸리티 함수
├── pages/        # 페이지 컴포넌트
├── stores/       # Zustand 스토어
├── types/        # TypeScript 타입 정의
├── App.tsx       # 메인 앱 컴포넌트
├── main.tsx      # 엔트리 포인트
└── index.css     # 글로벌 스타일
```

## 시작하기

```bash
# 의존성 설치
npm install

# 개발 서버 실행
npm run dev

# 프로덕션 빌드
npm run build

# 빌드 미리보기
npm run preview

# 린트 검사
npm run lint
```
