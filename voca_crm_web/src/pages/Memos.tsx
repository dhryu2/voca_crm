import { useEffect, useState, useCallback } from 'react';
import {
  FileText,
  Search,
  Plus,
  Edit2,
  Trash2,
  User,
  Calendar,
  Filter,
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
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatDate, formatRelativeTime, cn } from '@/lib/utils';
import type { Memo, Member } from '@/types';

interface MemoWithMember extends Memo {
  member?: Member;
}

type FilterType = 'all' | 'today' | 'week';

export function MemosPage() {
  const { currentBusinessPlace } = useAuthStore();
  const [memos, setMemos] = useState<MemoWithMember[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<FilterType>('all');
  const [selectedMemo, setSelectedMemo] = useState<MemoWithMember | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');

  const loadMemos = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    try {
      const response = await apiClient.get<MemoWithMember[]>(
        `/memos/by-business-place/${currentBusinessPlace.id}`
      );
      // Sort by date (newest first)
      const sorted = (response || []).sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
      setMemos(sorted);
    } catch (err) {
      console.error('Failed to load memos:', err);
      setMemos([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentBusinessPlace?.id]);

  useEffect(() => {
    loadMemos();
  }, [loadMemos]);

  const handleViewDetail = (memo: MemoWithMember) => {
    setSelectedMemo(memo);
    setIsDetailOpen(true);
  };

  const handleCreateNew = () => {
    setSelectedMemo(null);
    setFormMode('create');
    setIsFormOpen(true);
  };

  const handleEdit = (memo: MemoWithMember) => {
    setSelectedMemo(memo);
    setFormMode('edit');
    setIsDetailOpen(false);
    setIsFormOpen(true);
  };

  const handleDelete = async (memo: MemoWithMember) => {
    if (!confirm('이 메모를 삭제하시겠습니까?')) return;

    try {
      await apiClient.delete(`/memos/${memo.id}`);
      loadMemos();
      setIsDetailOpen(false);
    } catch (err) {
      alert('삭제 중 오류가 발생했습니다.');
    }
  };

  const filteredMemos = memos.filter((memo) => {
    // Apply text search
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      const matchesSearch =
        memo.content?.toLowerCase().includes(query) ||
        memo.memberName?.toLowerCase().includes(query);
      if (!matchesSearch) return false;
    }

    // Apply date filter
    if (filterType !== 'all') {
      const memoDate = new Date(memo.createdAt);
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

      if (filterType === 'today') {
        const memoDay = new Date(memoDate.getFullYear(), memoDate.getMonth(), memoDate.getDate());
        if (memoDay.getTime() !== today.getTime()) return false;
      } else if (filterType === 'week') {
        const weekAgo = new Date(today);
        weekAgo.setDate(weekAgo.getDate() - 7);
        if (memoDate < weekAgo) return false;
      }
    }

    return true;
  });

  const filterOptions: { value: FilterType; label: string }[] = [
    { value: 'all', label: '전체' },
    { value: 'today', label: '오늘' },
    { value: 'week', label: '최근 7일' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">메모 관리</h1>
          <p className="text-gray-500 mt-1">고객 상담 및 메모 기록</p>
        </div>
        <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
          메모 작성
        </Button>
      </div>

      {/* Search & Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center gap-4">
            <div className="flex-1 max-w-md">
              <Input
                placeholder="내용 또는 고객명으로 검색..."
                leftIcon={<Search className="w-4 h-4" />}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <div className="flex items-center gap-2">
              <Filter className="w-4 h-4 text-gray-400" />
              {filterOptions.map((option) => (
                <button
                  key={option.value}
                  onClick={() => setFilterType(option.value)}
                  className={cn(
                    'px-3 py-1.5 rounded-lg text-sm font-medium transition-colors',
                    filterType === option.value
                      ? 'bg-primary-100 text-primary-700'
                      : 'text-gray-500 hover:bg-gray-100'
                  )}
                >
                  {option.label}
                </button>
              ))}
            </div>
            <Badge variant="default">{filteredMemos.length}건</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Memos List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="w-5 h-5 text-gray-500" />
            메모 목록
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredMemos.length === 0 ? (
            <EmptyState
              icon={<FileText className="w-8 h-8" />}
              title={searchQuery || filterType !== 'all' ? '검색 결과가 없습니다' : '작성된 메모가 없습니다'}
              description={
                searchQuery || filterType !== 'all'
                  ? '다른 검색어나 필터로 시도해보세요'
                  : '새 메모를 작성해보세요'
              }
              action={
                !searchQuery && filterType === 'all' && (
                  <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
                    메모 작성
                  </Button>
                )
              }
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {filteredMemos.map((memo) => (
                <div
                  key={memo.id}
                  className="flex items-start gap-4 px-6 py-4 hover:bg-gray-50 transition-colors cursor-pointer"
                  onClick={() => handleViewDetail(memo)}
                >
                  {/* Avatar */}
                  <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center flex-shrink-0">
                    <User className="w-5 h-5 text-primary-600" />
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <p className="font-medium text-gray-900">
                        {memo.memberName || '고객'}
                      </p>
                      <span className="text-gray-300">·</span>
                      <p className="text-sm text-gray-400">
                        {formatRelativeTime(memo.createdAt)}
                      </p>
                    </div>
                    <p className="text-gray-600 line-clamp-2">{memo.content}</p>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleEdit(memo);
                      }}
                      className="p-2 rounded-lg hover:bg-gray-100 transition-colors text-gray-400 hover:text-gray-600"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDelete(memo);
                      }}
                      className="p-2 rounded-lg hover:bg-red-50 transition-colors text-gray-400 hover:text-red-500"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Memo Detail Panel */}
      <SlidePanel
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title="메모 상세"
        width="md"
      >
        {selectedMemo && (
          <div className="space-y-6">
            {/* Header */}
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center">
                  <User className="w-6 h-6 text-primary-600" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">
                    {selectedMemo.memberName || '고객'}
                  </p>
                  <p className="text-sm text-gray-500">
                    {formatDate(selectedMemo.createdAt)}
                  </p>
                </div>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleEdit(selectedMemo)}
                  leftIcon={<Edit2 className="w-4 h-4" />}
                >
                  수정
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => handleDelete(selectedMemo)}
                  leftIcon={<Trash2 className="w-4 h-4" />}
                >
                  삭제
                </Button>
              </div>
            </div>

            {/* Content */}
            <div className="p-4 bg-gray-50 rounded-xl">
              <p className="text-gray-700 whitespace-pre-wrap">{selectedMemo.content}</p>
            </div>

            {/* Metadata */}
            <div className="space-y-2 text-sm text-gray-500">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                <span>작성일: {formatDate(selectedMemo.createdAt)}</span>
              </div>
              {selectedMemo.updatedAt !== selectedMemo.createdAt && (
                <div className="flex items-center gap-2">
                  <Edit2 className="w-4 h-4" />
                  <span>수정일: {formatDate(selectedMemo.updatedAt)}</span>
                </div>
              )}
            </div>
          </div>
        )}
      </SlidePanel>

      {/* Memo Form Panel */}
      <SlidePanel
        isOpen={isFormOpen}
        onClose={() => setIsFormOpen(false)}
        title={formMode === 'create' ? '메모 작성' : '메모 수정'}
        width="md"
      >
        <MemoForm
          memo={formMode === 'edit' ? selectedMemo : null}
          businessPlaceId={currentBusinessPlace?.id || ''}
          onSuccess={() => {
            setIsFormOpen(false);
            loadMemos();
          }}
          onCancel={() => setIsFormOpen(false)}
        />
      </SlidePanel>
    </div>
  );
}

