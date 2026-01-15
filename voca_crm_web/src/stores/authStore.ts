import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User, BusinessPlaceWithRole } from '@/types';
import { apiClient, ApiError } from '@/lib/api';
import { oauthLogin, type OAuthProvider } from '@/lib/oauth';

interface AuthState {
  user: User | null;
  businessPlaces: BusinessPlaceWithRole[];
  currentBusinessPlace: BusinessPlaceWithRole | null;
  isAuthenticated: boolean;
  isLoading: boolean;

  // Actions
  setUser: (user: User | null) => void;
  setBusinessPlaces: (places: BusinessPlaceWithRole[]) => void;
  setCurrentBusinessPlace: (place: BusinessPlaceWithRole | null) => void;
  loginWithProvider: (provider: OAuthProvider) => Promise<User>;
  login: (provider: string, token: string) => Promise<User>;
  signupWithProvider: (provider: OAuthProvider, params: SignupUserParams) => Promise<User>;
  signup: (params: SignupParams) => Promise<User>;
  logout: () => Promise<void>;
  loadUserFromToken: () => Promise<void>;
  fetchBusinessPlaces: () => Promise<void>;
}

interface SignupUserParams {
  username: string;
  phone: string;
  email?: string;
}

interface SignupParams {
  provider: string;
  token: string;
  username: string;
  phone: string;
  email?: string;
}

// JWT 토큰에서 사용자 정보 추출
function parseJwt(token: string): User | null {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    const payload = JSON.parse(jsonPayload);

    return {
      providerId: payload.sub || payload.providerId,
      name: payload.name || payload.username || '',
      email: payload.email,
      phone: payload.phone,
      role: payload.role || 'USER',
      isSystemAdmin: payload.isSystemAdmin === true,
      defaultBusinessPlaceId: payload.defaultBusinessPlaceId,
      createdAt: payload.createdAt || new Date().toISOString(),
    };
  } catch {
    return null;
  }
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      businessPlaces: [],
      currentBusinessPlace: null,
      isAuthenticated: false,
      isLoading: false,

      setUser: (user) => set({ user, isAuthenticated: !!user }),

      setBusinessPlaces: (places) => {
        set({ businessPlaces: places });
        // 현재 사업장이 없거나 목록에 없으면 첫 번째 사업장 선택
        const current = get().currentBusinessPlace;
        if (!current || !places.find(p => p.id === current.id)) {
          const defaultPlace = places.find(p => p.id === get().user?.defaultBusinessPlaceId) || places[0];
          set({ currentBusinessPlace: defaultPlace || null });
        }
      },

      setCurrentBusinessPlace: (place) => set({ currentBusinessPlace: place }),

      // OAuth provider를 사용한 로그인
      loginWithProvider: async (provider) => {
        set({ isLoading: true });
        try {
          // OAuth 인증
          const oauthResult = await oauthLogin(provider);

          // 백엔드 API 호출
          const result = await apiClient.post<{ accessToken: string; refreshToken: string }>('/auth/login', {
            provider: oauthResult.provider,
            token: oauthResult.token,
          });

          apiClient.saveTokens({
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          });

          const user = parseJwt(result.accessToken);
          if (!user) throw new Error('토큰 파싱 실패');

          set({ user, isAuthenticated: true, isLoading: false });

          // 사업장 목록 로드
          await get().fetchBusinessPlaces();

          return user;
        } catch (error) {
          set({ isLoading: false });
          // USER_NOT_FOUND 에러는 회원가입이 필요함을 의미
          if (error instanceof ApiError && error.status === 404) {
            const errorData = error.data as { error?: string };
            if (errorData?.error === 'USER_NOT_FOUND') {
              throw new Error('SIGNUP_REQUIRED');
            }
          }
          throw error;
        }
      },

      login: async (provider, token) => {
        set({ isLoading: true });
        try {
          const result = await apiClient.post<{ accessToken: string; refreshToken: string }>('/auth/login', {
            provider,
            token,
          });

          apiClient.saveTokens({
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          });

          const user = parseJwt(result.accessToken);
          if (!user) throw new Error('토큰 파싱 실패');

          set({ user, isAuthenticated: true, isLoading: false });

          // 사업장 목록 로드
          await get().fetchBusinessPlaces();

          return user;
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      // OAuth provider를 사용한 회원가입
      signupWithProvider: async (provider, params) => {
        set({ isLoading: true });
        try {
          // OAuth 인증
          const oauthResult = await oauthLogin(provider);

          // 백엔드 API 호출
          const result = await apiClient.post<{ accessToken: string; refreshToken: string }>('/auth/signup', {
            provider: oauthResult.provider,
            token: oauthResult.token,
            username: params.username,
            phone: params.phone,
            email: params.email,
          });

          apiClient.saveTokens({
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          });

          const user = parseJwt(result.accessToken);
          if (!user) throw new Error('토큰 파싱 실패');

          set({ user, isAuthenticated: true, isLoading: false });

          return user;
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      signup: async (params) => {
        set({ isLoading: true });
        try {
          const result = await apiClient.post<{ accessToken: string; refreshToken: string }>('/auth/signup', params);

          apiClient.saveTokens({
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          });

          const user = parseJwt(result.accessToken);
          if (!user) throw new Error('토큰 파싱 실패');

          set({ user, isAuthenticated: true, isLoading: false });

          return user;
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      logout: async () => {
        // 서버에 로그아웃 요청 (refresh token 폐기)
        await apiClient.logoutFromServer();
        // 로컬 토큰 삭제
        apiClient.clearTokens();
        set({
          user: null,
          businessPlaces: [],
          currentBusinessPlace: null,
          isAuthenticated: false,
        });
      },

      loadUserFromToken: async () => {
        const accessToken = apiClient.getAccessToken();

        // 토큰이 없으면 비인증 상태
        if (!accessToken) {
          set({ isAuthenticated: false, user: null });
          return;
        }

        // 토큰 만료 여부 확인
        if (!apiClient.hasValidToken()) {
          // Access token 만료 - refresh 시도
          try {
            const refreshed = await apiClient.tryRefresh();
            if (!refreshed) {
              // Refresh 실패 - 로그아웃 상태로
              apiClient.clearTokens();
              set({ isAuthenticated: false, user: null });
              return;
            }
          } catch {
            apiClient.clearTokens();
            set({ isAuthenticated: false, user: null });
            return;
          }
        }

        // 유효한 토큰으로 사용자 정보 파싱
        const validToken = apiClient.getAccessToken();
        if (validToken) {
          const user = parseJwt(validToken);
          if (user) {
            set({ user, isAuthenticated: true });
            await get().fetchBusinessPlaces();
          } else {
            apiClient.clearTokens();
            set({ isAuthenticated: false, user: null });
          }
        }
      },

      fetchBusinessPlaces: async () => {
        try {
          const user = get().user;
          if (!user) return;

          const response = await apiClient.get<{ data: BusinessPlaceWithRole[] }>(
            `/business-places/user/${user.providerId}`
          );

          get().setBusinessPlaces(response.data || []);
        } catch {
          // 사업장 로드 실패 시 빈 배열
          set({ businessPlaces: [] });
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        currentBusinessPlace: state.currentBusinessPlace,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
