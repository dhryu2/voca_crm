import { useEffect, useState, useCallback } from 'react';
import {
  Search,
  ChevronLeft,
  ChevronRight,
  Building2,
  X,
  MapPin,
  Phone,
  Calendar,
  Users,
  UserCircle,
  Mail,
} from 'lucide-react';
import { Card, CardContent, Button, Input } from '@/components/ui';
import { apiClient } from '@/lib/api';
import { cn, formatDate } from '@/lib/utils';
import type { AdminBusinessPlace, PaginatedResponse } from '@/types';

export function BusinessPlaceManagementPage() {
  const [businessPlaces, setBusinessPlaces] = useState<AdminBusinessPlace[]>([]);
  const [totalElements, setTotalElements] = useState(0);
  const [currentPage, setCurrentPage] = useState(0);
  const [pageSize] = useState(20);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');

  const [selectedPlace, setSelectedPlace] = useState<AdminBusinessPlace | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);

  const loadBusinessPlaces = useCallback(async () => {
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      params.append('page', currentPage.toString());
      params.append('size', pageSize.toString());
      if (search) params.append('search', search);

      const response = await apiClient.get<PaginatedResponse<AdminBusinessPlace>>(
        `/admin/business-places?${params.toString()}`
      );
      setBusinessPlaces(response.content || []);
      setTotalElements(response.totalElements || 0);
    } catch (err) {
      console.error('Failed to load business places:', err);
      setBusinessPlaces([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentPage, pageSize, search]);

  useEffect(() => {
    loadBusinessPlaces();
  }, [loadBusinessPlaces]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setCurrentPage(0);
    loadBusinessPlaces();
  };

  const totalPages = Math.ceil(totalElements / pageSize);

  const openPlaceDetail = (place: AdminBusinessPlace) => {
    setSelectedPlace(place);
    setIsDetailOpen(true);
  };

  const closePlaceDetail = () => {
    setIsDetailOpen(false);
    setSelectedPlace(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">사업장 관리</h1>
        <p className="text-gray-500 mt-1">등록된 사업장을 조회합니다</p>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <form onSubmit={handleSearch} className="flex flex-wrap gap-4">
            <div className="flex-1 min-w-[200px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <Input
                  type="text"
                  placeholder="사업장명, 주소 검색"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>
            <Button type="submit" className="bg-green-600 hover:bg-green-700">검색</Button>
          </form>
        </CardContent>
      </Card>

      {/* Business Places Table */}
      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center h-64">
              <div className="w-8 h-8 border-4 border-green-200 border-t-green-600 rounded-full animate-spin"></div>
            </div>
          ) : businessPlaces.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-gray-500">
              <Building2 className="w-12 h-12 mb-2" />
              <p>사업장이 없습니다</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      사업장
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      대표자
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      회원/직원
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      등록일
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {businessPlaces.map((place) => (
                    <tr
                      key={place.id}
                      className="hover:bg-gray-50 cursor-pointer"
                      onClick={() => openPlaceDetail(place)}
                    >
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                            <Building2 className="w-5 h-5 text-green-600" />
                          </div>
                          <div>
                            <p className="text-sm font-medium text-gray-900">{place.name}</p>
                            {place.address && (
                              <p className="text-xs text-gray-500 truncate max-w-[200px]">
                                {place.address}
                              </p>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm">
                          <p className="text-gray-900">{place.ownerName}</p>
                          {place.ownerEmail && (
                            <p className="text-gray-500 text-xs">{place.ownerEmail}</p>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <div className="flex items-center gap-3">
                          <span className="text-gray-900">{place.memberCount}명</span>
                          <span className="text-gray-400">/</span>
                          <span className="text-gray-500">{place.staffCount}명</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {formatDate(place.createdAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between px-6 py-3 border-t border-gray-200">
              <p className="text-sm text-gray-500">
                총 {totalElements.toLocaleString()}개 중 {currentPage * pageSize + 1}-
                {Math.min((currentPage + 1) * pageSize, totalElements)}개 표시
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(Math.max(0, currentPage - 1))}
                  disabled={currentPage === 0}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <span className="text-sm text-gray-600">
                  {currentPage + 1} / {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage(Math.min(totalPages - 1, currentPage + 1))}
                  disabled={currentPage >= totalPages - 1}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Business Place Detail Slide Panel */}
      <div
        className={cn(
          'fixed inset-y-0 right-0 w-full max-w-md bg-white shadow-2xl z-50 transform transition-transform duration-300',
          isDetailOpen ? 'translate-x-0' : 'translate-x-full'
        )}
      >
        {selectedPlace && (
          <div className="h-full flex flex-col">
            {/* Panel Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">사업장 상세</h2>
              <button
                onClick={closePlaceDetail}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Panel Content */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              {/* Business Place Info */}
              <div className="text-center">
                <div className="w-20 h-20 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
                  <Building2 className="w-10 h-10 text-green-600" />
                </div>
                <h3 className="text-xl font-bold text-gray-900">{selectedPlace.name}</h3>
              </div>

              {/* Contact & Location */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">연락처 및 위치</h4>
                <div className="space-y-2">
                  {selectedPlace.address && (
                    <div className="flex items-start gap-3 text-sm">
                      <MapPin className="w-4 h-4 text-gray-400 mt-0.5" />
                      <span>{selectedPlace.address}</span>
                    </div>
                  )}
                  {selectedPlace.phone && (
                    <div className="flex items-center gap-3 text-sm">
                      <Phone className="w-4 h-4 text-gray-400" />
                      <span>{selectedPlace.phone}</span>
                    </div>
                  )}
                  {!selectedPlace.address && !selectedPlace.phone && (
                    <p className="text-sm text-gray-400">등록된 연락처 없음</p>
                  )}
                </div>
              </div>

              {/* Owner Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">대표자 정보</h4>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                      <UserCircle className="w-6 h-6 text-blue-600" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{selectedPlace.ownerName}</p>
                      {selectedPlace.ownerEmail && (
                        <div className="flex items-center gap-1 text-sm text-gray-500">
                          <Mail className="w-3 h-3" />
                          <span>{selectedPlace.ownerEmail}</span>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              {/* Stats */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">운영 현황</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2 text-gray-500 mb-1">
                      <Users className="w-4 h-4" />
                      <span className="text-xs">회원 수</span>
                    </div>
                    <p className="text-xl font-bold text-gray-900">
                      {selectedPlace.memberCount}명
                    </p>
                  </div>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2 text-gray-500 mb-1">
                      <UserCircle className="w-4 h-4" />
                      <span className="text-xs">직원 수</span>
                    </div>
                    <p className="text-xl font-bold text-gray-900">
                      {selectedPlace.staffCount}명
                    </p>
                  </div>
                </div>
              </div>

              {/* Date Info */}
              <div className="space-y-3">
                <h4 className="font-medium text-gray-900">등록 정보</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex items-center gap-3">
                    <Calendar className="w-4 h-4 text-gray-400" />
                    <span className="text-gray-500">등록일:</span>
                    <span>{formatDate(selectedPlace.createdAt)}</span>
                  </div>
                </div>
              </div>

              {/* Description */}
              {selectedPlace.description && (
                <div className="space-y-3">
                  <h4 className="font-medium text-gray-900">설명</h4>
                  <p className="text-sm text-gray-600">{selectedPlace.description}</p>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Overlay */}
      {isDetailOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40"
          onClick={closePlaceDetail}
        />
      )}
    </div>
  );
}
