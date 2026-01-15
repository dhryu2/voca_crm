// User & Auth Types
export interface User {
  providerId: string;
  provider?: string;
  name: string;
  email?: string;
  phone?: string;
  role: 'USER' | 'ADMIN';
  isSystemAdmin?: boolean;
  defaultBusinessPlaceId?: string;
  createdAt: string;
}

export interface Tokens {
  accessToken: string;
  refreshToken: string;
}

export interface LoginResult {
  accessToken: string;
  refreshToken: string;
  user: User;
}

// Business Place Types
export interface BusinessPlace {
  id: string;
  name: string;
  address?: string;
  phone?: string;
  description?: string;
  ownerId: string;
  createdAt: string;
}

export interface BusinessPlaceWithRole extends BusinessPlace {
  role: 'OWNER' | 'MANAGER' | 'STAFF';
}

// Member Types
export interface Member {
  id: string;
  businessPlaceId: string;
  memberNumber: string;
  name: string;
  phone?: string;
  email?: string;
  grade?: string;
  remark?: string;
  createdAt: string;
  updatedAt: string;
  isDeleted?: boolean;
  deletedAt?: string;
  deletedBy?: string;
}

export interface MemberWithMemo extends Member {
  latestMemo?: Memo;
}

// Memo Types
export interface Memo {
  id: string;
  memberId: string;
  memberName?: string;
  content: string;
  isImportant: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
  deleteRequestedAt?: string;
}

// Reservation Types
export type ReservationStatus = 'PENDING' | 'CONFIRMED' | 'CANCELLED' | 'COMPLETED' | 'NO_SHOW';

export interface Reservation {
  id: string;
  businessPlaceId: string;
  memberId: string;
  memberName?: string;
  reservationDate: string;
  reservationTime: string;
  durationMinutes: number;
  serviceType?: string;
  status: ReservationStatus;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

// Visit Types
export interface Visit {
  id: string;
  memberId: string;
  memberName?: string;
  businessPlaceId: string;
  visitTime: string;
  note?: string;
}

export interface CheckInRequest {
  memberId: string;
  note?: string;
}

// Statistics Types
export interface HomeStatistics {
  businessPlaceId: string;
  businessPlaceName: string;
  todayReservations: number;
  todayVisits: number;
  pendingMemos: number;
  totalMembers: number;
}

export interface TodaySchedule {
  reservationId: string;
  memberId: string;
  memberName: string;
  reservationTime: string;
  serviceType?: string;
  durationMinutes: number;
  status: ReservationStatus;
  notes?: string;
}

export interface RecentActivity {
  activityId: string;
  activityType: 'MEMO' | 'VISIT';
  memberId: string;
  memberName: string;
  content: string;
  activityTime: string;
}

// API Response Types
export interface ApiResponse<T> {
  data?: T;
  message?: string;
  error?: string;
}

export interface PaginatedResponse<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  size: number;
  number: number;
}

// Error Log Types (Admin)
export type ErrorSeverity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface ErrorLog {
  id: string;
  businessPlaceId?: string;
  businessPlaceName?: string;
  userId?: string;
  username?: string;
  severity: ErrorSeverity;
  errorCode?: string;
  message: string;
  stackTrace?: string;
  requestPath?: string;
  requestMethod?: string;
  userAgent?: string;
  ipAddress?: string;
  resolved: boolean;
  resolvedAt?: string;
  resolvedBy?: string;
  createdAt: string;
}

export interface ErrorLogSummary {
  totalErrors: number;
  unresolvedCount: number;
  criticalCount: number;
  highCount: number;
  mediumCount: number;
  lowCount: number;
  periodStart: string;
  periodEnd: string;
}

// Notice Types (Admin)
export type NoticeDisplayType = 'POPUP' | 'BANNER' | 'LIST';

export interface Notice {
  id: string;
  title: string;
  content: string;
  displayType: NoticeDisplayType;
  priority: number;
  isActive: boolean;
  startDate: string;
  endDate?: string;
  targetBusinessPlaceIds?: string[];
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface NoticeStats {
  noticeId: string;
  viewCount: number;
  hideCount: number;
}

// Admin System Stats Types
export interface SystemStats {
  totalUsers: number;
  activeUsers: number;
  newUsersToday: number;
  newUsersThisWeek: number;
  totalBusinessPlaces: number;
  activeBusinessPlaces: number;
  dau: number; // Daily Active Users
  mau: number; // Monthly Active Users
}

// Admin User Management Types
export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'BANNED';

export interface AdminUser {
  providerId: string;
  provider: string;
  name: string;
  email?: string;
  phone?: string;
  role: 'USER' | 'ADMIN';
  isSystemAdmin: boolean;
  status: UserStatus;
  lastLoginAt?: string;
  loginCount: number;
  businessPlaceCount: number;
  createdAt: string;
  updatedAt: string;
}

// Admin Business Place Management Types
export type BusinessPlaceStatus = 'ACTIVE' | 'SUSPENDED' | 'DELETED';

export interface AdminBusinessPlace {
  id: string;
  name: string;
  address?: string;
  phone?: string;
  description?: string;
  ownerId: string;
  ownerName: string;
  ownerEmail?: string;
  status: BusinessPlaceStatus;
  memberCount: number;
  staffCount: number;
  lastActivityAt?: string;
  createdAt: string;
  updatedAt: string;
}

// BusinessPlace Access Request Types
export type BusinessPlaceRole = 'OWNER' | 'MANAGER' | 'STAFF';
export type AccessRequestStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export interface BusinessPlaceAccessRequest {
  id: string;
  userId: string;
  businessPlaceId: string;
  role: BusinessPlaceRole;
  status: AccessRequestStatus;
  requestedAt: string;
  processedAt?: string;
  processedBy?: string;
  isReadByRequester: boolean;
  createdAt: string;
  updatedAt: string;
  // 요청자 정보
  requesterName?: string;
  requesterPhone?: string;
  requesterEmail?: string;
  // 사업장 정보
  businessPlaceName?: string;
}

export interface BusinessPlaceMember {
  userBusinessPlaceId: string;
  userId: string;
  businessPlaceId: string;
  role: BusinessPlaceRole;
  username?: string;
  phone?: string;
  email?: string;
  displayName?: string;
  joinedAt: string;
}

// Statistics Advanced Types (Trend Charts)
export interface TimeSeriesDataPoint {
  date: string;
  count: number;
}

export interface MemberRegistrationTrend {
  dataPoints: TimeSeriesDataPoint[];
  totalNewMembers: number;
}

export interface MemberGradeDistribution {
  distribution: Record<string, number>;
  totalMembers: number;
}

export interface ReservationTrend {
  dataPoints: TimeSeriesDataPoint[];
  totalReservations: number;
}

export interface MemoStatistics {
  totalMemos: number;
  importantMemos: number;
  archivedMemos: number;
  dailyMemos: TimeSeriesDataPoint[];
}
