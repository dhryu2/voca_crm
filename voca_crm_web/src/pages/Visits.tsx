import { useEffect, useState, useCallback } from 'react';
import {
  ClipboardCheck,
  Search,
  User,
  X,
} from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Badge,
  Input,
  EmptyState,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';
import type { Visit } from '@/types';

export function VisitsPage() {
  const { currentBusinessPlace } = useAuthStore();
  const [visits, setVisits] = useState<Visit[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  const loadVisits = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    try {
      const response = await apiClient.get<Visit[]>(
        `/visits/today/${currentBusinessPlace.id}`
      );
      // Sort by time (newest first)
      const sorted = (response || []).sort((a, b) =>
        new Date(b.visitTime).getTime() - new Date(a.visitTime).getTime()
      );
      setVisits(sorted);
    } catch (err) {
      console.error('Failed to load visits:', err);
      setVisits([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentBusinessPlace?.id]);

  useEffect(() => {
    loadVisits();
  }, [loadVisits]);

  const handleCancelVisit = async (visit: Visit) => {
    if (!confirm(`${visit.memberName || '고객'}님의 방문 기록을 취소하시겠습니까?`)) return;

    try {
      await apiClient.delete(`/visits/${visit.id}?businessPlaceId=${currentBusinessPlace?.id}`);
      loadVisits();
    } catch (err) {
      alert('방문 취소 중 오류가 발생했습니다.');
    }
  };

  const filteredVisits = visits.filter((visit) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      visit.memberName?.toLowerCase().includes(query) ||
      visit.note?.toLowerCase().includes(query)
    );
  });

  const formatVisitTime = (time: string) => {
    const date = new Date(time);
    return date.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">방문 관리</h1>
          <p className="text-gray-500 mt-1">오늘의 방문(체크인) 기록</p>
        </div>
      </div>

      {/* Search */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center gap-4">
            <div className="flex-1 max-w-md">
              <Input
                placeholder="고객명으로 검색..."
                leftIcon={<Search className="w-4 h-4" />}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <Badge variant="success">{filteredVisits.length}명 방문</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Visits List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ClipboardCheck className="w-5 h-5 text-gray-500" />
            오늘 방문 기록
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredVisits.length === 0 ? (
            <EmptyState
              icon={<ClipboardCheck className="w-8 h-8" />}
              title={searchQuery ? '검색 결과가 없습니다' : '오늘 방문 기록이 없습니다'}
              description={searchQuery ? '다른 검색어로 시도해보세요' : '고객이 체크인하면 여기에 표시됩니다'}
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {filteredVisits.map((visit) => (
                <div
                  key={visit.id}
                  className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors"
                >
                  {/* Time */}
                  <div className="text-center min-w-[60px]">
                    <p className="text-lg font-bold text-green-600">
                      {formatVisitTime(visit.visitTime)}
                    </p>
                  </div>

                  {/* Divider */}
                  <div className="w-px h-10 bg-gray-200"></div>

                  {/* Avatar */}
                  <div className="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0">
                    <User className="w-5 h-5 text-green-600" />
                  </div>

                  {/* Info */}
                  <div className="flex-1">
                    <p className="font-medium text-gray-900">
                      {visit.memberName || '고객'}
                    </p>
                    {visit.note && (
                      <p className="text-sm text-gray-500 truncate max-w-md">
                        {visit.note}
                      </p>
                    )}
                  </div>

                  {/* Time Ago */}
                  <p className="text-sm text-gray-400">
                    {formatRelativeTime(visit.visitTime)}
                  </p>

                  {/* Cancel Button */}
                  <button
                    onClick={() => handleCancelVisit(visit)}
                    className="p-2 rounded-lg hover:bg-red-50 transition-colors text-gray-400 hover:text-red-500"
                    title="방문 취소"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Summary */}
      {visits.length > 0 && (
        <div className="grid grid-cols-3 gap-4">
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-3xl font-bold text-gray-900">{visits.length}</p>
              <p className="text-sm text-gray-500">총 방문</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-3xl font-bold text-gray-900">
                {visits.filter(v => {
                  const hour = new Date(v.visitTime).getHours();
                  return hour < 12;
                }).length}
              </p>
              <p className="text-sm text-gray-500">오전 방문</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-3xl font-bold text-gray-900">
                {visits.filter(v => {
                  const hour = new Date(v.visitTime).getHours();
                  return hour >= 12;
                }).length}
              </p>
              <p className="text-sm text-gray-500">오후 방문</p>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
