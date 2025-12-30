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
  deletedAt?: string;
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
