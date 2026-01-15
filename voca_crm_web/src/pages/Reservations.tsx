import { useEffect, useState, useCallback, useRef } from 'react';
import {
  Calendar,
  Clock,
  Plus,
  ChevronLeft,
  ChevronRight,
  User,
  Check,
  X,
  ChevronDown,
  UserX,
} from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Badge,
  SlidePanel,
  EmptyState,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatTime } from '@/lib/utils';
import type { Reservation, ReservationStatus } from '@/types';

const STATUS_CONFIG: Record<ReservationStatus, { label: string; variant: 'default' | 'success' | 'warning' | 'error' | 'info' }> = {
  PENDING: { label: '대기', variant: 'warning' },
  CONFIRMED: { label: '확정', variant: 'success' },
  CANCELLED: { label: '취소', variant: 'error' },
  COMPLETED: { label: '완료', variant: 'default' },
  NO_SHOW: { label: '노쇼', variant: 'error' },
};

type StatusFilter = 'ALL' | ReservationStatus;

const STATUS_FILTER_TABS: { key: StatusFilter; label: string }[] = [
  { key: 'ALL', label: '전체' },
  { key: 'PENDING', label: '대기' },
  { key: 'CONFIRMED', label: '확정' },
  { key: 'COMPLETED', label: '완료' },
  { key: 'CANCELLED', label: '취소' },
  { key: 'NO_SHOW', label: '노쇼' },
];

