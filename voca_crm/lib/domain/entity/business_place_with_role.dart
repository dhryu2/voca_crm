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
    return BusinessPlaceWithRole(
      businessPlace: BusinessPlace.fromJson(json['businessPlace']),
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
