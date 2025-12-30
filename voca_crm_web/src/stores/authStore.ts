import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User, BusinessPlaceWithRole } from '@/types';
import { apiClient } from '@/lib/api';

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
  login: (provider: string, token: string) => Promise<User>;
  signup: (params: SignupParams) => Promise<User>;
  logout: () => void;
  loadUserFromToken: () => Promise<void>;
  fetchBusinessPlaces: () => Promise<void>;
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

      logout: () => {
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
        if (!accessToken) {
          set({ isAuthenticated: false, user: null });
          return;
        }

        const user = parseJwt(accessToken);
        if (user) {
          set({ user, isAuthenticated: true });
          await get().fetchBusinessPlaces();
        } else {
          apiClient.clearTokens();
          set({ isAuthenticated: false, user: null });
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
