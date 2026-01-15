import { useEffect, useState, useCallback, useMemo } from 'react';
import {
  Search,
  Plus,
  Phone,
  Mail,
  FileText,
  Edit,
  Trash2,
  User,
  Download,
  Upload,
  RotateCcw,
} from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  SlidePanel,
  Badge,
  EmptyState,
  DataTable,
  CSVUploader,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatPhoneNumber, formatDate } from '@/lib/utils';
import { useCSVExport } from '@/hooks/useCSVExport';
import type { Member, Memo } from '@/types';
import type { ColumnDef } from '@tanstack/react-table';

interface MemberWithLatestMemo extends Member {
  latestMemo?: Memo;
}

export function CustomersPage() {
  const { currentBusinessPlace, user } = useAuthStore();
  const [members, setMembers] = useState<MemberWithLatestMemo[]>([]);
  const [deletedMembers, setDeletedMembers] = useState<MemberWithLatestMemo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedMember, setSelectedMember] = useState<MemberWithLatestMemo | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isImportOpen, setIsImportOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [activeTab, setActiveTab] = useState<'active' | 'deleted'>('active');

  const { exportToCSV } = useCSVExport<MemberWithLatestMemo>();

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

  const loadDeletedMembers = useCallback(async () => {
    if (!currentBusinessPlace?.id) return;

    setIsLoading(true);
    try {
      const response = await apiClient.get<{ data: MemberWithLatestMemo[] }>(
        `/members/by-business-place/${currentBusinessPlace.id}?deleted=true`
      );
      setDeletedMembers(response.data || []);
    } catch (err) {
      console.error('Failed to load deleted members:', err);
    } finally {
      setIsLoading(false);
    }
  }, [currentBusinessPlace?.id]);

  useEffect(() => {
    if (activeTab === 'active') {
      loadMembers();
    } else {
      loadDeletedMembers();
    }
  }, [activeTab, loadMembers, loadDeletedMembers]);

  const filteredMembers = useMemo(() => {
    const sourceMembers = activeTab === 'active' ? members : deletedMembers;
    if (!searchQuery) return sourceMembers;
    const query = searchQuery.toLowerCase();
    return sourceMembers.filter((member) =>
      member.name.toLowerCase().includes(query) ||
      member.memberNumber.toLowerCase().includes(query) ||
      member.phone?.toLowerCase().includes(query) ||
      member.email?.toLowerCase().includes(query)
    );
  }, [members, deletedMembers, activeTab, searchQuery]);

  const handleViewDetail = useCallback((member: MemberWithLatestMemo) => {
    setSelectedMember(member);
    setIsDetailOpen(true);
  }, []);

  // Column definitions (memoized)
  const columns = useMemo<ColumnDef<MemberWithLatestMemo, unknown>[]>(() => [
    {
      id: 'select',
      header: ({ table }) => (
        <input
          type="checkbox"
          checked={table.getIsAllPageRowsSelected()}
          onChange={table.getToggleAllPageRowsSelectedHandler()}
          className="rounded border-gray-300"
        />
      ),
      cell: ({ row }) => (
        <input
          type="checkbox"
          checked={row.getIsSelected()}
          onChange={row.getToggleSelectedHandler()}
          onClick={(e) => e.stopPropagation()}
          className="rounded border-gray-300"
        />
      ),
      enableSorting: false,
    },
    {
      accessorKey: 'memberNumber',
      header: '번호',
      cell: ({ row }) => (
        <span className="text-gray-500">{row.original.memberNumber}</span>
      ),
    },
    {
      accessorKey: 'name',
      header: '이름',
      cell: ({ row }) => (
        <span className="font-medium text-gray-900">{row.original.name}</span>
      ),
    },
    {
      accessorKey: 'phone',
      header: '연락처',
      cell: ({ row }) => (
        <span className="text-gray-600">
          {row.original.phone ? formatPhoneNumber(row.original.phone) : '-'}
        </span>
      ),
    },
    {
      accessorKey: 'email',
      header: '이메일',
      cell: ({ row }) => (
        <span className="text-gray-600 truncate max-w-[150px] block">
          {row.original.email || '-'}
        </span>
      ),
    },
    {
      accessorKey: 'grade',
      header: '등급',
      cell: ({ row }) =>
        row.original.grade ? (
          <Badge variant="info">{row.original.grade}</Badge>
        ) : (
          <span className="text-gray-400">-</span>
        ),
    },
    {
      accessorKey: 'latestMemo.content',
      header: '최근 메모',
      cell: ({ row }) => (
        <span className="text-gray-500 truncate max-w-[200px] block">
          {row.original.latestMemo?.content || '-'}
        </span>
      ),
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => (
        <Button
          size="sm"
          variant="ghost"
          onClick={(e) => {
            e.stopPropagation();
            handleViewDetail(row.original);
          }}
        >
          상세
        </Button>
      ),
      enableSorting: false,
    },
  ], [handleViewDetail]);

  // Deleted members columns (memoized)
  const deletedColumns = useMemo<ColumnDef<MemberWithLatestMemo, unknown>[]>(() => [
    {
      accessorKey: 'memberNumber',
      header: '번호',
      cell: ({ row }) => (
        <span className="text-gray-500">{row.original.memberNumber}</span>
      ),
    },
    {
      accessorKey: 'name',
      header: '이름',
      cell: ({ row }) => (
        <span className="font-medium text-gray-900">{row.original.name}</span>
      ),
    },
    {
      accessorKey: 'phone',
      header: '연락처',
      cell: ({ row }) => (
        <span className="text-gray-600">
          {row.original.phone ? formatPhoneNumber(row.original.phone) : '-'}
        </span>
      ),
    },
    {
      accessorKey: 'email',
      header: '이메일',
      cell: ({ row }) => (
        <span className="text-gray-600 truncate max-w-[150px] block">
          {row.original.email || '-'}
        </span>
      ),
    },
    {
      accessorKey: 'deletedAt',
      header: '삭제일시',
      cell: ({ row }) => (
        <span className="text-gray-500">
          {row.original.deletedAt ? formatDate(row.original.deletedAt) : '-'}
        </span>
      ),
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => (
        <Button
          size="sm"
          variant="outline"
          onClick={(e) => {
            e.stopPropagation();
            handleRestore(row.original);
          }}
          leftIcon={<RotateCcw className="w-3 h-3" />}
        >
          복원
        </Button>
      ),
    },
  ], []);

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

  const handleRestore = async (member: MemberWithLatestMemo) => {
    if (!confirm(`${member.name} 고객을 복원하시겠습니까?`)) return;

    try {
      await apiClient.post(`/members/${member.id}/restore`);
      loadDeletedMembers();
    } catch (err) {
      alert('복원 중 오류가 발생했습니다.');
    }
  };

  // CSV Export handler
  const handleExport = (selectedRows?: MemberWithLatestMemo[]) => {
    const data = selectedRows?.length ? selectedRows : filteredMembers;
    exportToCSV(data, {
      filename: `고객목록_${new Date().toISOString().split('T')[0]}`,
      headers: {
        memberNumber: '회원번호',
        name: '이름',
        phone: '연락처',
        email: '이메일',
        grade: '등급',
        remark: '비고',
      },
    });
  };

  // CSV Import handler
  const handleImport = async (data: Record<string, string>[]) => {
    if (!currentBusinessPlace?.id || !user?.providerId) {
      alert('사업장 또는 사용자 정보가 없습니다.');
      return;
    }

    // 이름 컬럼 필수 검증
    const invalidRows = data.filter((row) => !row['이름']?.trim());
    if (invalidRows.length > 0) {
      alert(`이름이 없는 행이 ${invalidRows.length}개 있습니다. 모든 행에 이름을 입력해주세요.`);
      return;
    }

    try {
      // 각 행별로 등록
      for (const row of data) {
        await apiClient.post('/members', {
          memberNumber: row['회원번호'] || '',
          name: row['이름'],
          phone: row['연락처'] || '',
          email: row['이메일'] || '',
          grade: row['등급'] || '',
          remark: row['비고'] || '',
          businessPlaceId: currentBusinessPlace.id,
          ownerId: user.providerId,
        });
      }
      alert(`${data.length}명의 고객이 등록되었습니다.`);
      loadMembers();
      setIsImportOpen(false);
    } catch (err) {
      alert('가져오기 중 오류가 발생했습니다.');
      console.error('Import error:', err);
    }
  };

  // Bulk Delete handler
  const handleBulkDelete = async (selectedRows: MemberWithLatestMemo[]) => {
    if (!confirm(`${selectedRows.length}명을 삭제하시겠습니까?`)) return;

    try {
      await Promise.all(
        selectedRows.map((m) => apiClient.delete(`/members/${m.id}/soft`))
      );
      loadMembers();
    } catch (err) {
      alert('삭제 중 오류가 발생했습니다.');
    }
  };

  // Render bulk actions
  const renderBulkActions = (selectedRows: MemberWithLatestMemo[]) => (
    <div className="flex gap-2">
      <Button
        size="sm"
        variant="outline"
        onClick={() => handleExport(selectedRows)}
        leftIcon={<Download className="w-3 h-3" />}
      >
        선택 내보내기 ({selectedRows.length})
      </Button>
      <Button
        size="sm"
        variant="destructive"
        onClick={() => handleBulkDelete(selectedRows)}
        leftIcon={<Trash2 className="w-3 h-3" />}
      >
        선택 삭제 ({selectedRows.length})
      </Button>
    </div>
  );

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
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() => handleExport()}
            leftIcon={<Download className="w-4 h-4" />}
          >
            전체 내보내기
          </Button>
          <Button
            variant="outline"
            onClick={() => setIsImportOpen(true)}
            leftIcon={<Upload className="w-4 h-4" />}
          >
            CSV 가져오기
          </Button>
          <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
            고객 등록
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2">
        <Button
          variant={activeTab === 'active' ? 'primary' : 'outline'}
          onClick={() => setActiveTab('active')}
        >
          활성 고객 ({members.length})
        </Button>
        <Button
          variant={activeTab === 'deleted' ? 'primary' : 'outline'}
          onClick={() => setActiveTab('deleted')}
        >
          삭제된 고객 ({deletedMembers.length})
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

      {/* Members List with DataTable */}
      <Card>
        <CardContent className="p-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredMembers.length === 0 ? (
            <EmptyState
              icon={<User className="w-8 h-8" />}
              title={searchQuery ? '검색 결과가 없습니다' : activeTab === 'active' ? '등록된 고객이 없습니다' : '삭제된 고객이 없습니다'}
              description={searchQuery ? '다른 검색어로 시도해보세요' : activeTab === 'active' ? '새 고객을 등록해보세요' : '삭제된 고객이 없습니다'}
              action={
                !searchQuery && activeTab === 'active' && (
                  <Button onClick={handleCreateNew} leftIcon={<Plus className="w-4 h-4" />}>
                    고객 등록
                  </Button>
                )
              }
              className="py-12"
            />
          ) : activeTab === 'active' ? (
            <DataTable
              data={filteredMembers}
              columns={columns}
              enableRowSelection
              renderBulkActions={renderBulkActions}
              enableFiltering={false}
              enablePagination
              pageSize={20}
              emptyMessage="등록된 고객이 없습니다"
            />
          ) : (
            <DataTable
              data={filteredMembers}
              columns={deletedColumns}
              enableRowSelection={false}
              enableFiltering={false}
              enablePagination
              pageSize={20}
              emptyMessage="삭제된 고객이 없습니다"
            />
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

      {/* CSV Import Panel */}
      <SlidePanel
        isOpen={isImportOpen}
        onClose={() => setIsImportOpen(false)}
        title="CSV 가져오기"
        width="md"
      >
        <div className="space-y-4">
          <p className="text-sm text-gray-600">
            CSV 파일을 업로드하여 고객을 일괄 등록할 수 있습니다.
            <br />
            필수 컬럼: <span className="font-medium">이름</span>
            <br />
            선택 컬럼: 회원번호, 연락처, 이메일, 등급, 비고
          </p>
          <CSVUploader
            onUpload={handleImport}
            expectedHeaders={['이름']}
          />
        </div>
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
