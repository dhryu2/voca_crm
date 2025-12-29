import 'package:jwt_decoder/jwt_decoder.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String phone;
  final String? defaultBusinessPlaceId;
  final bool pushNotificationEnabled;
  final bool isSystemAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    this.displayName,
    this.defaultBusinessPlaceId,
    this.pushNotificationEnabled = true,
    this.isSystemAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory for creating User from JWT token
  factory User.fromJwt(String accessToken) {
    final decodedToken = JwtDecoder.decode(accessToken);

    // Extract issued at time from JWT (iat claim in seconds)
    final userId = decodedToken['sub'] as String;
    final iat = decodedToken['iat'] as int?;
    final createdAt = iat != null
        ? DateTime.fromMillisecondsSinceEpoch(iat * 1000)
        : DateTime.now();

    return User(
      id: userId,
      username: decodedToken['username'] as String,
      email: decodedToken['email'] as String? ?? '',
      phone: decodedToken['phone'] as String? ?? '',
      displayName: decodedToken['displayName'] as String?,
      defaultBusinessPlaceId: decodedToken['defaultBusinessPlaceId'] as String?,
      pushNotificationEnabled: decodedToken['pushNotificationEnabled'] as bool? ?? true,
      isSystemAdmin: decodedToken['isSystemAdmin'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Factory for creating User from API JSON (signup, user info endpoints)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      displayName: json['displayName'],
      defaultBusinessPlaceId: json['defaultBusinessPlaceId'],
      pushNotificationEnabled: json['pushNotificationEnabled'] ?? true,
      isSystemAdmin: json['isSystemAdmin'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'defaultBusinessPlaceId': defaultBusinessPlaceId,
      'pushNotificationEnabled': pushNotificationEnabled,
      'isSystemAdmin': isSystemAdmin,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Getters for backward compatibility
  String get name => username;

  /// 하위 호환성을 위한 getter
  /// providerId는 더 이상 사용하지 않고 id(UUID)를 사용합니다.
  /// 기존 코드와의 호환성을 위해 id를 반환합니다.
  String get providerId => id;
}
