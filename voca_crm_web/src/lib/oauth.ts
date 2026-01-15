export type OAuthProvider = 'google' | 'kakao' | 'apple';

export type OAuthErrorCode = 'CANCELLED' | 'SDK_LOAD_FAILED' | 'AUTH_FAILED' | 'CONFIG_MISSING';

export class OAuthError extends Error {
  code: OAuthErrorCode;
  provider: OAuthProvider;

  constructor(
    message: string,
    code: OAuthErrorCode,
    provider: OAuthProvider
  ) {
    super(message);
    this.name = 'OAuthError';
    this.code = code;
    this.provider = provider;
  }
}

// Provider 이름 매핑 (Flutter와 동일한 한글 메시지용)
const providerNames: Record<OAuthProvider, string> = {
  google: 'Google',
  kakao: '카카오',
  apple: 'Apple',
};

// 에러 메시지 생성 함수 (Flutter와 동일한 포맷)
function createOAuthError(
  code: OAuthErrorCode,
  provider: OAuthProvider
): OAuthError {
  const name = providerNames[provider];
  let message: string;

  switch (code) {
    case 'CANCELLED':
      message = `사용자가 ${name} 로그인을 취소했습니다`;
      break;
    case 'SDK_LOAD_FAILED':
      message = `${name} 로그인 스크립트를 불러올 수 없습니다`;
      break;
    case 'AUTH_FAILED':
      message = `${name} 로그인에 실패했습니다. 다시 시도해주세요.`;
      break;
    case 'CONFIG_MISSING':
      message = `${name} Client ID가 설정되지 않았습니다. .env 파일을 확인해주세요.`;
      break;
  }

  return new OAuthError(message, code, provider);
}

export interface OAuthResult {
  provider: string; // API format: google.com, kakao.com, apple.com
  token: string;
}

// OAuth 타임아웃 (ms) - 기본 30초
const OAUTH_TIMEOUT = 30000;

// 타임아웃 에러 코드 추가
export type OAuthErrorCodeExtended = OAuthErrorCode | 'TIMEOUT';

// Promise.race를 사용한 타임아웃 래퍼
function withTimeout<T>(
  promise: Promise<T>,
  provider: OAuthProvider,
  timeoutMs: number = OAUTH_TIMEOUT
): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      setTimeout(() => {
        const name = providerNames[provider];
        reject(new OAuthError(
          `${name} 로그인 시간이 초과되었습니다. 다시 시도해주세요.`,
          'AUTH_FAILED', // TIMEOUT을 AUTH_FAILED로 처리
          provider
        ));
      }, timeoutMs);
    }),
  ]);
}

// Google OAuth using GSI (Google Sign-In)
export async function googleLogin(): Promise<OAuthResult> {
  return new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

    if (!clientId || clientId === 'your-google-client-id.apps.googleusercontent.com') {
      reject(createOAuthError('CONFIG_MISSING', 'google'));
      return;
    }

    // Load Google GSI script if not loaded
    if (!window.google?.accounts) {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.defer = true;
      script.onload = () => initGoogleLogin(clientId, resolve, reject);
      script.onerror = () => reject(createOAuthError('SDK_LOAD_FAILED', 'google'));
      document.head.appendChild(script);
    } else {
      initGoogleLogin(clientId, resolve, reject);
    }
  });
}

function initGoogleLogin(
  clientId: string,
  resolve: (result: OAuthResult) => void,
  reject: (error: OAuthError) => void
) {
  window.google!.accounts.id.initialize({
    client_id: clientId,
    callback: (response: { credential: string }) => {
      if (response.credential) {
        resolve({
          provider: 'google.com',
          token: response.credential,
        });
      } else {
        reject(createOAuthError('AUTH_FAILED', 'google'));
      }
    },
  });

  // Prompt for account selection
  window.google!.accounts.id.prompt((notification: { isNotDisplayed: () => boolean; isSkippedMoment: () => boolean }) => {
    if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
      // Fallback: use popup via tokenClient
      const tokenClient = window.google!.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: 'openid email profile',
        callback: (tokenResponse: { access_token?: string; error?: string }) => {
          if (tokenResponse.access_token) {
            resolve({
              provider: 'google.com',
              token: tokenResponse.access_token,
            });
          } else if (tokenResponse.error === 'popup_closed_by_user' || tokenResponse.error === 'access_denied') {
            // 사용자가 팝업을 닫거나 취소한 경우
            reject(createOAuthError('CANCELLED', 'google'));
          } else {
            reject(createOAuthError('AUTH_FAILED', 'google'));
          }
        },
      });
      tokenClient.requestAccessToken();
    }
  });
}

