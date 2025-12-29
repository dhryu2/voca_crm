import 'package:voca_crm/domain/entity/user.dart';

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final User user;

  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}