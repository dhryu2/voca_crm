import { NavLink } from 'react-router-dom';
import {
  Shield,
  AlertTriangle,
  Megaphone,
  ArrowLeft,
  Users,
  Building2,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAuthStore } from '@/stores/authStore';

const adminNavItems = [
  { path: '/admin', label: '관리자 홈', icon: Shield, exact: true },
  { path: '/admin/users', label: '사용자 관리', icon: Users },
  { path: '/admin/business-places', label: '사업장 관리', icon: Building2 },
  { path: '/admin/logs', label: '오류 로그', icon: AlertTriangle },
  { path: '/admin/notices', label: '공지사항 관리', icon: Megaphone },
];

export function AdminSidebar() {
  const { user } = useAuthStore();

  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-64 bg-gray-900 flex flex-col">
      {/* Logo */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-gray-800">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-red-600 rounded-lg flex items-center justify-center">
            <Shield className="w-4 h-4 text-white" />
          </div>
          <div>
            <span className="font-bold text-lg text-white">VocaCRM</span>
            <span className="ml-2 text-xs bg-red-600 text-white px-1.5 py-0.5 rounded">Admin</span>
          </div>
        </div>
      </div>

      {/* Admin Info */}
      <div className="px-4 py-3 border-b border-gray-800">
        <p className="text-xs text-gray-500 uppercase tracking-wider">시스템 관리자</p>
        <p className="text-sm font-medium text-white truncate">{user?.name}</p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {adminNavItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            end={item.exact}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-red-600/20 text-red-400'
                  : 'text-gray-400 hover:bg-gray-800 hover:text-white'
              )
            }
          >
            <item.icon className="w-5 h-5 flex-shrink-0" />
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>

      {/* Back to Main */}
      <div className="px-3 py-4 border-t border-gray-800">
        <NavLink
          to="/dashboard"
          className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-400 hover:bg-gray-800 hover:text-white transition-colors"
        >
          <ArrowLeft className="w-5 h-5 flex-shrink-0" />
          <span>일반 화면으로 돌아가기</span>
        </NavLink>
      </div>

      {/* Footer */}
      <div className="px-4 py-3 border-t border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-red-600 rounded-full flex items-center justify-center">
            <span className="text-xs font-bold text-white">
              {user?.name?.charAt(0) || 'A'}
            </span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white truncate">{user?.name}</p>
            <p className="text-xs text-gray-500">시스템 관리자</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
