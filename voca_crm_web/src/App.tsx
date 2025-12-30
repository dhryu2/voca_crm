import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';
import { MainLayout, AuthGuard, AdminGuard, AdminLayout } from '@/components/layout';
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

// Public route wrapper - redirects to dashboard if already logged in
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();

  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return <>{children}</>;
}

function App() {
  return (
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
  );
}

export default App;
