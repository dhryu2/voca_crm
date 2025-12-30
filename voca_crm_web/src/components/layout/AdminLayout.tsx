import { AdminSidebar } from './AdminSidebar';

interface AdminLayoutProps {
  children: React.ReactNode;
}

export function AdminLayout({ children }: AdminLayoutProps) {
  return (
    <div className="min-h-screen bg-gray-100">
      <AdminSidebar />
      <div className="pl-64 min-h-screen flex flex-col">
        {/* Admin Header */}
        <header className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="px-3 py-1 bg-red-100 rounded-lg">
              <span className="text-sm font-medium text-red-700">관리자 모드</span>
            </div>
          </div>
          <div className="text-sm text-gray-500">
            시스템 관리 기능에 접근 중입니다
          </div>
        </header>
        <main className="flex-1 p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
