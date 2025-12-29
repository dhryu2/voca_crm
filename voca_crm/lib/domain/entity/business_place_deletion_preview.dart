/// 사업장 삭제 미리보기 DTO
class BusinessPlaceDeletionPreview {
  final String businessPlaceId;
  final String businessPlaceName;
  final int memberCount;
  final int memoCount;
  final int reservationCount;
  final int visitCount;
  final int auditLogCount;
  final int staffCount;
  final int accessRequestCount;

  BusinessPlaceDeletionPreview({
    required this.businessPlaceId,
    required this.businessPlaceName,
    required this.memberCount,
    required this.memoCount,
    required this.reservationCount,
    required this.visitCount,
    required this.auditLogCount,
    required this.staffCount,
    required this.accessRequestCount,
  });

  factory BusinessPlaceDeletionPreview.fromJson(Map<String, dynamic> json) {
    return BusinessPlaceDeletionPreview(
      businessPlaceId: json['businessPlaceId'] as String,
      businessPlaceName: json['businessPlaceName'] as String,
      memberCount: json['memberCount'] as int,
      memoCount: json['memoCount'] as int,
      reservationCount: json['reservationCount'] as int,
      visitCount: json['visitCount'] as int,
      auditLogCount: json['auditLogCount'] as int,
      staffCount: json['staffCount'] as int,
      accessRequestCount: json['accessRequestCount'] as int,
    );
  }

  /// 총 삭제될 데이터 개수
  int get totalDataCount =>
      memberCount +
      memoCount +
      reservationCount +
      visitCount +
      auditLogCount +
      accessRequestCount;

  /// 직원(Owner 제외)이 있는지 여부
  bool get hasStaff => staffCount > 0;
}
