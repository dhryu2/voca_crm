export type OAuthProvider = 'google' | 'kakao' | 'apple';

export interface OAuthResult {
  provider: string; // API format: google.com, kakao.com, apple.com
  token: string;
}

// Google OAuth using GSI (Google Sign-In)
export async function googleLogin(): Promise<OAuthResult> {
  return new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

    if (!clientId || clientId === 'your-google-client-id.apps.googleusercontent.com') {
      reject(new Error('Google Client ID가 설정되지 않았습니다. .env 파일을 확인해주세요.'));
      return;
    }

    // Load Google GSI script if not loaded
    if (!window.google?.accounts) {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.defer = true;
      script.onload = () => initGoogleLogin(clientId, resolve, reject);
      script.onerror = () => reject(new Error('Google 로그인 스크립트를 불러올 수 없습니다.'));
      document.head.appendChild(script);
    } else {
      initGoogleLogin(clientId, resolve, reject);
    }
  });
}

function initGoogleLogin(
  clientId: string,
  resolve: (result: OAuthResult) => void,
  reject: (error: Error) => void
) {
  window.google.accounts.id.initialize({
    client_id: clientId,
    callback: (response: { credential: string }) => {
      if (response.credential) {
        resolve({
          provider: 'google.com',
          token: response.credential,
        });
      } else {
        reject(new Error('Google 로그인에 실패했습니다.'));
      }
    },
  });

  // Prompt for account selection
  window.google.accounts.id.prompt((notification: { isNotDisplayed: () => boolean; isSkippedMoment: () => boolean }) => {
    if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
      // Fallback: use popup
      const tokenClient = window.google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: 'openid email profile',
        callback: (tokenResponse: { access_token?: string; error?: string }) => {
          if (tokenResponse.access_token) {
            resolve({
              provider: 'google.com',
              token: tokenResponse.access_token,
            });
          } else {
            reject(new Error(tokenResponse.error || 'Google 로그인에 실패했습니다.'));
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
      reject(new Error('Kakao Client ID가 설정되지 않았습니다. .env 파일을 확인해주세요.'));
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
      script.onerror = () => reject(new Error('Kakao 로그인 스크립트를 불러올 수 없습니다.'));
      document.head.appendChild(script);
    } else {
      initKakaoLogin(clientId, resolve, reject);
    }
  });
}

function initKakaoLogin(
  clientId: string,
  resolve: (result: OAuthResult) => void,
  reject: (error: Error) => void
) {
  if (!window.Kakao.isInitialized()) {
    window.Kakao.init(clientId);
  }

  window.Kakao.Auth.login({
    success: (authObj: { access_token: string }) => {
      resolve({
        provider: 'kakao.com',
        token: authObj.access_token,
      });
    },
    fail: (err: { error_description?: string }) => {
      reject(new Error(err.error_description || 'Kakao 로그인에 실패했습니다.'));
    },
  });
}

// Apple OAuth (Sign in with Apple JS)
export async function appleLogin(): Promise<OAuthResult> {
  return new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_APPLE_CLIENT_ID;
    const redirectUri = import.meta.env.VITE_APPLE_REDIRECT_URI;

    if (!clientId || clientId === 'your-apple-service-id') {
      reject(new Error('Apple Client ID가 설정되지 않았습니다. .env 파일을 확인해주세요.'));
      return;
    }

    // Load Apple Sign-In JS if not loaded
    if (!window.AppleID) {
      const script = document.createElement('script');
      script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
      script.async = true;
      script.onload = () => initAppleLogin(clientId, redirectUri, resolve, reject);
      script.onerror = () => reject(new Error('Apple 로그인 스크립트를 불러올 수 없습니다.'));
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
  reject: (error: Error) => void
) {
  try {
    window.AppleID.auth.init({
      clientId,
      scope: 'name email',
      redirectURI: redirectUri,
      usePopup: true,
    });

    const response = await window.AppleID.auth.signIn();

    if (response.authorization?.id_token) {
      resolve({
        provider: 'apple.com',
        token: response.authorization.id_token,
      });
    } else {
      reject(new Error('Apple 로그인에 실패했습니다.'));
    }
  } catch (error) {
    if (error instanceof Error) {
      reject(error);
    } else {
      reject(new Error('Apple 로그인에 실패했습니다.'));
    }
  }
}

// Unified OAuth login function
export async function oauthLogin(provider: OAuthProvider): Promise<OAuthResult> {
  switch (provider) {
    case 'google':
      return googleLogin();
    case 'kakao':
      return kakaoLogin();
    case 'apple':
      return appleLogin();
    default:
      throw new Error('지원하지 않는 로그인 방식입니다.');
  }
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
          fail: (err: { error_description?: string }) => void;
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
