import type { Tokens } from '@/types';

const API_BASE_URL = import.meta.env.PROD
  ? import.meta.env.VITE_API_BASE_URL
  : '/api';

class ApiClient {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private onAuthFailed?: () => void;

  constructor() {
    this.loadTokens();
  }

  setOnAuthFailed(callback: () => void) {
    this.onAuthFailed = callback;
  }

  private loadTokens() {
    const tokens = localStorage.getItem('tokens');
    if (tokens) {
      const parsed = JSON.parse(tokens) as Tokens;
      this.accessToken = parsed.accessToken;
      this.refreshToken = parsed.refreshToken;
    }
  }

  saveTokens(tokens: Tokens) {
    this.accessToken = tokens.accessToken;
    this.refreshToken = tokens.refreshToken;
    localStorage.setItem('tokens', JSON.stringify(tokens));
  }

  clearTokens() {
    this.accessToken = null;
    this.refreshToken = null;
    localStorage.removeItem('tokens');
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }

  /**
   * JWT 토큰 만료 여부 확인
   * @param token JWT 토큰 문자열
   * @returns 만료되었으면 true, 유효하면 false
   */
  private isTokenExpired(token: string): boolean {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      // exp는 초 단위, Date.now()는 밀리초 단위
      return payload.exp * 1000 < Date.now();
    } catch {
      return true; // 파싱 실패 시 만료로 간주
    }
  }

  /**
   * 유효한 토큰 보유 여부 확인 (존재 여부 + 만료 여부)
   */
  hasValidToken(): boolean {
    return !!this.accessToken && !this.isTokenExpired(this.accessToken);
  }

  private async refreshAccessToken(): Promise<boolean> {
    if (!this.refreshToken) return false;

    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: this.refreshToken }),
      });

      if (response.ok) {
        const data = await response.json();
        this.saveTokens({
          accessToken: data.accessToken,
          refreshToken: data.refreshToken,
        });
        return true;
      }
    } catch {
      // Refresh failed
    }
    return false;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = endpoint.startsWith('/api')
      ? `${API_BASE_URL}${endpoint}`
      : `${API_BASE_URL}/api${endpoint}`;

    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    // 토큰이 만료됐으면 요청 전에 선제적으로 갱신 시도
    if (this.accessToken && this.isTokenExpired(this.accessToken) && this.refreshToken) {
      const refreshed = await this.refreshAccessToken();
      if (!refreshed) {
        this.clearTokens();
        this.onAuthFailed?.();
        throw new ApiError('인증이 만료되었습니다. 다시 로그인해주세요.', 401);
      }
    }

    if (this.accessToken) {
      (headers as Record<string, string>)['Authorization'] = `Bearer ${this.accessToken}`;
    }

    let response = await fetch(url, { ...options, headers });

    // Handle 401 - try to refresh token (서버에서 토큰 무효화된 경우)
    if (response.status === 401 && this.refreshToken) {
      const refreshed = await this.refreshAccessToken();
      if (refreshed) {
        (headers as Record<string, string>)['Authorization'] = `Bearer ${this.accessToken}`;
        response = await fetch(url, { ...options, headers });
      } else {
        this.clearTokens();
        this.onAuthFailed?.();
        throw new ApiError('인증이 만료되었습니다. 다시 로그인해주세요.', 401);
      }
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new ApiError(
        errorData.message || '요청 처리 중 오류가 발생했습니다.',
        response.status,
        errorData
      );
    }

    // Handle 204 No Content
    if (response.status === 204) {
      return {} as T;
    }

    return response.json();
  }

  get<T>(endpoint: string, queryParams?: Record<string, string>): Promise<T> {
    let url = endpoint;
    if (queryParams) {
      const params = new URLSearchParams(queryParams);
      url = `${endpoint}?${params.toString()}`;
    }
    return this.request<T>(url, { method: 'GET' });
  }

  post<T>(endpoint: string, body?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  put<T>(endpoint: string, body?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  patch<T>(endpoint: string, body?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }

  /**
   * 서버에 로그아웃 요청 (refresh token 폐기)
   * 로그아웃 실패해도 로컬 토큰은 삭제해야 하므로 에러를 무시함
   */
  async logoutFromServer(): Promise<void> {
    if (!this.refreshToken) return;
    try {
      await fetch(`${API_BASE_URL}/api/auth/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: this.refreshToken }),
      });
    } catch {
      // 로그아웃 실패해도 로컬 토큰은 삭제
    }
  }

  /**
   * 토큰 갱신 시도 (외부에서 호출 가능)
   * @returns 갱신 성공 여부
   */
  async tryRefresh(): Promise<boolean> {
    return this.refreshAccessToken();
  }
}

export class ApiError extends Error {
  status: number;
  data?: unknown;

  constructor(message: string, status: number, data?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }
}

export const apiClient = new ApiClient();
