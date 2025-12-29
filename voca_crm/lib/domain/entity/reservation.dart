/// 예약 엔티티
class Reservation {
  final String id;
  final String memberId;
  final String businessPlaceId;
  final DateTime reservationDate;
  final DateTime reservationTime;
  final ReservationStatus status;
  final String? serviceType;
  final int durationMinutes;
  final String? notes;
  final String? remark; // 예약 특이사항 (예: "30분 늦을 수도 있음")
  final String? createdBy;
  final String? updatedBy; // 마지막 수정자
  final DateTime createdAt;
  final DateTime updatedAt;

  Reservation({
    required this.id,
    required this.memberId,
    required this.businessPlaceId,
    required this.reservationDate,
    required this.reservationTime,
    required this.status,
    this.serviceType,
    this.durationMinutes = 60,
    this.notes,
    this.remark,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Reservation copyWith({
    String? id,
    String? memberId,
    String? businessPlaceId,
    DateTime? reservationDate,
    DateTime? reservationTime,
    ReservationStatus? status,
    String? serviceType,
    int? durationMinutes,
    String? notes,
    String? remark,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      businessPlaceId: businessPlaceId ?? this.businessPlaceId,
      reservationDate: reservationDate ?? this.reservationDate,
      reservationTime: reservationTime ?? this.reservationTime,
      status: status ?? this.status,
      serviceType: serviceType ?? this.serviceType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      remark: remark ?? this.remark,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 예약 상태 ENUM
enum ReservationStatus {
  PENDING,
  CONFIRMED,
  CANCELLED,
  COMPLETED,
  NO_SHOW;

  String get displayName {
    switch (this) {
      case ReservationStatus.PENDING:
        return '대기중';
      case ReservationStatus.CONFIRMED:
        return '확정됨';
      case ReservationStatus.CANCELLED:
        return '취소됨';
      case ReservationStatus.COMPLETED:
        return '완료됨';
      case ReservationStatus.NO_SHOW:
        return '노쇼';
    }
  }

  static ReservationStatus? fromString(String? value) {
    if (value == null) return null;
    try {
      return ReservationStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == value.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