// Memo Form Component
interface MemoFormProps {
  memo: MemoWithMember | null;
  businessPlaceId: string;
  onSuccess: () => void;
  onCancel: () => void;
}

function MemoForm({ memo, businessPlaceId, onSuccess, onCancel }: MemoFormProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [formData, setFormData] = useState({
    memberId: memo?.memberId || '',
    content: memo?.content || '',
  });

  useEffect(() => {
    loadMembers();
  }, [businessPlaceId]);

  const loadMembers = async () => {
    if (!businessPlaceId) return;

    try {
      const response = await apiClient.get<{ data: Member[] }>(
        `/members/by-business-place/${businessPlaceId}`
      );
      setMembers(response.data || []);
    } catch (err) {
      console.error('Failed to load members:', err);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    if (!formData.memberId) {
      setError('고객을 선택해주세요.');
      setIsLoading(false);
      return;
    }

    if (!formData.content.trim()) {
      setError('메모 내용을 입력해주세요.');
      setIsLoading(false);
      return;
    }

    try {
      if (memo) {
        // Update
        await apiClient.put(`/memos/${memo.id}`, {
          content: formData.content,
        });
      } else {
        // Create
        await apiClient.post('/memos', {
          memberId: formData.memberId,
          content: formData.content,
          businessPlaceId,
        });
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
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
          {error}
        </div>
      )}

      {!memo && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">고객 선택</label>
          <select
            className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2"
            value={formData.memberId}
            onChange={(e) => setFormData({ ...formData, memberId: e.target.value })}
            required
          >
            <option value="">고객을 선택하세요</option>
            {members.map((member) => (
              <option key={member.id} value={member.id}>
                {member.name} ({member.memberNumber})
              </option>
            ))}
          </select>
        </div>
      )}

      {memo && (
        <div className="p-4 bg-gray-50 rounded-lg">
          <p className="text-sm text-gray-500">고객</p>
          <p className="font-medium text-gray-900">{memo.memberName || '고객'}</p>
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">메모 내용</label>
        <textarea
          className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2 min-h-[200px]"
          placeholder="메모 내용을 입력하세요"
          value={formData.content}
          onChange={(e) => setFormData({ ...formData, content: e.target.value })}
          required
        />
      </div>

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="flex-1" isLoading={isLoading}>
          {memo ? '수정' : '저장'}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          취소
        </Button>
      </div>
    </form>
  );
}
