import { useEffect, useState, useCallback } from 'react';
import {
  Search,
  Plus,
  MoreHorizontal,
  Phone,
  Mail,
  FileText,
  Edit,
  Trash2,
  User,
} from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  SlidePanel,
  Badge,
  EmptyState,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatPhoneNumber, formatDate } from '@/lib/utils';
import type { Member, Memo } from '@/types';

interface MemberWithLatestMemo extends Member {
  latestMemo?: Memo;
}

export function CustomersPage() {
  const { currentBusinessPlace, user } = useAuthStore();
  const [members, setMembers] = useState<MemberWithLatestMemo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedMember, setSelectedMember] = useState<MemberWithLatestMemo | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');

  const loadMembers = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    try {
      const response = await apiClient.get<{ data: MemberWithLatestMemo[] }>(
        `/members/by-business-place/${currentBusinessPlace.id}`
      );
      setMembers(response.data || []);
    } catch (err) {
      console.error('Failed to load members:', err);
    } finally {
      setIsLoading(false);
    }
  }, [currentBusinessPlace?.id]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  const filteredMembers = members.filter((member) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      member.name.toLowerCase().includes(query) ||
      member.memberNumber.toLowerCase().includes(query) ||
      member.phone?.toLowerCase().includes(query) ||
      member.email?.toLowerCase().includes(query)
    );
  });

  const handleViewDetail = (member: MemberWithLatestMemo) => {
    setSelectedMember(member);
    setIsDetailOpen(true);
  };

  const handleCreateNew = () => {
    setSelectedMember(null);
    setFormMode('create');
    setIsFormOpen(true);
  };

  const handleEdit = (member: MemberWithLatestMemo) => {
    setSelectedMember(member);
    setFormMode('edit');
    setIsDetailOpen(false);
    setIsFormOpen(true);
  };

  const handleDelete = async (member: MemberWithLatestMemo) => {
    if (!confirm(`${member.name} 고객을 삭제하시겠습니까?`)) return;

    try {
      await apiClient.delete(`/members/${member.id}/soft`);
      loadMembers();
      setIsDetailOpen(false);
    } catch (err) {
      alert('삭제 중 오류가 발생했습니다.');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">고객 관리</h1>
          <p className="text-gray-500 mt-1">
            {currentBusinessPlace?.name || '사업장'}의 고객 목록
          </p>
        </div>
        <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
          고객 등록
        </Button>
      </div>

      {/* Search & Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center gap-4">
            <div className="flex-1 max-w-md">
              <Input
                placeholder="이름, 회원번호, 연락처로 검색..."
                leftIcon={<Search className="w-4 h-4" />}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <Badge variant="default">{filteredMembers.length}명</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Members List */}
      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredMembers.length === 0 ? (
            <EmptyState
              icon={<User className="w-8 h-8" />}
              title={searchQuery ? '검색 결과가 없습니다' : '등록된 고객이 없습니다'}
              description={searchQuery ? '다른 검색어로 시도해보세요' : '새 고객을 등록해보세요'}
              action={
                !searchQuery && (
                  <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
                    고객 등록
                  </Button>
                )
              }
              className="py-12"
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {/* Table Header */}
              <div className="grid grid-cols-12 gap-4 px-6 py-3 bg-gray-50 text-sm font-medium text-gray-500">
                <div className="col-span-1">번호</div>
                <div className="col-span-2">이름</div>
                <div className="col-span-2">연락처</div>
                <div className="col-span-2">이메일</div>
                <div className="col-span-1">등급</div>
                <div className="col-span-3">최근 메모</div>
                <div className="col-span-1"></div>
              </div>

              {/* Table Body */}
              {filteredMembers.map((member) => (
                <div
                  key={member.id}
                  className="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-gray-50 transition-colors cursor-pointer"
                  onClick={() => handleViewDetail(member)}
                >
                  <div className="col-span-1 text-sm text-gray-500">
                    {member.memberNumber}
                  </div>
                  <div className="col-span-2">
                    <p className="font-medium text-gray-900">{member.name}</p>
                  </div>
                  <div className="col-span-2 text-sm text-gray-600">
                    {member.phone ? formatPhoneNumber(member.phone) : '-'}
                  </div>
                  <div className="col-span-2 text-sm text-gray-600 truncate">
                    {member.email || '-'}
                  </div>
                  <div className="col-span-1">
                    {member.grade && (
                      <Badge variant="info">{member.grade}</Badge>
                    )}
                  </div>
                  <div className="col-span-3 text-sm text-gray-500 truncate">
                    {member.latestMemo?.content || '-'}
                  </div>
                  <div className="col-span-1 text-right">
                    <button
                      className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleViewDetail(member);
                      }}
                    >
                      <MoreHorizontal className="w-4 h-4 text-gray-400" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Member Detail Panel */}
      <SlidePanel
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title="고객 상세"
        width="lg"
      >
        {selectedMember && (
          <div className="space-y-6">
            {/* Basic Info */}
            <div className="flex items-start gap-4">
              <div className="w-16 h-16 bg-primary-100 rounded-full flex items-center justify-center">
                <span className="text-2xl font-bold text-primary-700">
                  {selectedMember.name.charAt(0)}
                </span>
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-gray-900">
                  {selectedMember.name}
                </h3>
                <p className="text-gray-500">#{selectedMember.memberNumber}</p>
                {selectedMember.grade && (
                  <Badge variant="info" className="mt-2">{selectedMember.grade}</Badge>
                )}
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleEdit(selectedMember)}
                  leftIcon={<Edit className="w-4 h-4" />}
                >
                  수정
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => handleDelete(selectedMember)}
                  leftIcon={<Trash2 className="w-4 h-4" />}
                >
                  삭제
                </Button>
              </div>
            </div>

            {/* Contact Info */}
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">연락처</h4>
              <div className="space-y-2">
                {selectedMember.phone && (
                  <div className="flex items-center gap-3 text-gray-600">
                    <Phone className="w-4 h-4" />
                    <span>{formatPhoneNumber(selectedMember.phone)}</span>
                  </div>
                )}
                {selectedMember.email && (
                  <div className="flex items-center gap-3 text-gray-600">
                    <Mail className="w-4 h-4" />
                    <span>{selectedMember.email}</span>
                  </div>
                )}
              </div>
            </div>

            {/* Remark */}
            {selectedMember.remark && (
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">비고</h4>
                <p className="text-gray-600 text-sm">{selectedMember.remark}</p>
              </div>
            )}

            {/* Latest Memo */}
            {selectedMember.latestMemo && (
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900 flex items-center gap-2">
                  <FileText className="w-4 h-4" />
                  최근 메모
                </h4>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-gray-700">{selectedMember.latestMemo.content}</p>
                  <p className="text-xs text-gray-400 mt-2">
                    {formatDate(selectedMember.latestMemo.createdAt)}
                  </p>
                </div>
              </div>
            )}

            {/* Metadata */}
            <div className="pt-4 border-t border-gray-200 text-sm text-gray-500">
              <p>등록일: {formatDate(selectedMember.createdAt)}</p>
              <p>수정일: {formatDate(selectedMember.updatedAt)}</p>
            </div>
          </div>
        )}
      </SlidePanel>

      {/* Member Form Panel */}
      <SlidePanel
        isOpen={isFormOpen}
        onClose={() => setIsFormOpen(false)}
        title={formMode === 'create' ? '고객 등록' : '고객 수정'}
        width="md"
      >
        <MemberForm
          member={formMode === 'edit' ? selectedMember : null}
          businessPlaceId={currentBusinessPlace?.id || ''}
          userId={user?.providerId || ''}
          onSuccess={() => {
            setIsFormOpen(false);
            loadMembers();
          }}
          onCancel={() => setIsFormOpen(false)}
        />
      </SlidePanel>
    </div>
  );
}

