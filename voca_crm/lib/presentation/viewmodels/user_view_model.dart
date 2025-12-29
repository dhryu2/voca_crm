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
    _user = user;
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
