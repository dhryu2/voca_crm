import { useState } from 'react';
import {
  User,
  Building2,
  Bell,
  Shield,
  LogOut,
  Mail,
  Phone,
  Edit,
  Plus,
  Trash2,
} from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Input,
  Badge,
  SlidePanel,
} from '@/components/ui';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';
import { formatPhoneNumber, cn } from '@/lib/utils';
import type { BusinessPlace } from '@/types';

type SettingsTab = 'profile' | 'business' | 'notifications' | 'account';

export function SettingsPage() {
  const { user, businessPlaces, currentBusinessPlace, setCurrentBusinessPlace, logout } = useAuthStore();
  const [activeTab, setActiveTab] = useState<SettingsTab>('profile');
  const [isEditProfileOpen, setIsEditProfileOpen] = useState(false);
  const [isBusinessFormOpen, setIsBusinessFormOpen] = useState(false);
  const [editingBusinessPlace, setEditingBusinessPlace] = useState<BusinessPlace | null>(null);

  const tabs: { id: SettingsTab; label: string; icon: React.ReactNode }[] = [
    { id: 'profile', label: '프로필', icon: <User className="w-5 h-5" /> },
    { id: 'business', label: '사업장 관리', icon: <Building2 className="w-5 h-5" /> },
    { id: 'notifications', label: '알림 설정', icon: <Bell className="w-5 h-5" /> },
    { id: 'account', label: '계정 설정', icon: <Shield className="w-5 h-5" /> },
  ];

  const handleLogout = () => {
    if (confirm('로그아웃 하시겠습니까?')) {
      logout();
    }
  };

  const handleAddBusinessPlace = () => {
    setEditingBusinessPlace(null);
    setIsBusinessFormOpen(true);
  };

  const handleEditBusinessPlace = (bp: BusinessPlace) => {
    setEditingBusinessPlace(bp);
    setIsBusinessFormOpen(true);
  };

  const handleDeleteBusinessPlace = async (bp: BusinessPlace) => {
    if (!confirm(`${bp.name} 사업장을 삭제하시겠습니까?`)) return;

    try {
      await apiClient.delete(`/business-places/${bp.id}/remove`);
      // Reload or update local state
      window.location.reload();
    } catch (err) {
      alert('삭제 중 오류가 발생했습니다.');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">설정</h1>
        <p className="text-gray-500 mt-1">계정 및 앱 설정을 관리합니다</p>
      </div>

      <div className="flex gap-6">
        {/* Sidebar */}
        <div className="w-64 flex-shrink-0">
          <Card>
            <CardContent className="p-2">
              <nav className="space-y-1">
                {tabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={cn(
                      'w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors',
                      activeTab === tab.id
                        ? 'bg-primary-50 text-primary-700'
                        : 'text-gray-600 hover:bg-gray-50'
                    )}
                  >
                    {tab.icon}
                    <span className="font-medium">{tab.label}</span>
                  </button>
                ))}
              </nav>
            </CardContent>
          </Card>
        </div>

        {/* Content */}
        <div className="flex-1">
          {activeTab === 'profile' && (
            <Card>
              <CardHeader>
                <CardTitle>프로필 정보</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Avatar & Basic Info */}
                <div className="flex items-center gap-6">
                  <div className="w-20 h-20 bg-primary-100 rounded-full flex items-center justify-center">
                    <span className="text-3xl font-bold text-primary-700">
                      {user?.name?.charAt(0) || 'U'}
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-gray-900">{user?.name || '사용자'}</h3>
                    <p className="text-gray-500">{user?.email || ''}</p>
                    <Button
                      variant="outline"
                      size="sm"
                      className="mt-2"
                      onClick={() => setIsEditProfileOpen(true)}
                      leftIcon={<Edit className="w-4 h-4" />}
                    >
                      프로필 수정
                    </Button>
                  </div>
                </div>

                {/* Contact Info */}
                <div className="border-t border-gray-200 pt-6 space-y-4">
                  <h4 className="font-medium text-gray-900">연락처 정보</h4>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                      <Mail className="w-5 h-5 text-gray-400" />
                      <div>
                        <p className="text-sm text-gray-500">이메일</p>
                        <p className="font-medium text-gray-900">{user?.email || '-'}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                      <Phone className="w-5 h-5 text-gray-400" />
                      <div>
                        <p className="text-sm text-gray-500">연락처</p>
                        <p className="font-medium text-gray-900">
                          {user?.phone ? formatPhoneNumber(user.phone) : '-'}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Provider Info */}
                <div className="border-t border-gray-200 pt-6 space-y-4">
                  <h4 className="font-medium text-gray-900">연동된 계정</h4>
                  <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                    <div className="w-10 h-10 bg-white rounded-full flex items-center justify-center shadow-sm">
                      {user?.provider === 'google' && (
                        <svg className="w-5 h-5" viewBox="0 0 24 24">
                          <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                          <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                          <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                          <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                        </svg>
                      )}
                      {user?.provider === 'kakao' && (
                        <svg className="w-5 h-5" viewBox="0 0 24 24">
                          <path fill="#3C1E1E" d="M12 3c5.8 0 10.5 3.664 10.5 8.185 0 4.52-4.7 8.184-10.5 8.184a13.5 13.5 0 0 1-1.727-.11l-4.408 2.883c-.501.265-.678.236-.472-.413l.892-3.678c-2.88-1.46-4.785-3.99-4.785-6.866C1.5 6.665 6.2 3 12 3z" />
                        </svg>
                      )}
                      {user?.provider === 'apple' && (
                        <svg className="w-5 h-5" viewBox="0 0 24 24">
                          <path fill="currentColor" d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
                        </svg>
                      )}
                    </div>
                    <div>
                      <p className="font-medium text-gray-900 capitalize">{user?.provider || 'Social'}</p>
                      <p className="text-sm text-gray-500">{user?.providerId || ''}</p>
                    </div>
                    <Badge variant="success" className="ml-auto">연동됨</Badge>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {activeTab === 'business' && (
            <Card>
              <CardHeader className="flex flex-row items-center justify-between">
                <CardTitle>사업장 관리</CardTitle>
                <Button
                  size="sm"
                  onClick={handleAddBusinessPlace}
                  leftIcon={<Plus className="w-4 h-4" />}
                >
                  사업장 추가
                </Button>
              </CardHeader>
              <CardContent className="space-y-4">
                {businessPlaces.length === 0 ? (
                  <div className="text-center py-8">
                    <Building2 className="w-12 h-12 text-gray-300 mx-auto mb-4" />
                    <p className="text-gray-500 mb-4">등록된 사업장이 없습니다</p>
                    <Button onClick={handleAddBusinessPlace} leftIcon={<Plus className="w-4 h-4" />}>
                      사업장 추가
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {businessPlaces.map((bp) => (
                      <div
                        key={bp.id}
                        className={cn(
                          'flex items-center gap-4 p-4 rounded-lg border-2 transition-colors',
                          currentBusinessPlace?.id === bp.id
                            ? 'border-primary-500 bg-primary-50'
                            : 'border-gray-200 hover:border-gray-300'
                        )}
                      >
                        <div className="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                          <Building2 className="w-6 h-6 text-gray-500" />
                        </div>
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-gray-900">{bp.name}</p>
                            {currentBusinessPlace?.id === bp.id && (
                              <Badge variant="success">현재 선택됨</Badge>
                            )}
                          </div>
                          <p className="text-sm text-gray-500">{bp.address || '주소 미등록'}</p>
                        </div>
                        <div className="flex items-center gap-2">
                          {currentBusinessPlace?.id !== bp.id && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => setCurrentBusinessPlace(bp)}
                            >
                              선택
                            </Button>
                          )}
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleEditBusinessPlace(bp)}
                          >
                            <Edit className="w-4 h-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleDeleteBusinessPlace(bp)}
                            className="text-red-500 hover:text-red-600 hover:bg-red-50"
                          >
                            <Trash2 className="w-4 h-4" />
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {activeTab === 'notifications' && (
            <Card>
              <CardHeader>
                <CardTitle>알림 설정</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <NotificationToggle
                  label="예약 알림"
                  description="새 예약이 등록되면 알림을 받습니다"
                  defaultChecked={true}
                />
                <NotificationToggle
                  label="방문 알림"
                  description="고객이 체크인하면 알림을 받습니다"
                  defaultChecked={true}
                />
                <NotificationToggle
                  label="메모 알림"
                  description="새 메모가 작성되면 알림을 받습니다"
                  defaultChecked={false}
                />
                <NotificationToggle
                  label="마케팅 알림"
                  description="프로모션 및 이벤트 정보를 받습니다"
                  defaultChecked={false}
                />
              </CardContent>
            </Card>
          )}

          {activeTab === 'account' && (
            <div className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle>보안</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                    <div>
                      <p className="font-medium text-gray-900">비밀번호 변경</p>
                      <p className="text-sm text-gray-500">소셜 로그인 사용 중</p>
                    </div>
                    <Badge variant="info">소셜 로그인</Badge>
                  </div>
                  <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                    <div>
                      <p className="font-medium text-gray-900">2단계 인증</p>
                      <p className="text-sm text-gray-500">추가 보안을 위해 2단계 인증을 설정합니다</p>
                    </div>
                    <Button variant="outline" size="sm">설정</Button>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle className="text-red-600">위험 영역</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between p-4 border border-red-200 rounded-lg">
                    <div>
                      <p className="font-medium text-gray-900">로그아웃</p>
                      <p className="text-sm text-gray-500">현재 기기에서 로그아웃합니다</p>
                    </div>
                    <Button
                      variant="outline"
                      onClick={handleLogout}
                      leftIcon={<LogOut className="w-4 h-4" />}
                    >
                      로그아웃
                    </Button>
                  </div>
                  <div className="flex items-center justify-between p-4 border border-red-200 rounded-lg">
                    <div>
                      <p className="font-medium text-red-600">계정 삭제</p>
                      <p className="text-sm text-gray-500">모든 데이터가 영구적으로 삭제됩니다</p>
                    </div>
                    <Button variant="destructive" size="sm">
                      계정 삭제
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
          )}
        </div>
      </div>

      {/* Edit Profile Panel */}
      <SlidePanel
        isOpen={isEditProfileOpen}
        onClose={() => setIsEditProfileOpen(false)}
        title="프로필 수정"
        width="md"
      >
        <ProfileEditForm
          user={user}
          onSuccess={() => {
            setIsEditProfileOpen(false);
            window.location.reload();
          }}
          onCancel={() => setIsEditProfileOpen(false)}
        />
      </SlidePanel>

      {/* Business Place Form Panel */}
      <SlidePanel
        isOpen={isBusinessFormOpen}
        onClose={() => setIsBusinessFormOpen(false)}
        title={editingBusinessPlace ? '사업장 수정' : '사업장 추가'}
        width="md"
      >
        <BusinessPlaceForm
          businessPlace={editingBusinessPlace}
          onSuccess={() => {
            setIsBusinessFormOpen(false);
            window.location.reload();
          }}
          onCancel={() => setIsBusinessFormOpen(false)}
        />
      </SlidePanel>
    </div>
  );
}

// Notification Toggle Component
interface NotificationToggleProps {
  label: string;
  description: string;
  defaultChecked: boolean;
}

function NotificationToggle({ label, description, defaultChecked }: NotificationToggleProps) {
  const [checked, setChecked] = useState(defaultChecked);

  return (
    <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
      <div>
        <p className="font-medium text-gray-900">{label}</p>
        <p className="text-sm text-gray-500">{description}</p>
      </div>
      <button
        onClick={() => setChecked(!checked)}
        className={cn(
          'relative w-12 h-7 rounded-full transition-colors',
          checked ? 'bg-primary-600' : 'bg-gray-300'
        )}
      >
        <span
          className={cn(
            'absolute top-1 w-5 h-5 bg-white rounded-full shadow transition-transform',
            checked ? 'translate-x-6' : 'translate-x-1'
          )}
        />
      </button>
    </div>
  );
}

// Profile Edit Form
interface ProfileEditFormProps {
  user: any;
  onSuccess: () => void;
  onCancel: () => void;
}

function ProfileEditForm({ user, onSuccess, onCancel }: ProfileEditFormProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: user?.name || '',
    phone: user?.phone || '',
    email: user?.email || '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      await apiClient.put('/users/me', formData);
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
        label="이름"
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
        value={formData.email}
        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
      />

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="flex-1" isLoading={isLoading}>
          저장
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          취소
        </Button>
      </div>
    </form>
  );
}

// Business Place Form
interface BusinessPlaceFormProps {
  businessPlace: BusinessPlace | null;
  onSuccess: () => void;
  onCancel: () => void;
}

function BusinessPlaceForm({ businessPlace, onSuccess, onCancel }: BusinessPlaceFormProps) {
  const { user } = useAuthStore();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: businessPlace?.name || '',
    address: businessPlace?.address || '',
    phone: businessPlace?.phone || '',
    description: businessPlace?.description || '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      if (businessPlace) {
        await apiClient.put(`/business-places/${businessPlace.id}`, formData);
      } else {
        await apiClient.post('/business-places', {
          ...formData,
          ownerId: user?.providerId,
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
        label="사업장 이름"
        placeholder="OO헤어샵"
        value={formData.name}
        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
        required
      />

      <Input
        label="주소"
        placeholder="서울시 강남구..."
        value={formData.address}
        onChange={(e) => setFormData({ ...formData, address: e.target.value })}
      />

      <Input
        label="연락처"
        placeholder="02-1234-5678"
        value={formData.phone}
        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
      />

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">설명</label>
        <textarea
          className="flex w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2 min-h-[100px]"
          placeholder="사업장 설명을 입력하세요"
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
        />
      </div>

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="flex-1" isLoading={isLoading}>
          {businessPlace ? '수정' : '추가'}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          취소
        </Button>
      </div>
    </form>
  );
}