// Member Form Component
interface MemberFormProps {
  member: Member | null;
  businessPlaceId: string;
  userId: string;
  onSuccess: () => void;
  onCancel: () => void;
}

function MemberForm({ member, businessPlaceId, userId, onSuccess, onCancel }: MemberFormProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    memberNumber: member?.memberNumber || '',
    name: member?.name || '',
    phone: member?.phone || '',
    email: member?.email || '',
    grade: member?.grade || '',
    remark: member?.remark || '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      if (member) {
        // Update
        await apiClient.put(`/members/${member.id}`, {
          ...formData,
          businessPlaceId,
        });
      } else {
        // Create
        await apiClient.post('/members', {
          ...formData,
          businessPlaceId,
          ownerId: userId,
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

      <Input
        label="회원번호"
        placeholder="001"
        value={formData.memberNumber}
        onChange={(e) => setFormData({ ...formData, memberNumber: e.target.value })}
        required
      />

      <Input
        label="이름"
        placeholder="홍길동"
        value={formData.name}
        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
        required
      />

      <Input
        label="연락처"
        placeholder="010-1234-5678"
        value={formData.phone}
        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
      />

      <Input
        label="이메일"
        type="email"
        placeholder="example@email.com"
        value={formData.email}
        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
      />

      <Input
        label="등급"
        placeholder="VIP, 일반 등"
        value={formData.grade}
        onChange={(e) => setFormData({ ...formData, grade: e.target.value })}
      />

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">비고</label>
        <textarea
          className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2 min-h-[100px]"
          placeholder="특이사항을 입력하세요"
          value={formData.remark}
          onChange={(e) => setFormData({ ...formData, remark: e.target.value })}
        />
      </div>

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="flex-1" isLoading={isLoading}>
          {member ? '수정' : '등록'}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          취소
        </Button>
      </div>
    </form>
  );
}
