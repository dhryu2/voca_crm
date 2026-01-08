import 'business_place.dart';
import 'user_business_place.dart';

class BusinessPlaceWithRole {
  final BusinessPlace businessPlace;
  final Role userRole;
  final int memberCount;

  BusinessPlaceWithRole({
    required this.businessPlace,
    required this.userRole,
    required this.memberCount,
  });

  factory BusinessPlaceWithRole.fromJson(Map<String, dynamic> json) {
    // 백엔드 BusinessPlaceWithRoleDTO는 플랫 구조로 응답:
    // businessPlaceId, businessPlaceName, businessPlaceAddress, businessPlacePhone,
    // businessPlaceCreatedAt, businessPlaceUpdatedAt, userRole, memberCount
    final now = DateTime.now();
    return BusinessPlaceWithRole(
      businessPlace: BusinessPlace(
        id: json['businessPlaceId'],
        name: json['businessPlaceName'],
        address: json['businessPlaceAddress'],
        phone: json['businessPlacePhone'],
        createdAt: json['businessPlaceCreatedAt'] != null
            ? DateTime.parse(json['businessPlaceCreatedAt'])
            : now,
        updatedAt: json['businessPlaceUpdatedAt'] != null
            ? DateTime.parse(json['businessPlaceUpdatedAt'])
            : now,
      ),
      userRole: Role.fromString(json['userRole']),
      memberCount: json['memberCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessPlace': businessPlace.toJson(),
      'userRole': userRole.name,
      'memberCount': memberCount,
    };
  }
}
