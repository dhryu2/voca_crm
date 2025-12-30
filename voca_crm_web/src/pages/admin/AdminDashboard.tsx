import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AlertTriangle,
  Megaphone,
  ArrowRight,
  AlertCircle,
  Users,
  Building2,
  TrendingUp,
  Activity,
  UserPlus,
  Clock,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui';
import { apiClient } from '@/lib/api';
import { cn } from '@/lib/utils';
import type { ErrorLogSummary, SystemStats } from '@/types';

export function AdminDashboardPage() {
  const [errorSummary, setErrorSummary] = useState<ErrorLogSummary | null>(null);
  const [systemStats, setSystemStats] = useState<SystemStats | null>(null);
  const [noticeCount, setNoticeCount] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    setIsLoading(true);
    try {
      const [summaryData, noticesData, statsData] = await Promise.all([
        apiClient.get<ErrorLogSummary>('/error-logs/summary').catch(() => null),
        apiClient.get<{ data: unknown[] }>('/admin/notices').catch(() => ({ data: [] })),
        apiClient.get<SystemStats>('/admin/stats').catch(() => null),
      ]);
      setErrorSummary(summaryData);
      setNoticeCount(noticesData?.data?.length || 0);
      setSystemStats(statsData);
    } catch (err) {
      console.error('Failed to load admin dashboard:', err);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
      </div>
    );
  }

  // Default stats if API doesn't return data
  const stats = systemStats || {
    totalUsers: 0,
    activeUsers: 0,
    newUsersToday: 0,
    newUsersThisWeek: 0,
    totalBusinessPlaces: 0,
    activeBusinessPlaces: 0,
    dau: 0,
    mau: 0,
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">시스템 관리</h1>
        <p className="text-gray-500 mt-1">시스템 전체 현황 및 관리 기능</p>
      </div>

      {/* System Overview Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                <Users className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">전체 사용자</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalUsers.toLocaleString()}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                <Building2 className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">전체 사업장</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalBusinessPlaces.toLocaleString()}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                <Activity className="w-6 h-6 text-purple-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">DAU</p>
                <p className="text-2xl font-bold text-gray-900">{stats.dau.toLocaleString()}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                <TrendingUp className="w-6 h-6 text-indigo-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">MAU</p>
                <p className="text-2xl font-bold text-gray-900">{stats.mau.toLocaleString()}</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Growth Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="border-l-4 border-l-green-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">오늘 가입자</p>
                <p className="text-3xl font-bold text-gray-900">{stats.newUsersToday}</p>
              </div>
              <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                <UserPlus className="w-6 h-6 text-green-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-l-4 border-l-blue-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">이번 주 가입자</p>
                <p className="text-3xl font-bold text-gray-900">{stats.newUsersThisWeek}</p>
              </div>
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                <Clock className="w-6 h-6 text-blue-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-l-4 border-l-purple-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">활성 사업장</p>
                <p className="text-3xl font-bold text-gray-900">{stats.activeBusinessPlaces}</p>
              </div>
              <div className="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                <Building2 className="w-6 h-6 text-purple-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Error & Notice Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="border-l-4 border-l-red-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">미해결 오류</p>
                <p className="text-3xl font-bold text-gray-900">
                  {errorSummary?.unresolvedCount || 0}
                </p>
              </div>
              <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                <AlertCircle className="w-6 h-6 text-red-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-l-4 border-l-orange-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Critical 오류</p>
                <p className="text-3xl font-bold text-gray-900">
                  {errorSummary?.criticalCount || 0}
                </p>
              </div>
              <div className="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center">
                <AlertTriangle className="w-6 h-6 text-orange-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-l-4 border-l-yellow-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">전체 오류 (7일)</p>
                <p className="text-3xl font-bold text-gray-900">
                  {errorSummary?.totalErrors || 0}
                </p>
              </div>
              <div className="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center">
                <AlertTriangle className="w-6 h-6 text-yellow-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-l-4 border-l-cyan-500">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">등록된 공지</p>
                <p className="text-3xl font-bold text-gray-900">{noticeCount}</p>
              </div>
              <div className="w-12 h-12 bg-cyan-100 rounded-xl flex items-center justify-center">
                <Megaphone className="w-6 h-6 text-cyan-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="grid lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="w-5 h-5 text-blue-500" />
              사용자 관리
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-gray-600 mb-4">
              시스템 사용자를 조회하고 관리합니다.
              계정 상태 변경, 정지, 차단 기능을 제공합니다.
            </p>
            <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm text-gray-500">전체 사용자</p>
                <p className="text-2xl font-bold text-blue-600">
                  {stats.totalUsers.toLocaleString()}명
                </p>
              </div>
              <Link
                to="/admin/users"
                className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                사용자 관리
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Building2 className="w-5 h-5 text-green-500" />
              사업장 관리
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-gray-600 mb-4">
              등록된 사업장을 조회하고 관리합니다.
              사업장 정보 확인 및 상태 관리 기능을 제공합니다.
            </p>
            <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm text-gray-500">전체 사업장</p>
                <p className="text-2xl font-bold text-green-600">
                  {stats.totalBusinessPlaces.toLocaleString()}개
                </p>
              </div>
              <Link
                to="/admin/business-places"
                className="inline-flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                사업장 관리
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <AlertTriangle className="w-5 h-5 text-red-500" />
              오류 로그 모니터링
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-gray-600 mb-4">
              시스템에서 발생한 오류를 확인하고 관리합니다.
              필터링, 검색, 해결 상태 관리 기능을 제공합니다.
            </p>
            <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm text-gray-500">미해결 오류</p>
                <p className="text-2xl font-bold text-red-600">
                  {errorSummary?.unresolvedCount || 0}건
                </p>
              </div>
              <Link
                to="/admin/logs"
                className="inline-flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
              >
                오류 로그 보기
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Megaphone className="w-5 h-5 text-cyan-500" />
              시스템 공지사항
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-gray-600 mb-4">
              사용자에게 표시되는 공지사항을 관리합니다.
              팝업, 배너, 리스트 형태의 공지를 설정할 수 있습니다.
            </p>
            <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm text-gray-500">등록된 공지</p>
                <p className="text-2xl font-bold text-cyan-600">{noticeCount}건</p>
              </div>
              <Link
                to="/admin/notices"
                className="inline-flex items-center gap-2 px-4 py-2 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition-colors"
              >
                공지사항 관리
                <ArrowRight className="w-4 h-4" />
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Severity Breakdown */}
      {errorSummary && (
        <Card>
          <CardHeader>
            <CardTitle>오류 심각도 분포 (최근 7일)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-4 gap-4">
              <div className={cn(
                "text-center p-4 rounded-lg",
                errorSummary.criticalCount > 0 ? "bg-red-100" : "bg-red-50"
              )}>
                <p className="text-3xl font-bold text-red-600">{errorSummary.criticalCount}</p>
                <p className="text-sm text-red-700">Critical</p>
              </div>
              <div className={cn(
                "text-center p-4 rounded-lg",
                errorSummary.highCount > 0 ? "bg-orange-100" : "bg-orange-50"
              )}>
                <p className="text-3xl font-bold text-orange-600">{errorSummary.highCount}</p>
                <p className="text-sm text-orange-700">High</p>
              </div>
              <div className={cn(
                "text-center p-4 rounded-lg",
                errorSummary.mediumCount > 0 ? "bg-yellow-100" : "bg-yellow-50"
              )}>
                <p className="text-3xl font-bold text-yellow-600">{errorSummary.mediumCount}</p>
                <p className="text-sm text-yellow-700">Medium</p>
              </div>
              <div className="text-center p-4 bg-blue-50 rounded-lg">
                <p className="text-3xl font-bold text-blue-600">{errorSummary.lowCount}</p>
                <p className="text-sm text-blue-700">Low</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
