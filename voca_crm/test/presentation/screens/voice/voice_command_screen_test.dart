import 'package:flutter_test/flutter_test.dart';
import 'package:voca_crm/presentation/screens/voice/voice_command_screen.dart';

void main() {
  group('resolveMemberAndMemoData', () {
    test('data가 null이면 member/memo 모두 null이다', () {
      final result = resolveMemberAndMemoData(null);

      expect(result.member, isNull);
      expect(result.memo, isNull);
    });

    test('단일 액션 응답은 data의 member/memo를 그대로 사용한다', () {
      final data = {
        'member': {'id': 'm1'},
        'memo': {'id': 'note1'},
      };

      final result = resolveMemberAndMemoData(data);

      expect(result.member, data['member']);
      expect(result.memo, data['memo']);
    });

    test(
      '멀티액션 응답에서 마지막으로 member가 포함된 단계의 값을 사용한다',
      () {
        final data = {
          'steps': [
            {
              'data': {
                'member': {'id': 'm1'},
              },
            },
            {
              'data': {
                'member': {'id': 'm2'},
              },
            },
          ],
        };

        final result = resolveMemberAndMemoData(data);

        expect(result.member, {'id': 'm2'});
      },
    );

    test(
      'memo 없는 후속 회원 단계가 앞선 단계의 memo를 null로 덮어쓰지 않는다',
      () {
        final data = {
          'steps': [
            {
              'data': {
                'member': {'id': 'm1'},
                'memo': {'id': 'note1'},
              },
            },
            {
              'data': {
                'member': {'id': 'm2'},
              },
            },
          ],
        };

        final result = resolveMemberAndMemoData(data);

        expect(result.member, {'id': 'm2'});
        expect(result.memo, {'id': 'note1'});
      },
    );

    test('member/memo가 각각 다른 단계에서 등장하면 각자 마지막 값을 독립적으로 유지한다', () {
      final data = {
        'steps': [
          {
            'data': {
              'member': {'id': 'm1'},
            },
          },
          {
            'data': {
              'memo': {'id': 'note1'},
            },
          },
          {
            'data': {
              'member': {'id': 'm2'},
            },
          },
          {
            'data': {
              'memo': {'id': 'note2'},
            },
          },
        ],
      };

      final result = resolveMemberAndMemoData(data);

      expect(result.member, {'id': 'm2'});
      expect(result.memo, {'id': 'note2'});
    });

    test('data에 이미 member가 있으면 steps는 무시한다', () {
      final data = {
        'member': {'id': 'direct'},
        'steps': [
          {
            'data': {
              'member': {'id': 'from-step'},
            },
          },
        ],
      };

      final result = resolveMemberAndMemoData(data);

      expect(result.member, {'id': 'direct'});
    });

    test('steps 내 유효하지 않은 data(Map이 아님)는 무시한다', () {
      final data = {
        'steps': [
          {'data': 'invalid'},
          {
            'data': {
              'member': {'id': 'm1'},
            },
          },
        ],
      };

      final result = resolveMemberAndMemoData(data);

      expect(result.member, {'id': 'm1'});
    });
  });
}
