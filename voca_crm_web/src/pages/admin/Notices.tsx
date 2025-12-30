import { useEffect, useState, useCallback } from 'react';
import {
  Megaphone,
  Plus,
  Edit,
  Trash2,
  BarChart2,
  Calendar,
  AlertCircle,
} from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Badge,
  Input,
  SlidePanel,
  EmptyState,
} from '@/components/ui';
import { apiClient } from '@/lib/api';
import { formatDate, cn } from '@/lib/utils';
import type { Notice, NoticeDisplayType, NoticeStats } from '@/types';

const DISPLAY_TYPE_CONFIG: Record<NoticeDisplayType, { label: string; color: string }> = {
  POPUP: { label: '팝업', color: 'bg-purple-100 text-purple-700' },
  BANNER: { label: '배너', color: 'bg-blue-100 text-blue-700' },
  LIST: { label: '리스트', color: 'bg-gray-100 text-gray-700' },
};

export function NoticesPage() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedNotice, setSelectedNotice] = useState<Notice | null>(null);
  const [noticeStats, setNoticeStats] = useState<NoticeStats | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');

  const loadNotices = useCallback(async () => {
    setIsLoading(true);
    try {
      const response = await apiClient.get<{ data: Notice[] }>('/admin/notices');
      setNotices(response.data || []);
    } catch (err) {
      console.error('Failed to load notices:', err);
      setNotices([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadNotices();
  }, [loadNotices]);

  const handleViewDetail = async (notice: Notice) => {
    setSelectedNotice(notice);
    setIsDetailOpen(true);

    // Load stats
    try {
      const stats = await apiClient.get<NoticeStats>(`/admin/notices/${notice.id}/stats`);
      setNoticeStats(stats);
    } catch {
      setNoticeStats(null);
    }
  };

  const handleCreateNew = () => {
    setSelectedNotice(null);
    setFormMode('create');
    setIsFormOpen(true);
  };

  const handleEdit = (notice: Notice) => {
    setSelectedNotice(notice);
    setFormMode('edit');
    setIsDetailOpen(false);
    setIsFormOpen(true);
  };

  const handleDelete = async (notice: Notice) => {
    if (!confirm(`"${notice.title}" 공지를 삭제하시겠습니까?`)) return;

    try {
      await apiClient.delete(`/admin/notices/${notice.id}`);
      loadNotices();
      setIsDetailOpen(false);
    } catch (err) {
      alert('삭제 중 오류가 발생했습니다.');
    }
  };

  const getStatusBadge = (notice: Notice) => {
    const now = new Date();
    const startDate = new Date(notice.startDate);
    const endDate = notice.endDate ? new Date(notice.endDate) : null;

    if (!notice.isActive) {
      return <Badge variant="default">비활성</Badge>;
    }
    if (startDate > now) {
      return <Badge variant="warning">예정됨</Badge>;
    }
    if (endDate && endDate < now) {
      return <Badge variant="default">종료됨</Badge>;
    }
    return <Badge variant="success">활성</Badge>;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">공지사항 관리</h1>
          <p className="text-gray-500 mt-1">시스템 공지사항을 생성하고 관리합니다</p>
        </div>
        <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
          공지 작성
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-3xl font-bold text-gray-900">{notices.length}</p>
            <p className="text-sm text-gray-500">전체 공지</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-3xl font-bold text-green-600">
              {notices.filter((n) => n.isActive).length}
            </p>
            <p className="text-sm text-gray-500">활성 공지</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-3xl font-bold text-purple-600">
              {notices.filter((n) => n.displayType === 'POPUP').length}
            </p>
            <p className="text-sm text-gray-500">팝업 공지</p>
          </CardContent>
        </Card>
      </div>

      {/* Notices List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Megaphone className="w-5 h-5 text-blue-500" />
            공지사항 목록
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
            </div>
          ) : notices.length === 0 ? (
            <EmptyState
              icon={<Megaphone className="w-8 h-8" />}
              title="등록된 공지사항이 없습니다"
              description="새 공지사항을 작성해보세요"
              action={
                <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
                  공지 작성
                </Button>
              }
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {notices.map((notice) => {
                const displayConfig = DISPLAY_TYPE_CONFIG[notice.displayType];
                return (
                  <div
                    key={notice.id}
                    className="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition-colors cursor-pointer"
                    onClick={() => handleViewDetail(notice)}
                  >
                    {/* Display Type */}
                    <span className={cn('px-2 py-1 rounded text-xs font-medium', displayConfig.color)}>
                      {displayConfig.label}
                    </span>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="font-medium text-gray-900 truncate">{notice.title}</p>
                        {notice.priority > 0 && (
                          <Badge variant="warning">우선순위 {notice.priority}</Badge>
                        )}
                      </div>
                      <p className="text-sm text-gray-500 truncate">{notice.content}</p>
                    </div>

                    {/* Date */}
                    <div className="text-right text-sm text-gray-500">
                      <p>{formatDate(notice.startDate)}</p>
                      {notice.endDate && (
                        <p className="text-xs">~ {formatDate(notice.endDate)}</p>
                      )}
                    </div>

                    {/* Status */}
                    {getStatusBadge(notice)}

                    {/* Actions */}
                    <div className="flex items-center gap-1">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEdit(notice);
                        }}
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors"
                        title="수정"
                      >
                        <Edit className="w-4 h-4 text-gray-500" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDelete(notice);
                        }}
                        className="p-1.5 rounded hover:bg-red-50 transition-colors"
                        title="삭제"
                      >
                        <Trash2 className="w-4 h-4 text-red-500" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Notice Detail Panel */}
      <SlidePanel
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title="공지사항 상세"
        width="lg"
      >
        {selectedNotice && (
          <div className="space-y-6">
            {/* Header */}
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <span className={cn('px-2 py-1 rounded text-xs font-medium', DISPLAY_TYPE_CONFIG[selectedNotice.displayType].color)}>
                    {DISPLAY_TYPE_CONFIG[selectedNotice.displayType].label}
                  </span>
                  {getStatusBadge(selectedNotice)}
                </div>
                <h3 className="text-xl font-bold text-gray-900">{selectedNotice.title}</h3>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleEdit(selectedNotice)}
                  leftIcon={<Edit className="w-4 h-4" />}
                >
                  수정
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => handleDelete(selectedNotice)}
                  leftIcon={<Trash2 className="w-4 h-4" />}
                >
                  삭제
                </Button>
              </div>
            </div>

            {/* Content */}
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">내용</h4>
              <div className="p-4 bg-gray-50 rounded-lg whitespace-pre-wrap">
                {selectedNotice.content}
              </div>
            </div>

            {/* Schedule */}
            <div className="grid grid-cols-2 gap-4">
              <div className="p-4 bg-blue-50 rounded-lg">
                <div className="flex items-center gap-2 mb-1">
                  <Calendar className="w-4 h-4 text-blue-600" />
                  <span className="text-sm font-medium text-blue-700">시작일</span>
                </div>
                <p className="text-blue-900">{formatDate(selectedNotice.startDate)}</p>
              </div>
              <div className="p-4 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-2 mb-1">
                  <Calendar className="w-4 h-4 text-gray-500" />
                  <span className="text-sm font-medium text-gray-700">종료일</span>
                </div>
                <p className="text-gray-900">
                  {selectedNotice.endDate ? formatDate(selectedNotice.endDate) : '무기한'}
                </p>
              </div>
            </div>

            {/* Stats */}
            {noticeStats && (
              <div className="p-4 bg-purple-50 rounded-lg">
                <div className="flex items-center gap-2 mb-3">
                  <BarChart2 className="w-4 h-4 text-purple-600" />
                  <span className="text-sm font-medium text-purple-700">통계</span>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-2xl font-bold text-purple-900">{noticeStats.viewCount}</p>
                    <p className="text-sm text-purple-700">조회수</p>
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-purple-900">{noticeStats.hideCount}</p>
                    <p className="text-sm text-purple-700">다시 보지 않기</p>
                  </div>
                </div>
              </div>
            )}

            {/* Metadata */}
            <div className="pt-4 border-t border-gray-200 text-sm text-gray-500">
              <p>작성일: {formatDate(selectedNotice.createdAt)}</p>
              <p>수정일: {formatDate(selectedNotice.updatedAt)}</p>
              <p>우선순위: {selectedNotice.priority}</p>
            </div>
          </div>
        )}
      </SlidePanel>

      {/* Notice Form Panel */}
      <SlidePanel
        isOpen={isFormOpen}
        onClose={() => setIsFormOpen(false)}
        title={formMode === 'create' ? '공지사항 작성' : '공지사항 수정'}
        width="lg"
      >
        <NoticeForm
          notice={formMode === 'edit' ? selectedNotice : null}
          onSuccess={() => {
            setIsFormOpen(false);
            loadNotices();
          }}
          onCancel={() => setIsFormOpen(false)}
        />
      </SlidePanel>
    </div>
  );
}

