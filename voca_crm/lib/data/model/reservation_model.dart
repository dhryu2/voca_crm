import 'package:voca_crm/domain/entity/reservation.dart';

/// 예약 데이터 모델
class ReservationModel {
  final String id;
  final String memberId;
  final String businessPlaceId;
  final String reservationDate; // YYYY-MM-DD format
  final String reservationTime; // HH:mm:ss format
  final String status;
  final String? serviceType;
  final int durationMinutes;
  final String? notes;
  final String? remark; // 예약 특이사항
  final String? createdBy;
  final String? updatedBy; // 마지막 수정자
  final String createdAt;
  final String updatedAt;

  ReservationModel({
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

  /// JSON에서 모델 생성
  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'],
      memberId: json['memberId'],
      businessPlaceId: json['businessPlaceId'],
      reservationDate: json['reservationDate'],
      reservationTime: json['reservationTime'],
      status: json['status'],
      serviceType: json['serviceType'],
      durationMinutes: json['durationMinutes'] ?? 60,
      notes: json['notes'],
      remark: json['remark'],
      createdBy: json['createdBy'],
      updatedBy: json['updatedBy'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  /// 모델을 JSON으로 변환 (생성 요청용 - 불필요한 필드 제외)
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'memberId': memberId,
      'businessPlaceId': businessPlaceId,
      'reservationDate': reservationDate,
      'reservationTime': reservationTime,
      'status': status,
      'durationMinutes': durationMinutes,
    };

    // 선택적 필드는 값이 있을 때만 포함
    if (serviceType != null && serviceType!.isNotEmpty) {
      json['serviceType'] = serviceType;
    }
    if (notes != null && notes!.isNotEmpty) {
      json['notes'] = notes;
    }
    if (remark != null && remark!.isNotEmpty) {
      json['remark'] = remark;
    }
    if (createdBy != null && createdBy!.isNotEmpty) {
      json['createdBy'] = createdBy;
    }
    if (updatedBy != null && updatedBy!.isNotEmpty) {
      json['updatedBy'] = updatedBy;
    }

    return json;
  }

  /// 엔티티로 변환
  Reservation toEntity() {
    return Reservation(
      id: id,
      memberId: memberId,
      businessPlaceId: businessPlaceId,
      reservationDate: DateTime.parse(reservationDate),
      reservationTime: DateTime.parse('1970-01-01 $reservationTime'),
      status: ReservationStatus.fromString(status) ?? ReservationStatus.PENDING,
      serviceType: serviceType,
      durationMinutes: durationMinutes,
      notes: notes,
      remark: remark,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// 엔티티에서 모델 생성
  factory ReservationModel.fromEntity(Reservation entity) {
    return ReservationModel(
      id: entity.id,
      memberId: entity.memberId,
      businessPlaceId: entity.businessPlaceId,
      reservationDate: entity.reservationDate.toIso8601String().split('T')[0],
      reservationTime: '${entity.reservationTime.hour.toString().padLeft(2, '0')}:'
          '${entity.reservationTime.minute.toString().padLeft(2, '0')}:'
          '${entity.reservationTime.second.toString().padLeft(2, '0')}',
      status: entity.status.name,
      serviceType: entity.serviceType,
      durationMinutes: entity.durationMinutes,
      notes: entity.notes,
      remark: entity.remark,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      createdAt: entity.createdAt.toIso8601String(),
      updatedAt: entity.updatedAt.toIso8601String(),
    );
  }
}
