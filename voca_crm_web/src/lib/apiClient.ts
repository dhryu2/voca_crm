import { ApiError } from './api';

const API_BASE_URL = import.meta.env.PROD
  ? import.meta.env.VITE_API_BASE_URL
  : '/api';

export const getAccessToken = (): string | null => {
  const tokens = localStorage.getItem('tokens');
  if (tokens) {
    try {
      const parsed = JSON.parse(tokens);
      return parsed.accessToken || null;
    } catch {
      return null;
    }
  }
  return null;
};

export const getRefreshToken = (): string | null => {
  const tokens = localStorage.getItem('tokens');
  if (tokens) {
    try {
      const parsed = JSON.parse(tokens);
      return parsed.refreshToken || null;
    } catch {
      return null;
    }
  }
  return null;
};

export const setTokens = (accessToken: string, refreshToken: string): void => {
  localStorage.setItem('tokens', JSON.stringify({ accessToken, refreshToken }));
};

export const removeTokens = (): void => {
  localStorage.removeItem('tokens');
};

const isTokenExpired = (token: string): boolean => {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const payload = JSON.parse(atob(base64));
    return payload.exp * 1000 < Date.now();
  } catch {
    return true;
  }
};

const refreshAccessToken = async (): Promise<boolean> => {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return false;

  try {
    const response = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });

    if (response.ok) {
      const data = await response.json();
      setTokens(data.accessToken, data.refreshToken);
      return true;
    }
  } catch {
    // Refresh failed
  }
  return false;
};

export const customFetch = async <T>(
  url: string,
  options: RequestInit = {}
): Promise<T> => {
  const { method = 'GET', headers: optionsHeaders = {}, body, signal } = options;

  const fullUrl = url.startsWith('http') ? url : `${API_BASE_URL}${url}`;

  let accessToken = getAccessToken();

  if (accessToken && isTokenExpired(accessToken)) {
    const refreshed = await refreshAccessToken();
    if (!refreshed) {
      removeTokens();
      throw new ApiError('인증이 만료되었습니다. 다시 로그인해주세요.', 401);
    }
    accessToken = getAccessToken();
  }

  const headers: HeadersInit = {
    ...optionsHeaders,
  };

  if (accessToken) {
    (headers as Record<string, string>)['Authorization'] = `Bearer ${accessToken}`;
  }

  if (body && typeof body === 'string') {
    (headers as Record<string, string>)['Content-Type'] = 'application/json';
  }

  let response = await fetch(fullUrl, {
    method,
    headers,
    body,
    signal,
  });

  if (response.status === 401) {
    const refreshToken = getRefreshToken();
    if (refreshToken) {
      const refreshed = await refreshAccessToken();
      if (refreshed) {
        const newAccessToken = getAccessToken();
        if (newAccessToken) {
          (headers as Record<string, string>)['Authorization'] = `Bearer ${newAccessToken}`;
        }
        response = await fetch(fullUrl, {
          method,
          headers,
          body,
          signal,
        });
      } else {
        removeTokens();
        throw new ApiError('인증이 만료되었습니다. 다시 로그인해주세요.', 401);
      }
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

  if (response.status === 204) {
    return {} as T;
  }

  return response.json();
};
