import 'package:flutter_test/flutter_test.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

User _buildUser({required bool isSystemAdmin, String id = 'user-1'}) {
  final now = DateTime(2024, 1, 1);
  return User(
    id: id,
    username: 'tester',
    email: 'tester@example.com',
    phone: '010-0000-0000',
    isSystemAdmin: isSystemAdmin,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('UserViewModel.updateUser', () {
    test('기존 isSystemAdmin=true 상태에서 응답에 isSystemAdmin=false가 오면 보존한다', () {
      final viewModel = UserViewModel();
      viewModel.setUser(_buildUser(isSystemAdmin: true));

      final incoming = _buildUser(isSystemAdmin: false, id: 'user-2');
      viewModel.updateUser(incoming);

      expect(viewModel.user!.isSystemAdmin, isTrue);
      // isSystemAdmin 외 필드는 새 응답 값으로 갱신되어야 한다.
      expect(viewModel.user!.id, 'user-2');
    });

    test('기존 isSystemAdmin=false 상태에서 응답에 isSystemAdmin=true가 오면 갱신한다', () {
      final viewModel = UserViewModel();
      viewModel.setUser(_buildUser(isSystemAdmin: false));

      final incoming = _buildUser(isSystemAdmin: true, id: 'user-3');
      viewModel.updateUser(incoming);

      expect(viewModel.user!.isSystemAdmin, isTrue);
      expect(viewModel.user!.id, 'user-3');
    });

    test('기존 isSystemAdmin=false 상태에서 응답도 false면 그대로 false다', () {
      final viewModel = UserViewModel();
      viewModel.setUser(_buildUser(isSystemAdmin: false));

      viewModel.updateUser(_buildUser(isSystemAdmin: false, id: 'user-4'));

      expect(viewModel.user!.isSystemAdmin, isFalse);
    });

    test('기존 사용자가 없는 상태(_user == null)에서는 응답을 그대로 반영한다', () {
      final viewModel = UserViewModel();

      viewModel.updateUser(_buildUser(isSystemAdmin: false, id: 'user-5'));

      expect(viewModel.user, isNotNull);
      expect(viewModel.user!.id, 'user-5');
      expect(viewModel.user!.isSystemAdmin, isFalse);
    });

    test('updateUser 호출 시 notifyListeners가 호출된다', () {
      final viewModel = UserViewModel();
      viewModel.setUser(_buildUser(isSystemAdmin: true));

      var notified = false;
      viewModel.addListener(() {
        notified = true;
      });

      viewModel.updateUser(_buildUser(isSystemAdmin: false, id: 'user-6'));

      expect(notified, isTrue);
    });
  });
}
