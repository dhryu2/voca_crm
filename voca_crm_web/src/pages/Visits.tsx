import { useEffect, useState, useCallback } from 'react';
import {
  ClipboardCheck,
  Search,
  User,
  X,
  Plus,
  UserPlus,
} from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Badge,
  Input,
  EmptyState,
  Button,
  SlidePanel,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';
import type { Visit, Member, CheckInRequest } from '@/types';

export function VisitsPage() {
  const { currentBusinessPlace } = useAuthStore();
  const [visits, setVisits] = useState<Visit[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // 체크인 관련 상태
  const [isCheckInOpen, setIsCheckInOpen] = useState(false);
  const [members, setMembers] = useState<Member[]>([]);
  const [membersLoading, setMembersLoading] = useState(false);
  const [selectedMemberId, setSelectedMemberId] = useState('');
  const [checkInNote, setCheckInNote] = useState('');
  const [memberSearchQuery, setMemberSearchQuery] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

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

  // 고객 목록 로드
  const loadMembers = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setMembersLoading(true);
    try {
      const response = await apiClient.get<Member[]>(
        `/members/by-business-place/${currentBusinessPlace.id}`
      );
      setMembers(response || []);
    } catch (err) {
      console.error('Failed to load members:', err);
      setMembers([]);
    } finally {
      setMembersLoading(false);
    }
  }, [currentBusinessPlace?.id]);

  // 체크인 패널 열기
  const handleOpenCheckIn = () => {
    setIsCheckInOpen(true);
    setSelectedMemberId('');
    setCheckInNote('');
    setMemberSearchQuery('');
    loadMembers();
  };

  // 체크인 처리
  const handleCheckIn = async () => {
    if (!selectedMemberId) {
      alert('고객을 선택해주세요.');
      return;
    }

    setIsSubmitting(true);
    try {
      const request: CheckInRequest = {
        memberId: selectedMemberId,
      };
      if (checkInNote.trim()) {
        request.note = checkInNote.trim();
      }

      await apiClient.post('/visits/checkin', request);
      setIsCheckInOpen(false);
      loadVisits();
    } catch (err) {
      console.error('Check-in failed:', err);
      alert('체크인 처리 중 오류가 발생했습니다.');
    } finally {
      setIsSubmitting(false);
    }
  };

  // 고객 목록 필터링
  const filteredMembers = members.filter((member) => {
    if (!memberSearchQuery) return true;
    const query = memberSearchQuery.toLowerCase();
    return (
      member.name.toLowerCase().includes(query) ||
      member.phone?.toLowerCase().includes(query) ||
      member.memberNumber?.toLowerCase().includes(query)
    );
  });

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
        <Button leftIcon={<UserPlus className="w-4 h-4" />} onClick={handleOpenCheckIn}>
          체크인
        </Button>
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

      {/* Check-In SlidePanel */}
      <SlidePanel
        isOpen={isCheckInOpen}
        onClose={() => setIsCheckInOpen(false)}
        title="체크인"
        width="md"
      >
        <div className="space-y-6">
          {/* 고객 검색 */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700">
              고객 검색
            </label>
            <Input
              placeholder="이름, 전화번호, 회원번호로 검색..."
              leftIcon={<Search className="w-4 h-4" />}
              value={memberSearchQuery}
              onChange={(e) => setMemberSearchQuery(e.target.value)}
            />
          </div>

          {/* 고객 목록 */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700">
              고객 선택 <span className="text-red-500">*</span>
            </label>
            <div className="border border-gray-200 rounded-lg max-h-64 overflow-y-auto">
              {membersLoading ? (
                <div className="flex items-center justify-center py-8">
                  <div className="w-6 h-6 border-2 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
                </div>
              ) : filteredMembers.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  {memberSearchQuery ? '검색 결과가 없습니다' : '고객이 없습니다'}
                </div>
              ) : (
                <div className="divide-y divide-gray-100">
                  {filteredMembers.map((member) => (
                    <button
                      key={member.id}
                      type="button"
                      className={`w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 transition-colors ${
                        selectedMemberId === member.id ? 'bg-primary-50 border-l-4 border-primary-500' : ''
                      }`}
                      onClick={() => setSelectedMemberId(member.id)}
                    >
                      <div className="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0">
                        <User className="w-4 h-4 text-gray-500" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-medium text-gray-900 truncate">
                          {member.name}
                        </p>
                        <p className="text-sm text-gray-500 truncate">
                          {member.phone || member.memberNumber || ''}
                        </p>
                      </div>
                      {selectedMemberId === member.id && (
                        <div className="w-5 h-5 bg-primary-500 rounded-full flex items-center justify-center">
                          <Plus className="w-3 h-3 text-white rotate-45" />
                        </div>
                      )}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* 메모 입력 */}
          <div className="space-y-2">
            <label className="block text-sm font-medium text-gray-700">
              메모 (선택)
            </label>
            <textarea
              className="w-full px-4 py-3 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
              rows={3}
              placeholder="방문 관련 메모를 입력하세요..."
              value={checkInNote}
              onChange={(e) => setCheckInNote(e.target.value)}
            />
          </div>

          {/* 액션 버튼 */}
          <div className="flex gap-3 pt-4 border-t border-gray-200">
            <Button
              variant="outline"
              className="flex-1"
              onClick={() => setIsCheckInOpen(false)}
            >
              취소
            </Button>
            <Button
              variant="primary"
              className="flex-1"
              leftIcon={<UserPlus className="w-4 h-4" />}
              onClick={handleCheckIn}
              disabled={!selectedMemberId || isSubmitting}
            >
              {isSubmitting ? '처리 중...' : '체크인'}
            </Button>
          </div>
        </div>
      </SlidePanel>
    </div>
  );
}
