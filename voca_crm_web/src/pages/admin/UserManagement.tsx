import { useEffect, useState, useCallback } from 'react';
import {
  Search,
  ChevronLeft,
  ChevronRight,
  Users,
  Shield,
  X,
  Mail,
  Phone,
  Calendar,
  Building2,
  Clock,
} from 'lucide-react';
import { Card, CardContent, Button, Input } from '@/components/ui';
import { apiClient } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';
import type { AdminUser, PaginatedResponse } from '@/types';

export function UserManagementPage() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [totalElements, setTotalElements] = useState(0);
  const [currentPage, setCurrentPage] = useState(0);
  const [pageSize] = useState(20);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');

  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);

  const loadUsers = useCallback(async () => {
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      params.append('page', currentPage.toString());
      params.append('size', pageSize.toString());
      if (search) params.append('search', search);

      const response = await apiClient.get<PaginatedResponse<AdminUser>>(
        `/admin/users?${params.toString()}`
      );
      setUsers(response.content || []);
      setTotalElements(response.totalElements || 0);
    } catch (err) {
      console.error('Failed to load users:', err);
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentPage, pageSize, search]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setCurrentPage(0);
    loadUsers();
  };

  const totalPages = Math.ceil(totalElements / pageSize);

  const openUserDetail = (user: AdminUser) => {
    setSelectedUser(user);
    setIsDetailOpen(true);
  };

  const closeUserDetail = () => {
    setIsDetailOpen(false);
    setSelectedUser(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">사용자 관리</h1>
        <p className="text-gray-500 mt-1">시스템 사용자를 조회합니다</p>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <form onSubmit={handleSearch} className="flex flex-wrap gap-4">
            <div className="flex-1 min-w-[200px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <Input
                  type="text"
                  placeholder="이름, 이메일, 전화번호 검색"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>
            <Button type="submit">검색</Button>
          </form>
        </CardContent>
      </Card>

      {/* Users Table */}
      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center h-64">
              <div className="w-8 h-8 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
            </div>
          ) : users.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-gray-500">
              <Users className="w-12 h-12 mb-2" />
              <p>사용자가 없습니다</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      사용자
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      연락처
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      사업장
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      가입일
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {users.map((user) => (
                    <tr
                      key={user.providerId}
                      className="hover:bg-gray-50 cursor-pointer"
                      onClick={() => openUserDetail(user)}
                    >
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                            <span className="text-sm font-medium text-blue-600">
                              {user.name?.charAt(0) || '?'}
                            </span>
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <p className="text-sm font-medium text-gray-900">{user.name}</p>
                              {user.isSystemAdmin && (
                                <Shield className="w-4 h-4 text-red-500" />
                              )}
                            </div>
                            <p className="text-xs text-gray-500">{user.provider}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm">
                          {user.email && (
                            <p className="text-gray-900">{user.email}</p>
                          )}
                          {user.phone && (
                            <p className="text-gray-500">{user.phone}</p>
                          )}
                          {!user.email && !user.phone && (
                            <p className="text-gray-400">-</p>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {user.businessPlaceCount}개
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {formatDate(user.createdAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between px-6 py-3 border-t border-gray-200">
              <p className="text-sm text-gray-500">
                총 {totalElements.toLocaleString()}명 중 {currentPage * pageSize + 1}-
                {Math.min((currentPage + 1) * pageSize, totalElements)}명 표시
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(Math.max(0, currentPage - 1))}
                  disabled={currentPage === 0}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <span className="text-sm text-gray-600">
                  {currentPage + 1} / {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage(Math.min(totalPages - 1, currentPage + 1))}
                  disabled={currentPage >= totalPages - 1}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* User Detail Slide Panel */}
      <div
        className={cn(
          'fixed inset-y-0 right-0 w-full max-w-md bg-white shadow-2xl z-50 transform transition-transform duration-300',
          isDetailOpen ? 'translate-x-0' : 'translate-x-full'
        )}
      >
        {selectedUser && (
          <div className="h-full flex flex-col">
            {/* Panel Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">사용자 상세</h2>
              <button
                onClick={closeUserDetail}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Panel Content */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              {/* User Info */}
              <div className="text-center">
                <div className="w-20 h-20 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <span className="text-2xl font-bold text-blue-600">
                    {selectedUser.name?.charAt(0) || '?'}
                  </span>
                </div>
                <h3 className="text-xl font-bold text-gray-900 flex items-center justify-center gap-2">
                  {selectedUser.name}
                  {selectedUser.isSystemAdmin && (
                    <Shield className="w-5 h-5 text-red-500" />
                  )}
                </h3>
                <p className="text-gray-500">{selectedUser.provider}</p>
              </div>

              {/* Contact Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">연락처</h4>
                <div className="space-y-2">
                  {selectedUser.email && (
                    <div className="flex items-center gap-3 text-sm">
                      <Mail className="w-4 h-4 text-gray-400" />
                      <span>{selectedUser.email}</span>
                    </div>
                  )}
                  {selectedUser.phone && (
                    <div className="flex items-center gap-3 text-sm">
                      <Phone className="w-4 h-4 text-gray-400" />
                      <span>{selectedUser.phone}</span>
                    </div>
                  )}
                  {!selectedUser.email && !selectedUser.phone && (
                    <p className="text-sm text-gray-400">등록된 연락처 없음</p>
                  )}
                </div>
              </div>

              {/* Activity Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">활동 정보</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2 text-gray-500 mb-1">
                      <Building2 className="w-4 h-4" />
                      <span className="text-xs">사업장</span>
                    </div>
                    <p className="text-xl font-bold text-gray-900">
                      {selectedUser.businessPlaceCount}개
                    </p>
                  </div>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2 text-gray-500 mb-1">
                      <Clock className="w-4 h-4" />
                      <span className="text-xs">로그인</span>
                    </div>
                    <p className="text-xl font-bold text-gray-900">
                      {selectedUser.loginCount}회
                    </p>
                  </div>
                </div>
              </div>

              {/* Date Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">계정 정보</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex items-center gap-3">
                    <Calendar className="w-4 h-4 text-gray-400" />
                    <span className="text-gray-500">가입일:</span>
                    <span>{formatDate(selectedUser.createdAt)}</span>
                  </div>
                  {selectedUser.lastLoginAt && (
                    <div className="flex items-center gap-3">
                      <Clock className="w-4 h-4 text-gray-400" />
                      <span className="text-gray-500">최근 로그인:</span>
                      <span>{formatDate(selectedUser.lastLoginAt)}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Overlay */}
      {isDetailOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40"
          onClick={closeUserDetail}
        />
      )}
    </div>
  );
}
