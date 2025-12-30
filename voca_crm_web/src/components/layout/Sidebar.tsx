import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Calendar,
  ClipboardCheck,
  FileText,
  Settings,
  LogOut,
  ChevronLeft,
  Building2,
  Shield,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAuthStore } from '@/stores/authStore';
import { useState } from 'react';

const navItems = [
  { path: '/dashboard', label: '대시보드', icon: LayoutDashboard },
  { path: '/customers', label: '고객 관리', icon: Users },
  { path: '/reservations', label: '예약 관리', icon: Calendar },
  { path: '/visits', label: '방문 관리', icon: ClipboardCheck },
  { path: '/memos', label: '메모', icon: FileText },
];

const bottomNavItems = [
  { path: '/settings', label: '설정', icon: Settings },
];

export function Sidebar() {
  const { user, currentBusinessPlace, businessPlaces, setCurrentBusinessPlace, logout } = useAuthStore();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [showBusinessPlaceDropdown, setShowBusinessPlaceDropdown] = useState(false);

  const handleLogout = () => {
    logout();
    window.location.href = '/';
  };

  return (
    <aside
      className={cn(
        'fixed left-0 top-0 z-40 h-screen bg-white border-r border-gray-200 transition-all duration-300 flex flex-col',
        isCollapsed ? 'w-16' : 'w-64'
      )}
    >
      {/* Logo */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-gray-100">
        {!isCollapsed && (
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-primary-800 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-sm">V</span>
            </div>
            <span className="font-bold text-lg text-gray-900">VocaCRM</span>
          </div>
        )}
        <button
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <ChevronLeft
            className={cn(
              'w-5 h-5 text-gray-500 transition-transform',
              isCollapsed && 'rotate-180'
            )}
          />
        </button>
      </div>

      {/* Business Place Selector */}
      {!isCollapsed && currentBusinessPlace && (
        <div className="px-3 py-3 border-b border-gray-100">
          <div className="relative">
            <button
              onClick={() => setShowBusinessPlaceDropdown(!showBusinessPlaceDropdown)}
              className="w-full flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors text-left"
            >
              <Building2 className="w-4 h-4 text-gray-500 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate">
                  {currentBusinessPlace.name}
                </p>
                <p className="text-xs text-gray-500">{currentBusinessPlace.role}</p>
              </div>
            </button>

            {showBusinessPlaceDropdown && businessPlaces.length > 1 && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-50">
                {businessPlaces.map((place) => (
                  <button
                    key={place.id}
                    onClick={() => {
                      setCurrentBusinessPlace(place);
                      setShowBusinessPlaceDropdown(false);
                    }}
                    className={cn(
                      'w-full px-3 py-2 text-left text-sm hover:bg-gray-50 transition-colors',
                      place.id === currentBusinessPlace.id && 'bg-primary-50 text-primary-700'
                    )}
                  >
                    {place.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary-50 text-primary-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              )
            }
          >
            <item.icon className="w-5 h-5 flex-shrink-0" />
            {!isCollapsed && <span>{item.label}</span>}
          </NavLink>
        ))}
      </nav>

      {/* System Admin Menu - Only for system admins */}
      {user?.isSystemAdmin && (
        <div className="px-3 py-3 border-t border-gray-100">
          {!isCollapsed && (
            <p className="px-3 mb-2 text-xs font-medium text-gray-400 uppercase tracking-wider">
              시스템 관리
            </p>
          )}
          <NavLink
            to="/admin"
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-red-50 text-red-700'
                  : 'text-gray-600 hover:bg-red-50 hover:text-red-700'
              )
            }
          >
            <Shield className="w-5 h-5 flex-shrink-0" />
            {!isCollapsed && <span>관리자 모드</span>}
          </NavLink>
        </div>
      )}

      {/* Bottom Navigation */}
      <div className="px-3 py-4 border-t border-gray-100 space-y-1">
        {bottomNavItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary-50 text-primary-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              )
            }
          >
            <item.icon className="w-5 h-5 flex-shrink-0" />
            {!isCollapsed && <span>{item.label}</span>}
          </NavLink>
        ))}

        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-600 hover:bg-red-50 hover:text-red-600 transition-colors"
        >
          <LogOut className="w-5 h-5 flex-shrink-0" />
          {!isCollapsed && <span>로그아웃</span>}
        </button>
      </div>

      {/* User Info */}
      {!isCollapsed && user && (
        <div className="px-3 py-3 border-t border-gray-100">
          <div className="flex items-center gap-3 px-3">
            <div className="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
              <span className="text-sm font-medium text-gray-600">
                {user.name.charAt(0)}
              </span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">{user.name}</p>
              <p className="text-xs text-gray-500 truncate">{user.email}</p>
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
