import { useEffect, useState, useCallback } from 'react';
import {
  AlertTriangle,
  Search,
  Filter,
  CheckCircle,
  XCircle,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Eye,
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
import type { ErrorLog, ErrorSeverity, PaginatedResponse } from '@/types';

const SEVERITY_CONFIG: Record<ErrorSeverity, { label: string; color: string; bgColor: string }> = {
  CRITICAL: { label: 'Critical', color: 'text-red-700', bgColor: 'bg-red-100' },
  HIGH: { label: 'High', color: 'text-orange-700', bgColor: 'bg-orange-100' },
  MEDIUM: { label: 'Medium', color: 'text-yellow-700', bgColor: 'bg-yellow-100' },
  LOW: { label: 'Low', color: 'text-blue-700', bgColor: 'bg-blue-100' },
};

export function ErrorLogsPage() {
  const [logs, setLogs] = useState<ErrorLog[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [totalPages, setTotalPages] = useState(0);
  const [currentPage, setCurrentPage] = useState(0);
  const [selectedLog, setSelectedLog] = useState<ErrorLog | null>(null);
  const [isDetailOpen, setIsDetailOpen] = useState(false);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [severityFilter, setSeverityFilter] = useState<ErrorSeverity | ''>('');
  const [resolvedFilter, setResolvedFilter] = useState<'all' | 'resolved' | 'unresolved'>('all');
  const [dateRange, setDateRange] = useState({
    startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    endDate: new Date().toISOString().split('T')[0],
  });

  const loadLogs = useCallback(async () => {
    setIsLoading(true);
    try {
      const params: Record<string, string> = {
        startDate: dateRange.startDate,
        endDate: dateRange.endDate,
        page: currentPage.toString(),
        size: '20',
      };

      if (severityFilter) {
        params.severity = severityFilter;
      }
      if (resolvedFilter !== 'all') {
        params.resolved = (resolvedFilter === 'resolved').toString();
      }

      const response = await apiClient.get<PaginatedResponse<ErrorLog>>(
        '/error-logs/search',
        params
      );

      setLogs(response.content || []);
      setTotalPages(response.totalPages || 0);
    } catch (err) {
      console.error('Failed to load error logs:', err);
      setLogs([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentPage, severityFilter, resolvedFilter, dateRange]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const handleResolve = async (log: ErrorLog) => {
    try {
      await apiClient.patch(`/error-logs/${log.id}/resolve`);
      loadLogs();
      if (selectedLog?.id === log.id) {
        setSelectedLog({ ...selectedLog, resolved: true, resolvedAt: new Date().toISOString() });
      }
    } catch (err) {
      alert('상태 변경 중 오류가 발생했습니다.');
    }
  };

  const handleUnresolve = async (log: ErrorLog) => {
    try {
      await apiClient.patch(`/error-logs/${log.id}/unresolve`);
      loadLogs();
      if (selectedLog?.id === log.id) {
        setSelectedLog({ ...selectedLog, resolved: false, resolvedAt: undefined });
      }
    } catch (err) {
      alert('상태 변경 중 오류가 발생했습니다.');
    }
  };

  const filteredLogs = logs.filter((log) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      log.message?.toLowerCase().includes(query) ||
      log.errorCode?.toLowerCase().includes(query) ||
      log.username?.toLowerCase().includes(query) ||
      log.requestPath?.toLowerCase().includes(query)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">오류 로그</h1>
          <p className="text-gray-500 mt-1">시스템 오류 모니터링 및 관리</p>
        </div>
        <Button
          variant="outline"
          onClick={loadLogs}
          leftIcon={<RefreshCw className="w-4 h-4" />}
        >
          새로고침
        </Button>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-wrap items-center gap-4">
            <div className="flex-1 min-w-[200px] max-w-md">
              <Input
                placeholder="메시지, 오류 코드, 사용자, 경로 검색..."
                leftIcon={<Search className="w-4 h-4" />}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            <div className="flex items-center gap-2">
              <Filter className="w-4 h-4 text-gray-400" />
              <select
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                value={severityFilter}
                onChange={(e) => setSeverityFilter(e.target.value as ErrorSeverity | '')}
              >
                <option value="">전체 심각도</option>
                <option value="CRITICAL">Critical</option>
                <option value="HIGH">High</option>
                <option value="MEDIUM">Medium</option>
                <option value="LOW">Low</option>
              </select>

              <select
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                value={resolvedFilter}
                onChange={(e) => setResolvedFilter(e.target.value as 'all' | 'resolved' | 'unresolved')}
              >
                <option value="all">전체 상태</option>
                <option value="unresolved">미해결</option>
                <option value="resolved">해결됨</option>
              </select>
            </div>

            <div className="flex items-center gap-2">
              <input
                type="date"
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                value={dateRange.startDate}
                onChange={(e) => setDateRange({ ...dateRange, startDate: e.target.value })}
              />
              <span className="text-gray-400">~</span>
              <input
                type="date"
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                value={dateRange.endDate}
                onChange={(e) => setDateRange({ ...dateRange, endDate: e.target.value })}
              />
            </div>

            <Badge variant="default">{filteredLogs.length}건</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Error Logs Table */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-red-500" />
            오류 로그 목록
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-4 border-red-200 border-t-red-600 rounded-full animate-spin"></div>
            </div>
          ) : filteredLogs.length === 0 ? (
            <EmptyState
              icon={<AlertTriangle className="w-8 h-8" />}
              title="오류 로그가 없습니다"
              description="선택한 기간과 조건에 해당하는 오류가 없습니다"
              className="py-12"
            />
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">시간</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">심각도</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">메시지</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">사용자</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">경로</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">상태</th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">작업</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {filteredLogs.map((log) => {
                      const severityConfig = SEVERITY_CONFIG[log.severity];
                      return (
                        <tr
                          key={log.id}
                          className="hover:bg-gray-50 transition-colors cursor-pointer"
                          onClick={() => {
                            setSelectedLog(log);
                            setIsDetailOpen(true);
                          }}
                        >
                          <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">
                            {formatDate(log.createdAt)}
                          </td>
                          <td className="px-4 py-3">
                            <span className={cn('px-2 py-1 rounded-full text-xs font-medium', severityConfig.bgColor, severityConfig.color)}>
                              {severityConfig.label}
                            </span>
                          </td>
                          <td className="px-4 py-3 text-sm text-gray-900 max-w-xs truncate">
                            {log.message}
                          </td>
                          <td className="px-4 py-3 text-sm text-gray-600">
                            {log.username || '-'}
                          </td>
                          <td className="px-4 py-3 text-sm text-gray-500 font-mono max-w-xs truncate">
                            {log.requestPath || '-'}
                          </td>
                          <td className="px-4 py-3">
                            {log.resolved ? (
                              <Badge variant="success">해결됨</Badge>
                            ) : (
                              <Badge variant="error">미해결</Badge>
                            )}
                          </td>
                          <td className="px-4 py-3">
                            <div className="flex items-center gap-1">
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setSelectedLog(log);
                                  setIsDetailOpen(true);
                                }}
                                className="p-1.5 rounded hover:bg-gray-100 transition-colors"
                                title="상세 보기"
                              >
                                <Eye className="w-4 h-4 text-gray-500" />
                              </button>
                              {log.resolved ? (
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleUnresolve(log);
                                  }}
                                  className="p-1.5 rounded hover:bg-orange-50 transition-colors"
                                  title="미해결로 변경"
                                >
                                  <XCircle className="w-4 h-4 text-orange-500" />
                                </button>
                              ) : (
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleResolve(log);
                                  }}
                                  className="p-1.5 rounded hover:bg-green-50 transition-colors"
                                  title="해결됨으로 변경"
                                >
                                  <CheckCircle className="w-4 h-4 text-green-500" />
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-4 py-3 border-t border-gray-200">
                  <p className="text-sm text-gray-500">
                    {currentPage + 1} / {totalPages} 페이지
                  </p>
                  <div className="flex items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setCurrentPage((p) => Math.max(0, p - 1))}
                      disabled={currentPage === 0}
                    >
                      <ChevronLeft className="w-4 h-4" />
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setCurrentPage((p) => Math.min(totalPages - 1, p + 1))}
                      disabled={currentPage >= totalPages - 1}
                    >
                      <ChevronRight className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>

      {/* Error Detail Panel */}
      <SlidePanel
        isOpen={isDetailOpen}
        onClose={() => setIsDetailOpen(false)}
        title="오류 상세"
        width="lg"
      >
        {selectedLog && (
          <div className="space-y-6">
            {/* Header */}
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <span className={cn('px-2 py-1 rounded-full text-xs font-medium', SEVERITY_CONFIG[selectedLog.severity].bgColor, SEVERITY_CONFIG[selectedLog.severity].color)}>
                    {SEVERITY_CONFIG[selectedLog.severity].label}
                  </span>
                  {selectedLog.resolved ? (
                    <Badge variant="success">해결됨</Badge>
                  ) : (
                    <Badge variant="error">미해결</Badge>
                  )}
                </div>
                <p className="text-sm text-gray-500">{formatDate(selectedLog.createdAt)}</p>
              </div>
              {selectedLog.resolved ? (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleUnresolve(selectedLog)}
                  leftIcon={<XCircle className="w-4 h-4" />}
                >
                  미해결로 변경
                </Button>
              ) : (
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => handleResolve(selectedLog)}
                  leftIcon={<CheckCircle className="w-4 h-4" />}
                >
                  해결됨으로 변경
                </Button>
              )}
            </div>

            {/* Message */}
            <div>
              <h4 className="text-sm font-medium text-gray-500 mb-2">오류 메시지</h4>
              <p className="text-gray-900 p-4 bg-red-50 rounded-lg border border-red-100">
                {selectedLog.message}
              </p>
            </div>

            {/* Details Grid */}
            <div className="grid grid-cols-2 gap-4">
              {selectedLog.errorCode && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-1">오류 코드</h4>
                  <p className="text-gray-900 font-mono">{selectedLog.errorCode}</p>
                </div>
              )}
              {selectedLog.username && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-1">사용자</h4>
                  <p className="text-gray-900">{selectedLog.username}</p>
                </div>
              )}
              {selectedLog.requestMethod && selectedLog.requestPath && (
                <div className="col-span-2">
                  <h4 className="text-sm font-medium text-gray-500 mb-1">요청</h4>
                  <p className="text-gray-900 font-mono">
                    {selectedLog.requestMethod} {selectedLog.requestPath}
                  </p>
                </div>
              )}
              {selectedLog.ipAddress && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-1">IP 주소</h4>
                  <p className="text-gray-900 font-mono">{selectedLog.ipAddress}</p>
                </div>
              )}
              {selectedLog.businessPlaceName && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-1">사업장</h4>
                  <p className="text-gray-900">{selectedLog.businessPlaceName}</p>
                </div>
              )}
            </div>

            {/* Stack Trace */}
            {selectedLog.stackTrace && (
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">스택 트레이스</h4>
                <pre className="text-xs text-gray-700 p-4 bg-gray-900 text-gray-100 rounded-lg overflow-x-auto whitespace-pre-wrap font-mono">
                  {selectedLog.stackTrace}
                </pre>
              </div>
            )}

            {/* User Agent */}
            {selectedLog.userAgent && (
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">User Agent</h4>
                <p className="text-sm text-gray-600 p-3 bg-gray-50 rounded-lg break-all">
                  {selectedLog.userAgent}
                </p>
              </div>
            )}

            {/* Resolution Info */}
            {selectedLog.resolved && selectedLog.resolvedAt && (
              <div className="p-4 bg-green-50 rounded-lg border border-green-100">
                <h4 className="text-sm font-medium text-green-800 mb-1">해결 정보</h4>
                <p className="text-sm text-green-700">
                  {formatDate(selectedLog.resolvedAt)}에 해결됨
                  {selectedLog.resolvedBy && ` (${selectedLog.resolvedBy})`}
                </p>
              </div>
            )}
          </div>
        )}
      </SlidePanel>
    </div>
  );
}
