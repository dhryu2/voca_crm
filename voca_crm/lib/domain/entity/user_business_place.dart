enum Role {
  OWNER,
  MANAGER,
  STAFF;

  static Role fromString(String value) {
    return Role.values.firstWhere((e) => e.name == value);
  }
}

enum AccessStatus {
  PENDING,
  APPROVED,
  REJECTED;

  static AccessStatus fromString(String value) {
    return AccessStatus.values.firstWhere((e) => e.name == value);
  }
}

class UserBusinessPlace {
  final String id;
  final String userId;
  final String businessPlaceId;
  final Role role;
  final AccessStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserBusinessPlace({
    required this.id,
    required this.userId,
    required this.businessPlaceId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserBusinessPlace.fromJson(Map<String, dynamic> json) {
    return UserBusinessPlace(
      id: json['id'],
      userId: json['userId'],
      businessPlaceId: json['businessPlaceId'],
      role: Role.fromString(json['role']),
      status: AccessStatus.fromString(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessPlaceId': businessPlaceId,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
