import 'user_business_place.dart';

class BusinessPlaceAccessRequest {
  final String id;
  final String userId;
  final String businessPlaceId;
  final Role role;
  final AccessStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final bool isReadByRequester;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 요청자 정보 (API에서 함께 반환)
  final String? requesterName;
  final String? requesterPhone;
  final String? requesterEmail;

  // 사업장 정보 (API에서 함께 반환)
  final String? businessPlaceName;

  BusinessPlaceAccessRequest({
    required this.id,
    required this.userId,
    required this.businessPlaceId,
    required this.role,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    required this.isReadByRequester,
    required this.createdAt,
    required this.updatedAt,
    this.requesterName,
    this.requesterPhone,
    this.requesterEmail,
    this.businessPlaceName,
  });

  factory BusinessPlaceAccessRequest.fromJson(Map<String, dynamic> json) {
    return BusinessPlaceAccessRequest(
      id: json['id'],
      userId: json['userId'],
      businessPlaceId: json['businessPlaceId'],
      role: Role.fromString(json['role']),
      status: AccessStatus.fromString(json['status']),
      requestedAt: DateTime.parse(json['requestedAt']),
      processedAt: json['processedAt'] != null ? DateTime.parse(json['processedAt']) : null,
      processedBy: json['processedBy'],
      isReadByRequester: json['isReadByRequester'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      // 요청자 정보
      requesterName: json['requesterName'],
      requesterPhone: json['requesterPhone'],
      requesterEmail: json['requesterEmail'],
      // 사업장 정보
      businessPlaceName: json['businessPlaceName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessPlaceId': businessPlaceId,
      'role': role.name,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
      'isReadByRequester': isReadByRequester,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'requesterName': requesterName,
      'requesterPhone': requesterPhone,
      'requesterEmail': requesterEmail,
      'businessPlaceName': businessPlaceName,
    };
  }
}
