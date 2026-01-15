import { Navigate, useLocation, Link } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui';

interface AuthGuardProps {
  children: React.ReactNode;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const { isAuthenticated, user, businessPlaces, loadUserFromToken, logout, fetchBusinessPlaces } = useAuthStore();
  const [isInitialized, setIsInitialized] = useState(false);
  const [businessPlacesLoaded, setBusinessPlacesLoaded] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const init = async () => {
      // persist에서 이미 복원된 상태 확인
      const stored = useAuthStore.getState();
      if (stored.isAuthenticated && stored.user) {
        // 이미 인증 상태면 토큰 유효성만 확인
        if (apiClient.hasValidToken()) {
          setIsInitialized(true);
          // 사업장 목록 로드
          await fetchBusinessPlaces();
          setBusinessPlacesLoaded(true);
          return;
        }
      }
      // 토큰 검증 필요
      await loadUserFromToken();
      setIsInitialized(true);
      setBusinessPlacesLoaded(true);
    };
    init();
  }, [loadUserFromToken, fetchBusinessPlaces]);

  if (!isInitialized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="flex flex-col items-center gap-4">
          {/* VocaCRM 로고 */}
          <div className="flex items-center gap-2">
            <img
              src="/app_icon_white.png"
              alt="VocaCRM"
              className="w-12 h-12 rounded-xl shadow-lg"
            />
          </div>
          {/* 로딩 스피너 */}
          <div className="w-8 h-8 border-3 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 text-sm">인증 확인 중...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated || !user) {
    // 현재 경로 저장하여 로그인 후 리다이렉트
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // 인증됐지만 사업장이 없는 경우 안내 (설정 페이지는 접근 허용)
  if (businessPlacesLoaded && businessPlaces.length === 0 && location.pathname !== '/settings') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center max-w-md p-8">
          {/* VocaCRM 로고 */}
          <div className="flex justify-center mb-6">
            <img
              src="/app_icon_white.png"
              alt="VocaCRM"
              className="w-16 h-16 rounded-xl shadow-lg"
            />
          </div>
          <h2 className="text-xl font-bold text-gray-900 mb-4">
            사업장이 없습니다
          </h2>
          <p className="text-gray-600 mb-6">
            서비스를 이용하려면 사업장을 생성하거나<br />
            다른 사업장으로부터 초대를 받아야 합니다.
          </p>
          <div className="space-y-3">
            <Link to="/settings">
              <Button className="w-full">사업장 관리로 이동</Button>
            </Link>
            <Button variant="outline" onClick={() => logout()} className="w-full">
              로그아웃
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
