import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { HotkeysProvider, useHotkeys } from 'react-hotkeys-hook';
import { useAuthStore } from '@/stores/authStore';
import { useUIStore } from '@/stores/uiStore';
import { apiClient } from '@/lib/api';
import { MainLayout, AuthGuard, AdminGuard, AdminLayout } from '@/components/layout';
import { CommandPalette, KeyboardShortcutsHelp } from '@/components/ui';
import {
  LandingPage,
  LoginPage,
  SignupPage,
  DashboardPage,
  CustomersPage,
  ReservationsPage,
  VisitsPage,
  MemosPage,
  SettingsPage,
} from '@/pages';
import {
  AdminDashboardPage,
  ErrorLogsPage,
  NoticesPage,
  UserManagementPage,
  BusinessPlaceManagementPage,
} from '@/pages/admin';
import './index.css';

// Redirect based on auth state
function RootRedirect() {
  const { isAuthenticated } = useAuthStore();
  return <Navigate to={isAuthenticated ? '/dashboard' : '/'} replace />;
}

// 전역 단축키 훅 컴포넌트
function GlobalShortcuts() {
  const { toggleCommandPalette, toggleShortcutsHelp, closeCommandPalette, closeShortcutsHelp, isCommandPaletteOpen, isShortcutsHelpOpen } = useUIStore();

  // Ctrl+K: 명령어 팔레트
  useHotkeys('ctrl+k, meta+k', (e) => {
    e.preventDefault();
    toggleCommandPalette();
  }, { enableOnFormTags: true });

  // Ctrl+/: 단축키 도움말
  useHotkeys('ctrl+/, meta+/', (e) => {
    e.preventDefault();
    toggleShortcutsHelp();
  }, { enableOnFormTags: true });

  // ESC: 모달 닫기
  useHotkeys('escape', () => {
    if (isCommandPaletteOpen) closeCommandPalette();
    else if (isShortcutsHelpOpen) closeShortcutsHelp();
  }, { enableOnFormTags: true });

  return null;
}

// Public route wrapper - redirects to dashboard if already logged in
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();

  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return <>{children}</>;
}

function App() {
  const { isCommandPaletteOpen, isShortcutsHelpOpen, closeCommandPalette, closeShortcutsHelp } = useUIStore();

  useEffect(() => {
    // 인증 실패 시 (401 + refresh 실패) 자동 로그아웃 처리
    apiClient.setOnAuthFailed(() => {
      useAuthStore.getState().logout();
      // 리다이렉트는 AuthGuard에서 처리됨
    });
  }, []);

  return (
    <HotkeysProvider>
      <GlobalShortcuts />
      <BrowserRouter>
      <Routes>
        {/* Public Routes */}
        <Route
          path="/"
          element={
            <PublicRoute>
              <LandingPage />
            </PublicRoute>
          }
        />
        <Route
          path="/login"
          element={
            <PublicRoute>
              <LoginPage />
            </PublicRoute>
          }
        />
        <Route
          path="/signup"
          element={
            <PublicRoute>
              <SignupPage />
            </PublicRoute>
          }
        />

        {/* Protected Routes */}
        <Route
          path="/dashboard"
          element={
            <AuthGuard>
              <MainLayout>
                <DashboardPage />
              </MainLayout>
            </AuthGuard>
          }
        />
        <Route
          path="/customers"
          element={
            <AuthGuard>
              <MainLayout>
                <CustomersPage />
              </MainLayout>
            </AuthGuard>
          }
        />
        <Route
          path="/reservations"
          element={
            <AuthGuard>
              <MainLayout>
                <ReservationsPage />
              </MainLayout>
            </AuthGuard>
          }
        />
        <Route
          path="/visits"
          element={
            <AuthGuard>
              <MainLayout>
                <VisitsPage />
              </MainLayout>
            </AuthGuard>
          }
        />
        <Route
          path="/memos"
          element={
            <AuthGuard>
              <MainLayout>
                <MemosPage />
              </MainLayout>
            </AuthGuard>
          }
        />
        <Route
          path="/settings"
          element={
            <AuthGuard>
              <MainLayout>
                <SettingsPage />
              </MainLayout>
            </AuthGuard>
          }
        />

        {/* Admin Routes - System Admin Only */}
        <Route
          path="/admin"
          element={
            <AdminGuard>
              <AdminLayout>
                <AdminDashboardPage />
              </AdminLayout>
            </AdminGuard>
          }
        />
        <Route
          path="/admin/logs"
          element={
            <AdminGuard>
              <AdminLayout>
                <ErrorLogsPage />
              </AdminLayout>
            </AdminGuard>
          }
        />
        <Route
          path="/admin/notices"
          element={
            <AdminGuard>
              <AdminLayout>
                <NoticesPage />
              </AdminLayout>
            </AdminGuard>
          }
        />
        <Route
          path="/admin/users"
          element={
            <AdminGuard>
              <AdminLayout>
                <UserManagementPage />
              </AdminLayout>
            </AdminGuard>
          }
        />
        <Route
          path="/admin/business-places"
          element={
            <AdminGuard>
              <AdminLayout>
                <BusinessPlaceManagementPage />
              </AdminLayout>
            </AdminGuard>
          }
        />

        {/* Catch-all redirect */}
        <Route path="*" element={<RootRedirect />} />
      </Routes>
      </BrowserRouter>
      <CommandPalette isOpen={isCommandPaletteOpen} onClose={closeCommandPalette} />
      <KeyboardShortcutsHelp isOpen={isShortcutsHelpOpen} onClose={closeShortcutsHelp} />
    </HotkeysProvider>
  );
}

export default App;