// Kakao OAuth
export async function kakaoLogin(): Promise<OAuthResult> {
  return new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_KAKAO_CLIENT_ID;

    if (!clientId || clientId === 'your-kakao-javascript-key') {
      reject(createOAuthError('CONFIG_MISSING', 'kakao'));
      return;
    }

    // Load Kakao SDK if not loaded
    if (!window.Kakao) {
      const script = document.createElement('script');
      script.src = 'https://t1.kakaocdn.net/kakao_js_sdk/2.6.0/kakao.min.js';
      script.integrity = 'sha384-6MFdIr0zOira1CHQkedUqJVql0YtcZA1P0nbPrQYJXVJZUkTk/oX4U9GhLONxilN';
      script.crossOrigin = 'anonymous';
      script.async = true;
      script.onload = () => initKakaoLogin(clientId, resolve, reject);
      script.onerror = () => reject(createOAuthError('SDK_LOAD_FAILED', 'kakao'));
      document.head.appendChild(script);
    } else {
      initKakaoLogin(clientId, resolve, reject);
    }
  });
}

function initKakaoLogin(
  clientId: string,
  resolve: (result: OAuthResult) => void,
  reject: (error: OAuthError) => void
) {
  if (!window.Kakao!.isInitialized()) {
    window.Kakao!.init(clientId);
  }

  window.Kakao!.Auth.login({
    success: (authObj: { access_token: string }) => {
      resolve({
        provider: 'kakao.com',
        token: authObj.access_token,
      });
    },
    fail: (err: { error?: string; error_description?: string }) => {
      // Kakao SDK에서 취소 시 error가 'access_denied' 또는 설명에 '취소' 포함
      if (err.error === 'access_denied' || err.error_description?.includes('취소') || err.error_description?.includes('cancel')) {
        reject(createOAuthError('CANCELLED', 'kakao'));
      } else {
        reject(createOAuthError('AUTH_FAILED', 'kakao'));
      }
    },
  });
}

// Apple OAuth (Sign in with Apple JS)
export async function appleLogin(): Promise<OAuthResult> {
  return new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_APPLE_CLIENT_ID;
    const redirectUri = import.meta.env.VITE_APPLE_REDIRECT_URI;

    if (!clientId || clientId === 'your-apple-service-id') {
      reject(createOAuthError('CONFIG_MISSING', 'apple'));
      return;
    }

    // Load Apple Sign-In JS if not loaded
    if (!window.AppleID) {
      const script = document.createElement('script');
      script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
      script.async = true;
      script.onload = () => initAppleLogin(clientId, redirectUri, resolve, reject);
      script.onerror = () => reject(createOAuthError('SDK_LOAD_FAILED', 'apple'));
      document.head.appendChild(script);
    } else {
      initAppleLogin(clientId, redirectUri, resolve, reject);
    }
  });
}

async function initAppleLogin(
  clientId: string,
  redirectUri: string,
  resolve: (result: OAuthResult) => void,
  reject: (error: OAuthError) => void
) {
  try {
    window.AppleID!.auth.init({
      clientId,
      scope: 'name email',
      redirectURI: redirectUri,
      usePopup: true,
    });

    const response = await window.AppleID!.auth.signIn();

    if (response.authorization?.id_token) {
      resolve({
        provider: 'apple.com',
        token: response.authorization.id_token,
      });
    } else {
      reject(createOAuthError('AUTH_FAILED', 'apple'));
    }
  } catch (error) {
    // Apple Sign-In 팝업 취소 시 에러 처리
    // Apple SDK는 팝업 취소 시 'popup_closed_by_user' 또는 에러 객체 반환
    if (error && typeof error === 'object' && 'error' in error) {
      const appleError = error as { error: string };
      if (appleError.error === 'popup_closed_by_user' || appleError.error === 'user_cancelled_authorize') {
        reject(createOAuthError('CANCELLED', 'apple'));
        return;
      }
    }
    reject(createOAuthError('AUTH_FAILED', 'apple'));
  }
}

// Unified OAuth login function with timeout
export async function oauthLogin(provider: OAuthProvider): Promise<OAuthResult> {
  let loginPromise: Promise<OAuthResult>;

  switch (provider) {
    case 'google':
      loginPromise = googleLogin();
      break;
    case 'kakao':
      loginPromise = kakaoLogin();
      break;
    case 'apple':
      loginPromise = appleLogin();
      break;
    default:
      throw new Error('지원하지 않는 로그인 방식입니다.');
  }

  // 타임아웃 래퍼 적용 (30초)
  return withTimeout(loginPromise, provider);
}

// Type declarations for external SDKs
declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: { credential: string }) => void;
          }) => void;
          prompt: (callback: (notification: {
            isNotDisplayed: () => boolean;
            isSkippedMoment: () => boolean;
          }) => void) => void;
        };
        oauth2: {
          initTokenClient: (config: {
            client_id: string;
            scope: string;
            callback: (response: { access_token?: string; error?: string }) => void;
          }) => { requestAccessToken: () => void };
        };
      };
    };
    Kakao?: {
      init: (key: string) => void;
      isInitialized: () => boolean;
      Auth: {
        login: (options: {
          success: (authObj: { access_token: string }) => void;
          fail: (err: { error?: string; error_description?: string }) => void;
        }) => void;
      };
    };
    AppleID?: {
      auth: {
        init: (config: {
          clientId: string;
          scope: string;
          redirectURI: string;
          usePopup: boolean;
        }) => void;
        signIn: () => Promise<{
          authorization?: {
            id_token?: string;
          };
        }>;
      };
    };
  }
}
