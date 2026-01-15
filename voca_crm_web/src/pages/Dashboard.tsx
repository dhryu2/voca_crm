import { useEffect, useState } from 'react';
import {
  Calendar,
  Users,
  ClipboardCheck,
  FileText,
  ArrowRight,
  Clock,
  TrendingUp,
  BarChart3,
  PieChart,
  Bookmark,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, Badge, Button, EmptyState, TrendChart, DistributionChart } from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatRelativeTime, formatTime } from '@/lib/utils';
import type {
  HomeStatistics,
  TodaySchedule,
  RecentActivity,
  MemberRegistrationTrend,
  MemberGradeDistribution,
  ReservationTrend,
  MemoStatistics,
} from '@/types';
import { Link } from 'react-router-dom';

export function DashboardPage() {
  const { user, currentBusinessPlace } = useAuthStore();
  const [statistics, setStatistics] = useState<HomeStatistics | null>(null);
  const [todaySchedule, setTodaySchedule] = useState<TodaySchedule[]>([]);
  const [recentActivities, setRecentActivities] = useState<RecentActivity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 고급 통계 상태
  const [memberTrend, setMemberTrend] = useState<MemberRegistrationTrend | null>(null);
  const [gradeDistribution, setGradeDistribution] = useState<MemberGradeDistribution | null>(null);
  const [reservationTrend, setReservationTrend] = useState<ReservationTrend | null>(null);
  const [memoStats, setMemoStats] = useState<MemoStatistics | null>(null);
  const [chartsLoading, setChartsLoading] = useState(false);

  useEffect(() => {
    if (currentBusinessPlace?.id) {
      loadDashboardData();
    } else {
      setIsLoading(false);
      setError('사업장을 선택해주세요.');
    }
  }, [currentBusinessPlace?.id]);

  const loadDashboardData = async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    setError(null);

    try {
      const [statsData, scheduleData, activitiesData] = await Promise.all([
        apiClient.get<HomeStatistics>(`/statistics/home/${currentBusinessPlace.id}`),
        apiClient.get<TodaySchedule[]>(`/statistics/today-schedule/${currentBusinessPlace.id}`, { limit: '5' }),
        apiClient.get<RecentActivity[]>(`/statistics/recent-activities/${currentBusinessPlace.id}`, { limit: '5' }),
      ]);

      setStatistics(statsData);
      setTodaySchedule(scheduleData);
      setRecentActivities(activitiesData);

      // 고급 통계 로드 (비동기로 백그라운드에서)
      loadAdvancedStatistics();
    } catch (err) {
      setError(err instanceof Error ? err.message : '데이터를 불러오는 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const loadAdvancedStatistics = async () => {
    if (!currentBusinessPlace?.id) return;

    setChartsLoading(true);
    try {
      const [memberTrendData, gradeData, reservationData, memoData] = await Promise.all([
        apiClient.get<MemberRegistrationTrend>(
          `/statistics/member-registration-trend/${currentBusinessPlace.id}`,
          { days: '7' }
        ),
        apiClient.get<MemberGradeDistribution>(
          `/statistics/member-grade-distribution/${currentBusinessPlace.id}`
        ),
        apiClient.get<ReservationTrend>(
          `/statistics/reservation-trend/${currentBusinessPlace.id}`,
          { days: '7' }
        ),
        apiClient.get<MemoStatistics>(
          `/statistics/memo-statistics/${currentBusinessPlace.id}`,
          { days: '7' }
        ),
      ]);

      setMemberTrend(memberTrendData);
      setGradeDistribution(gradeData);
      setReservationTrend(reservationData);
      setMemoStats(memoData);
    } catch (err) {
      console.error('고급 통계 로드 실패:', err);
      // 차트 로드 실패해도 에러 표시하지 않음 (graceful fallback)
    } finally {
      setChartsLoading(false);
    }
  };

  const statCards = statistics ? [
    {
      label: '오늘 예약',
      value: statistics.todayReservations,
      icon: Calendar,
      color: 'text-primary-600',
      bgColor: 'bg-primary-50',
      link: '/reservations',
    },
    {
      label: '오늘 방문',
      value: statistics.todayVisits,
      icon: ClipboardCheck,
      color: 'text-green-600',
      bgColor: 'bg-green-50',
      link: '/visits',
    },
    {
      label: '총 고객',
      value: statistics.totalMembers,
      icon: Users,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      link: '/customers',
    },
    {
      label: '대기 메모',
      value: statistics.pendingMemos,
      icon: FileText,
      color: 'text-amber-600',
      bgColor: 'bg-amber-50',
      link: '/memos',
    },
  ] : [];

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 text-sm">데이터를 불러오는 중...</p>
        </div>
      </div>
    );
  }

  if (error && !currentBusinessPlace) {
    return (
      <div className="flex items-center justify-center h-96">
        <EmptyState
          icon={<Users className="w-8 h-8" />}
          title="사업장을 선택해주세요"
          description="사이드바에서 사업장을 선택하거나 새 사업장을 등록하세요."
          action={
            <Link to="/settings">
              <Button>사업장 관리</Button>
            </Link>
          }
        />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Welcome Section */}
      <div className="bg-gradient-to-r from-primary-600 to-primary-800 rounded-2xl p-6 text-white">
        <h1 className="text-2xl font-bold mb-1">
          안녕하세요, {user?.name}님
        </h1>
        <p className="text-white/80">
          {currentBusinessPlace?.name || 'VocaCRM'}의 오늘 현황입니다
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <Link key={stat.label} to={stat.link}>
            <Card className="hover:shadow-md transition-shadow cursor-pointer">
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-500 mb-1">{stat.label}</p>
                    <p className="text-3xl font-bold text-gray-900">{stat.value}</p>
                  </div>
                  <div className={`w-12 h-12 ${stat.bgColor} rounded-xl flex items-center justify-center`}>
                    <stat.icon className={`w-6 h-6 ${stat.color}`} />
                  </div>
                </div>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Today's Schedule */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <Clock className="w-5 h-5 text-gray-500" />
              오늘의 일정
            </CardTitle>
            <Link to="/reservations">
              <Button variant="ghost" size="sm" rightIcon={<ArrowRight className="w-4 h-4" />}>
                전체보기
              </Button>
            </Link>
          </CardHeader>
          <CardContent>
            {todaySchedule.length === 0 ? (
              <EmptyState
                icon={<Calendar className="w-6 h-6" />}
                title="오늘 예정된 일정이 없습니다"
                className="py-8"
              />
            ) : (
              <div className="space-y-3">
                {todaySchedule.map((schedule) => (
                  <div
                    key={schedule.reservationId}
                    className="flex items-center gap-4 p-3 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors"
                  >
                    <div className="text-center min-w-[60px]">
                      <p className="text-lg font-bold text-primary-600">
                        {formatTime(schedule.reservationTime)}
                      </p>
                    </div>
                    <div className="w-px h-10 bg-primary-200"></div>
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">{schedule.memberName}</p>
                      {schedule.serviceType && (
                        <p className="text-sm text-gray-500">{schedule.serviceType}</p>
                      )}
                    </div>
                    <Badge variant={schedule.status === 'CONFIRMED' ? 'success' : 'warning'}>
                      {schedule.status === 'CONFIRMED' ? '확정' : '대기'}
                    </Badge>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Recent Activities */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-gray-500" />
              최근 활동
            </CardTitle>
          </CardHeader>
          <CardContent>
            {recentActivities.length === 0 ? (
              <EmptyState
                icon={<FileText className="w-6 h-6" />}
                title="최근 활동이 없습니다"
                className="py-8"
              />
            ) : (
              <div className="space-y-3">
                {recentActivities.map((activity) => {
                  const isVisit = activity.activityType === 'VISIT';
                  return (
                    <div
                      key={activity.activityId}
                      className="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      <div
                        className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${
                          isVisit ? 'bg-green-100' : 'bg-blue-100'
                        }`}
                      >
                        {isVisit ? (
                          <ClipboardCheck className="w-4 h-4 text-green-600" />
                        ) : (
                          <FileText className="w-4 h-4 text-blue-600" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-gray-900">
                          <span className="font-medium">{activity.memberName}</span>님{' '}
                          {isVisit ? '방문' : '메모'}
                        </p>
                        {activity.content && (
                          <p className="text-sm text-gray-500 truncate">{activity.content}</p>
                        )}
                      </div>
                      <p className="text-xs text-gray-400 flex-shrink-0">
                        {formatRelativeTime(activity.activityTime)}
                      </p>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* 고급 통계 차트 섹션 */}
      <div className="mt-8">
        <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
          <BarChart3 className="w-5 h-5" />
          상세 통계
        </h2>

        {chartsLoading ? (
          <div className="flex items-center justify-center h-48">
            <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 gap-6">
            {/* 회원 등록 추이 차트 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Users className="w-4 h-4 text-blue-600" />
                  회원 등록 추이 (7일)
                </CardTitle>
              </CardHeader>
              <CardContent>
                {memberTrend && memberTrend.dataPoints.length > 0 ? (
                  <div>
                    <TrendChart
                      data={memberTrend.dataPoints}
                      color="#3b82f6"
                      gradientId="memberTrendGradient"
                      height={160}
                      valueLabel="명"
                    />
                    <div className="mt-3 text-center">
                      <Badge variant="info">총 {memberTrend.totalNewMembers}명 신규 등록</Badge>
                    </div>
                  </div>
                ) : (
                  <EmptyState
                    icon={<Users className="w-6 h-6" />}
                    title="데이터가 없습니다"
                    className="py-6"
                  />
                )}
              </CardContent>
            </Card>

            {/* 등급별 분포 차트 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <PieChart className="w-4 h-4 text-green-600" />
                  회원 등급 분포
                </CardTitle>
              </CardHeader>
              <CardContent>
                {gradeDistribution && gradeDistribution.totalMembers > 0 ? (
                  <DistributionChart
                    data={Object.entries(gradeDistribution.distribution).map(([grade, count]) => ({
                      name: grade,
                      value: count,
                    }))}
                    height={180}
                    showValues={true}
                  />
                ) : (
                  <EmptyState
                    icon={<PieChart className="w-6 h-6" />}
                    title="데이터가 없습니다"
                    className="py-6"
                  />
                )}
              </CardContent>
            </Card>

            {/* 예약 추이 차트 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Calendar className="w-4 h-4 text-primary-600" />
                  예약 추이 (7일)
                </CardTitle>
              </CardHeader>
              <CardContent>
                {reservationTrend && reservationTrend.dataPoints.length > 0 ? (
                  <div>
                    <TrendChart
                      data={reservationTrend.dataPoints}
                      color="#8b5cf6"
                      gradientId="reservationTrendGradient"
                      height={160}
                      valueLabel="건"
                    />
                    <div className="mt-3 text-center">
                      <Badge variant="success">총 {reservationTrend.totalReservations}건 예약</Badge>
                    </div>
                  </div>
                ) : (
                  <EmptyState
                    icon={<Calendar className="w-6 h-6" />}
                    title="데이터가 없습니다"
                    className="py-6"
                  />
                )}
              </CardContent>
            </Card>

            {/* 메모 통계 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Bookmark className="w-4 h-4 text-amber-600" />
                  메모 통계 (7일)
                </CardTitle>
              </CardHeader>
              <CardContent>
                {memoStats ? (
                  <div>
                    {/* 메모 요약 카드 */}
                    <div className="grid grid-cols-3 gap-3 mb-4">
                      <div className="bg-blue-50 rounded-lg p-3 text-center">
                        <p className="text-2xl font-bold text-blue-700">{memoStats.totalMemos}</p>
                        <p className="text-xs text-blue-600">전체</p>
                      </div>
                      <div className="bg-amber-50 rounded-lg p-3 text-center">
                        <p className="text-2xl font-bold text-amber-700">{memoStats.importantMemos}</p>
                        <p className="text-xs text-amber-600">중요</p>
                      </div>
                      <div className="bg-gray-50 rounded-lg p-3 text-center">
                        <p className="text-2xl font-bold text-gray-700">{memoStats.archivedMemos}</p>
                        <p className="text-xs text-gray-600">보관됨</p>
                      </div>
                    </div>

                    {/* 일별 메모 차트 */}
                    {memoStats.dailyMemos.length > 0 && (
                      <div>
                        <p className="text-xs text-gray-500 mb-2">일별 작성 추이</p>
                        <TrendChart
                          data={memoStats.dailyMemos}
                          color="#f59e0b"
                          gradientId="memoTrendGradient"
                          height={100}
                          valueLabel="건"
                        />
                      </div>
                    )}
                  </div>
                ) : (
                  <EmptyState
                    icon={<FileText className="w-6 h-6" />}
                    title="데이터가 없습니다"
                    className="py-6"
                  />
                )}
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}