// Notice Form Component
interface NoticeFormProps {
  notice: Notice | null;
  onSuccess: () => void;
  onCancel: () => void;
}

function NoticeForm({ notice, onSuccess, onCancel }: NoticeFormProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    title: notice?.title || '',
    content: notice?.content || '',
    displayType: notice?.displayType || 'LIST' as NoticeDisplayType,
    priority: notice?.priority || 0,
    isActive: notice?.isActive ?? true,
    startDate: notice?.startDate?.split('T')[0] || new Date().toISOString().split('T')[0],
    endDate: notice?.endDate?.split('T')[0] || '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    if (!formData.title.trim()) {
      setError('제목을 입력해주세요.');
      setIsLoading(false);
      return;
    }

    if (!formData.content.trim()) {
      setError('내용을 입력해주세요.');
      setIsLoading(false);
      return;
    }

    try {
      const payload = {
        ...formData,
        endDate: formData.endDate || null,
      };

      if (notice) {
        await apiClient.put(`/admin/notices/${notice.id}`, payload);
      } else {
        await apiClient.post('/admin/notices', payload);
      }
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : '저장 중 오류가 발생했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm flex items-center gap-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      <Input
        label="제목"
        placeholder="공지사항 제목"
        value={formData.title}
        onChange={(e) => setFormData({ ...formData, title: e.target.value })}
        required
      />

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">내용</label>
        <textarea
          className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 min-h-[150px]"
          placeholder="공지사항 내용을 입력하세요"
          value={formData.content}
          onChange={(e) => setFormData({ ...formData, content: e.target.value })}
          required
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">노출 형태</label>
          <select
            className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
            value={formData.displayType}
            onChange={(e) => setFormData({ ...formData, displayType: e.target.value as NoticeDisplayType })}
          >
            <option value="POPUP">팝업</option>
            <option value="BANNER">배너</option>
            <option value="LIST">리스트</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">우선순위</label>
          <input
            type="number"
            className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
            value={formData.priority}
            onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value) || 0 })}
            min="0"
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">시작일</label>
          <input
            type="date"
            className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
            value={formData.startDate}
            onChange={(e) => setFormData({ ...formData, startDate: e.target.value })}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">종료일 (선택)</label>
          <input
            type="date"
            className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
            value={formData.endDate}
            onChange={(e) => setFormData({ ...formData, endDate: e.target.value })}
          />
        </div>
      </div>

      <div className="flex items-center gap-2">
        <input
          type="checkbox"
          id="isActive"
          className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          checked={formData.isActive}
          onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
        />
        <label htmlFor="isActive" className="text-sm text-gray-700">
          활성화
        </label>
      </div>

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="flex-1" isLoading={isLoading}>
          {notice ? '수정' : '작성'}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          취소
        </Button>
      </div>
    </form>
  );
}
