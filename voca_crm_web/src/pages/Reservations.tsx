import { useEffect, useState, useCallback } from 'react';
import {
  Calendar,
  Clock,
  Plus,
  ChevronLeft,
  ChevronRight,
  User,
  Check,
  X,
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

export function ReservationsPage() {
  const { currentBusinessPlace } = useAuthStore();
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [selectedReservation, setSelectedReservation] = useState<Reservation | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);

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
    } catch (err) {
      alert('상태 변경 중 오류가 발생했습니다.');
    }
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

      {/* Date Selector */}
      <Card>
        <CardContent className="p-4">
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
            {!isToday && (
              <Button variant="ghost" size="sm" onClick={handleToday}>
                오늘로 이동
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Reservations List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="w-5 h-5 text-gray-500" />
            예약 목록
            <Badge variant="default" className="ml-2">{reservations.length}건</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : reservations.length === 0 ? (
            <EmptyState
              icon={<Calendar className="w-8 h-8" />}
              title="예약이 없습니다"
              description={`${formatDateHeader(selectedDate)}에 등록된 예약이 없습니다`}
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {reservations.map((reservation) => {
                const statusConfig = STATUS_CONFIG[reservation.status];
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

                    {/* Status */}
                    <Badge variant={statusConfig.variant}>
                      {statusConfig.label}
                    </Badge>
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