export function ReservationsPage() {
  const { currentBusinessPlace } = useAuthStore();
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [selectedReservation, setSelectedReservation] = useState<Reservation | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('ALL');
  const [openDropdownId, setOpenDropdownId] = useState<string | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const loadReservations = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    try {
      const dateStr = selectedDate.toISOString().split('T')[0];
      const response = await apiClient.get<Reservation[]>(
        `/reservations/business-place/${currentBusinessPlace.id}/date/${dateStr}`
      );
      // Sort by time
      const sorted = (response || []).sort((a, b) =>
        a.reservationTime.localeCompare(b.reservationTime)
      );
      setReservations(sorted);
    } catch (err) {
      console.error('Failed to load reservations:', err);
      setReservations([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentBusinessPlace?.id, selectedDate]);

  useEffect(() => {
    loadReservations();
  }, [loadReservations]);

  // 드롭다운 외부 클릭 시 닫기
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setOpenDropdownId(null);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // 상태 필터 적용된 예약 목록
  const filteredReservations = reservations.filter((reservation) => {
    if (statusFilter === 'ALL') return true;
    return reservation.status === statusFilter;
  });

  // 날짜 입력 형식 변환 (YYYY-MM-DD)
  const formatDateForInput = (date: Date) => {
    return date.toISOString().split('T')[0];
  };

  // 날짜 입력 핸들러
  const handleDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newDate = new Date(e.target.value);
    if (!isNaN(newDate.getTime())) {
      setSelectedDate(newDate);
    }
  };

  const handlePrevDay = () => {
    setSelectedDate((prev) => {
      const newDate = new Date(prev);
      newDate.setDate(newDate.getDate() - 1);
      return newDate;
    });
  };

  const handleNextDay = () => {
    setSelectedDate((prev) => {
      const newDate = new Date(prev);
      newDate.setDate(newDate.getDate() + 1);
      return newDate;
    });
  };

  const handleToday = () => {
    setSelectedDate(new Date());
  };

  const handleStatusChange = async (reservation: Reservation, newStatus: ReservationStatus) => {
    try {
      await apiClient.patch(`/reservations/${reservation.id}/status`, {
        status: newStatus,
      });
      loadReservations();
      setIsDetailOpen(false);
      setOpenDropdownId(null);
    } catch (err) {
      alert('상태 변경 중 오류가 발생했습니다.');
    }
  };

  // 인라인 상태 변경 (드롭다운)
  const handleInlineStatusChange = async (reservationId: string, newStatus: ReservationStatus) => {
    try {
      await apiClient.patch(`/reservations/${reservationId}/status`, {
        status: newStatus,
      });
      loadReservations();
      setOpenDropdownId(null);
    } catch (err) {
      alert('상태 변경 중 오류가 발생했습니다.');
    }
  };

  // 드롭다운 토글
  const toggleDropdown = (e: React.MouseEvent, reservationId: string) => {
    e.stopPropagation();
    setOpenDropdownId(openDropdownId === reservationId ? null : reservationId);
  };

  const formatDateHeader = (date: Date) => {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const dayOfWeek = days[date.getDay()];
    return `${month}월 ${day}일 (${dayOfWeek})`;
  };

  const isToday = selectedDate.toDateString() === new Date().toDateString();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">예약 관리</h1>
          <p className="text-gray-500 mt-1">
            {currentBusinessPlace?.name || '사업장'}의 예약 현황
          </p>
        </div>
        <Button leftIcon={<Plus className="w-4 h-4" />}>
          예약 등록
        </Button>
      </div>

      {/* Date Selector & Status Filter */}
      <Card>
        <CardContent className="p-4 space-y-4">
          {/* Date Navigation */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={handlePrevDay}>
                <ChevronLeft className="w-4 h-4" />
              </Button>
              <Button variant="outline" size="sm" onClick={handleNextDay}>
                <ChevronRight className="w-4 h-4" />
              </Button>
              <h2 className="text-lg font-semibold text-gray-900 ml-2">
                {formatDateHeader(selectedDate)}
              </h2>
              {isToday && (
                <Badge variant="info">오늘</Badge>
              )}
            </div>
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={formatDateForInput(selectedDate)}
                onChange={handleDateChange}
                className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
              {!isToday && (
                <Button variant="ghost" size="sm" onClick={handleToday}>
                  오늘로 이동
                </Button>
              )}
            </div>
          </div>

          {/* Status Filter Tabs */}
          <div className="flex items-center gap-1 border-b border-gray-200 overflow-x-auto">
            {STATUS_FILTER_TABS.map((tab) => (
              <button
                key={tab.key}
                onClick={() => setStatusFilter(tab.key)}
                className={`px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors border-b-2 -mb-px ${
                  statusFilter === tab.key
                    ? 'border-primary-500 text-primary-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.label}
                {tab.key !== 'ALL' && (
                  <span className="ml-1.5 text-xs text-gray-400">
                    ({reservations.filter(r => r.status === tab.key).length})
                  </span>
                )}
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Reservations List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="w-5 h-5 text-gray-500" />
            예약 목록
            <Badge variant="default" className="ml-2">
              {filteredReservations.length}건
              {statusFilter !== 'ALL' && ` / 전체 ${reservations.length}건`}
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredReservations.length === 0 ? (
            <EmptyState
              icon={<Calendar className="w-8 h-8" />}
              title="예약이 없습니다"
              description={
                statusFilter !== 'ALL'
                  ? `${formatDateHeader(selectedDate)}에 '${STATUS_CONFIG[statusFilter as ReservationStatus]?.label || ''}' 상태의 예약이 없습니다`
                  : `${formatDateHeader(selectedDate)}에 등록된 예약이 없습니다`
              }
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100" ref={dropdownRef}>
              {filteredReservations.map((reservation) => {
                const statusConfig = STATUS_CONFIG[reservation.status];
                const isDropdownOpen = openDropdownId === reservation.id;
                return (
                  <div
                    key={reservation.id}
                    className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors cursor-pointer"
                    onClick={() => {
                      setSelectedReservation(reservation);
                      setIsDetailOpen(true);
                    }}
                  >
                    {/* Time */}
                    <div className="text-center min-w-[80px]">
                      <p className="text-lg font-bold text-primary-600">
                        {formatTime(reservation.reservationTime)}
                      </p>
                      <p className="text-xs text-gray-400">{reservation.durationMinutes}분</p>
                    </div>

                    {/* Divider */}
                    <div className="w-px h-12 bg-gray-200"></div>

                    {/* Info */}
                    <div className="flex-1">
                      <p className="font-medium text-gray-900">
                        {reservation.memberName || '고객'}
                      </p>
                      {reservation.serviceType && (
                        <p className="text-sm text-gray-500">{reservation.serviceType}</p>
                      )}
                      {reservation.notes && (
                        <p className="text-sm text-gray-400 truncate max-w-md">
                          {reservation.notes}
                        </p>
                      )}
                    </div>

                    {/* Status with Dropdown */}
                    <div className="relative">
                      <button
                        onClick={(e) => toggleDropdown(e, reservation.id)}
                        className="flex items-center gap-1 group"
                      >
                        <Badge variant={statusConfig.variant} className="pr-1">
                          {statusConfig.label}
                          <ChevronDown className={`w-3 h-3 ml-1 transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} />
                        </Badge>
                      </button>

                      {/* Status Dropdown Menu */}
                      {isDropdownOpen && (
                        <div className="absolute right-0 top-full mt-1 w-32 bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-10">
                          {reservation.status === 'PENDING' && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleInlineStatusChange(reservation.id, 'CONFIRMED');
                              }}
                              className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center gap-2"
                            >
                              <Check className="w-4 h-4 text-green-500" />
                              확정
                            </button>
                          )}
                          {reservation.status === 'CONFIRMED' && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleInlineStatusChange(reservation.id, 'COMPLETED');
                              }}
                              className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center gap-2"
                            >
                              <Check className="w-4 h-4 text-blue-500" />
                              완료
                            </button>
                          )}
                          {(reservation.status === 'PENDING' || reservation.status === 'CONFIRMED') && (
                            <>
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleInlineStatusChange(reservation.id, 'CANCELLED');
                                }}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center gap-2"
                              >
                                <X className="w-4 h-4 text-red-500" />
                                취소
                              </button>
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleInlineStatusChange(reservation.id, 'NO_SHOW');
                                }}
                                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 flex items-center gap-2"
                              >
                                <UserX className="w-4 h-4 text-gray-500" />
                                노쇼
                              </button>
                            </>
                          )}
                          {(reservation.status === 'CANCELLED' || reservation.status === 'COMPLETED' || reservation.status === 'NO_SHOW') && (
                            <div className="px-3 py-2 text-sm text-gray-400">
                              변경 불가
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Reservation Detail Panel */}
      <SlidePanel
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title="예약 상세"
        width="md"
      >
        {selectedReservation && (
          <div className="space-y-6">
            {/* Time & Status */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-primary-100 rounded-xl flex items-center justify-center">
                  <Clock className="w-6 h-6 text-primary-600" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-gray-900">
                    {formatTime(selectedReservation.reservationTime)}
                  </p>
                  <p className="text-sm text-gray-500">
                    {selectedReservation.durationMinutes}분 소요
                  </p>
                </div>
              </div>
              <Badge variant={STATUS_CONFIG[selectedReservation.status].variant} className="text-base px-3 py-1">
                {STATUS_CONFIG[selectedReservation.status].label}
              </Badge>
            </div>

            {/* Customer Info */}
            <div className="p-4 bg-gray-50 rounded-xl">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center">
                  <User className="w-5 h-5 text-gray-500" />
                </div>
                <div>
                  <p className="font-medium text-gray-900">
                    {selectedReservation.memberName || '고객'}
                  </p>
                  {selectedReservation.serviceType && (
                    <p className="text-sm text-gray-500">{selectedReservation.serviceType}</p>
                  )}
                </div>
              </div>
            </div>

            {/* Notes */}
            {selectedReservation.notes && (
              <div className="space-y-2">
                <h4 className="font-medium text-gray-900">메모</h4>
                <p className="text-gray-600 p-4 bg-gray-50 rounded-lg">
                  {selectedReservation.notes}
                </p>
              </div>
            )}

            {/* Actions */}
            {(selectedReservation.status === 'PENDING' || selectedReservation.status === 'CONFIRMED') && (
              <div className="space-y-3 pt-4 border-t border-gray-200">
                <h4 className="font-medium text-gray-900">상태 변경</h4>
                <div className="flex gap-2">
                  {selectedReservation.status === 'PENDING' && (
                    <Button
                      variant="primary"
                      className="flex-1"
                      leftIcon={<Check className="w-4 h-4" />}
                      onClick={() => handleStatusChange(selectedReservation, 'CONFIRMED')}
                    >
                      확정
                    </Button>
                  )}
                  {selectedReservation.status === 'CONFIRMED' && (
                    <Button
                      variant="primary"
                      className="flex-1"
                      leftIcon={<Check className="w-4 h-4" />}
                      onClick={() => handleStatusChange(selectedReservation, 'COMPLETED')}
                    >
                      완료
                    </Button>
                  )}
                  <Button
                    variant="outline"
                    className="flex-1"
                    leftIcon={<X className="w-4 h-4" />}
                    onClick={() => handleStatusChange(selectedReservation, 'CANCELLED')}
                  >
                    취소
                  </Button>
                </div>
              </div>
            )}
          </div>
        )}
      </SlidePanel>
    </div>
  );
}
