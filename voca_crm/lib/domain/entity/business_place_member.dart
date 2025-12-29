import 'user_business_place.dart';

/// 사업장 멤버 정보 DTO
///
/// 사업장 멤버 관리 화면에서 사용됩니다.
/// 멤버의 사용자 정보와 역할 정보를 포함합니다.
class BusinessPlaceMember {
  final String userBusinessPlaceId;
  final String userId;
  final String businessPlaceId;
  final Role role;
  final String? username;
  final String? phone;
  final String? email;
  final String? displayName;
  final DateTime joinedAt;

  BusinessPlaceMember({
    required this.userBusinessPlaceId,
    required this.userId,
    required this.businessPlaceId,
    required this.role,
    this.username,
    this.phone,
    this.email,
    this.displayName,
    required this.joinedAt,
  });

  factory BusinessPlaceMember.fromJson(Map<String, dynamic> json) {
    return BusinessPlaceMember(
      userBusinessPlaceId: json['userBusinessPlaceId'],
      userId: json['userId'],
      businessPlaceId: json['businessPlaceId'],
      role: Role.fromString(json['role']),
      username: json['username'],
      phone: json['phone'],
      email: json['email'],
      displayName: json['displayName'],
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userBusinessPlaceId': userBusinessPlaceId,
      'userId': userId,
      'businessPlaceId': businessPlaceId,
      'role': role.name,
      'username': username,
      'phone': phone,
      'email': email,
      'displayName': displayName,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// 표시용 이름 (displayName 우선, 없으면 username)
  String get displayNameOrUsername => displayName ?? username ?? '알 수 없음';

  /// 역할 한글 표시
  String get roleDisplayName {
    switch (role) {
      case Role.OWNER:
        return '소유자';
      case Role.MANAGER:
        return '관리자';
      case Role.STAFF:
        return '직원';
    }
  }
}
