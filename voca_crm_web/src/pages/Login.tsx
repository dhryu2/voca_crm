import { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import { Button } from '@/components/ui';
import { Mic, ArrowLeft } from 'lucide-react';
import { OAuthError, type OAuthProvider } from '@/lib/oauth';

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { loginWithProvider, isLoading } = useAuthStore();
  const [error, setError] = useState<string | null>(null);
  const [loadingProvider, setLoadingProvider] = useState<OAuthProvider | null>(null);

  const from = (location.state as { from?: { pathname: string } })?.from?.pathname || '/dashboard';

  const handleSocialLogin = async (provider: OAuthProvider) => {
    setError(null);
    setLoadingProvider(provider);

    try {
      await loginWithProvider(provider);
      navigate(from, { replace: true });
    } catch (err) {
      if (err instanceof Error) {
        if (err.message === 'SIGNUP_REQUIRED') {
          // 회원가입이 필요한 경우 - 회원가입 페이지로 이동
          navigate('/signup', { state: { provider, from } });
          return;
        }

        // OAuthError인 경우 코드별 처리
        if (err instanceof OAuthError) {
          if (err.code === 'CANCELLED') {
            // 취소는 에러 메시지 표시하지 않음
            return;
          }
        }

        setError(err.message);
      } else {
        setError('로그인에 실패했습니다. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      setLoadingProvider(null);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Left: Branding */}
      <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-primary-700 to-primary-900 p-12 flex-col justify-between">
        <div>
          <Link to="/" className="inline-flex items-center gap-2 text-white/80 hover:text-white transition-colors">
            <ArrowLeft className="w-4 h-4" />
            <span className="text-sm">홈으로</span>
          </Link>
        </div>

        <div>
          <div className="w-16 h-16 bg-white/10 backdrop-blur rounded-2xl flex items-center justify-center mb-8">
            <Mic className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-4xl font-bold text-white mb-4">
            음성으로 더 쉬운
            <br />
            고객 관리
          </h1>
          <p className="text-lg text-white/80 max-w-md">
            VocaCRM으로 고객을 관리하고, 예약을 정리하고, 비즈니스를 성장시키세요.
          </p>
        </div>

        <div className="text-sm text-white/60">
          © 2024 VocaCRM. All rights reserved.
        </div>
      </div>

      {/* Right: Login Form */}
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="w-full max-w-md">
          {/* Mobile Logo */}
          <div className="lg:hidden mb-8 text-center">
            <Link to="/" className="inline-flex items-center gap-2">
              <div className="w-10 h-10 bg-primary-800 rounded-xl flex items-center justify-center">
                <span className="text-white font-bold">V</span>
              </div>
              <span className="font-bold text-2xl text-gray-900">VocaCRM</span>
            </Link>
          </div>

          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold text-gray-900">시작하기</h2>
            <p className="text-gray-600 mt-2">소셜 계정으로 간편하게 로그인하세요</p>
          </div>

          {error && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
              {error}
            </div>
          )}

          <div className="space-y-3">
            {/* Google Login */}
            <Button
              variant="outline"
              className="w-full h-12 justify-center gap-3"
              onClick={() => handleSocialLogin('google')}
              disabled={isLoading || loadingProvider !== null}
              isLoading={loadingProvider === 'google'}
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="currentColor"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="currentColor"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="currentColor"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              {loadingProvider === 'google' ? '로그인 중...' : 'Google로 계속하기'}
            </Button>

            {/* Kakao Login */}
            <Button
              className="w-full h-12 justify-center gap-3 bg-[#FEE500] text-[#191919] hover:bg-[#FDD800]"
              onClick={() => handleSocialLogin('kakao')}
              disabled={isLoading || loadingProvider !== null}
              isLoading={loadingProvider === 'kakao'}
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M12 3c5.8 0 10.5 3.664 10.5 8.185 0 4.52-4.7 8.184-10.5 8.184a13.5 13.5 0 0 1-1.727-.11l-4.408 2.883c-.501.265-.678.236-.472-.413l.892-3.678c-2.88-1.46-4.785-3.99-4.785-6.866C1.5 6.665 6.2 3 12 3z"
                />
              </svg>
              {loadingProvider === 'kakao' ? '로그인 중...' : 'Kakao로 계속하기'}
            </Button>

            {/* Apple Login */}
            <Button
              className="w-full h-12 justify-center gap-3 bg-black text-white hover:bg-gray-900"
              onClick={() => handleSocialLogin('apple')}
              disabled={isLoading || loadingProvider !== null}
              isLoading={loadingProvider === 'apple'}
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"
                />
              </svg>
              {loadingProvider === 'apple' ? '로그인 중...' : 'Apple로 계속하기'}
            </Button>
          </div>

          <div className="relative my-8">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-200"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-gray-50 text-gray-500">또는</span>
            </div>
          </div>

          <Link to="/signup">
            <div className="text-center p-4 bg-primary-50 rounded-xl hover:bg-primary-100 transition-colors cursor-pointer">
              <span className="text-gray-600">처음이신가요?</span>{' '}
              <span className="text-primary-700 font-semibold">회원가입</span>
            </div>
          </Link>

          <p className="mt-8 text-center text-xs text-gray-500">
            로그인함으로써{' '}
            <a href="#" className="text-primary-600 hover:underline">
              서비스 이용약관
            </a>
            과{' '}
            <a href="#" className="text-primary-600 hover:underline">
              개인정보처리방침
            </a>
            에 동의합니다.
          </p>
        </div>
      </div>
    </div>
  );
}
