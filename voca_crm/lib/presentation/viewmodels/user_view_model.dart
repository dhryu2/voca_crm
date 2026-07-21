import 'package:flutter/foundation.dart';
import 'package:voca_crm/domain/entity/user.dart';

class UserViewModel extends ChangeNotifier {
  User? _user;

  User? get user => _user;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void updateUser(User user) {
    // updateUser/fcm-token/push-notification 등 갱신 응답에는 isSystemAdmin 키가
    // 없어 false로 파싱된다. 로그인(JWT) 시 확정된 기존 관리자 여부를 보존한다.
    if (_user != null && _user!.isSystemAdmin && !user.isSystemAdmin) {
      _user = User(
        id: user.id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        displayName: user.displayName,
        defaultBusinessPlaceId: user.defaultBusinessPlaceId,
        pushNotificationEnabled: user.pushNotificationEnabled,
        isSystemAdmin: _user!.isSystemAdmin,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      );
    } else {
      _user = user;
    }
    notifyListeners();
  }

  void updateDefaultBusinessPlace(String? businessPlaceId) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        username: _user!.username,
        email: _user!.email,
        phone: _user!.phone,
        displayName: _user!.displayName,
        defaultBusinessPlaceId: businessPlaceId,
        pushNotificationEnabled: _user!.pushNotificationEnabled,
        isSystemAdmin: _user!.isSystemAdmin,
        createdAt: _user!.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
