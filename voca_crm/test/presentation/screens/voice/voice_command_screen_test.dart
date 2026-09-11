import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/data/datasource/voice_command_service.dart';
import 'package:voca_crm/domain/entity/conversation_context.dart';
import 'package:voca_crm/domain/entity/conversation_step.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/domain/entity/voice_command_response.dart';
import 'package:voca_crm/presentation/screens/voice/voice_command_screen.dart';
import 'package:voca_crm/presentation/screens/voice/voice_session_ports.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

void main() {
  group('parseVoiceSelectionNumber', () {
    test('띄어 쓴 첫번째를 1로 인식한다', () {
      expect(parseVoiceSelectionNumber('첫 번째'), 1);
      expect(parseVoiceSelectionNumber('첫번째'), 1);
      expect(parseVoiceSelectionNumber('1번'), 1);
      expect(parseVoiceSelectionNumber('1'), 1);
      expect(parseVoiceSelectionNumber('1번.'), 1);
    });

    test('두번째와 2번을 2로 인식한다', () {
      expect(parseVoiceSelectionNumber('두 번째'), 2);
      expect(parseVoiceSelectionNumber('2번'), 2);
    });

    test('후보 선택이 아닌 말은 null이다', () {
      expect(parseVoiceSelectionNumber('아니'), isNull);
      expect(parseVoiceSelectionNumber('음'), isNull);
      expect(parseVoiceSelectionNumber('전수검사_김테스트'), isNull);
    });
  });

  group('parseVoiceConfirmation', () {
    test('예/네/맞아요는 확인이다', () {
      expect(parseVoiceConfirmation('예'), isTrue);
      expect(parseVoiceConfirmation('네'), isTrue);
      expect(parseVoiceConfirmation('맞아요'), isTrue);
    });

    test('아니요/취소/안 맞아요는 거절이다', () {
      expect(parseVoiceConfirmation('아니요'), isFalse);
      expect(parseVoiceConfirmation('취소'), isFalse);
      expect(parseVoiceConfirmation('안 맞아요'), isFalse);
    });

    test('예약처럼 예가 포함된 일반 말은 확인으로 치지 않는다', () {
      expect(parseVoiceConfirmation('예약'), isNull);
      expect(parseVoiceConfirmation('안녕하세요'), isNull);
      expect(parseVoiceConfirmation('음'), isNull);
    });

    test('STT 마침표가 붙은 예/네도 확인이다', () {
      expect(parseVoiceConfirmation('예.'), isTrue);
      expect(parseVoiceConfirmation('네!'), isTrue);
      expect(parseVoiceConfirmation('아니요.'), isFalse);
      expect(parseVoiceConfirmation('예약.'), isNull);
    });
  });

  group('parseVoiceMemberReselect', () {
    test('다른 회원과 아니는 재선택이다', () {
      expect(parseVoiceMemberReselect('다른 회원'), isTrue);
      expect(parseVoiceMemberReselect('아니'), isTrue);
      expect(parseVoiceMemberReselect('다시 선택'), isTrue);
    });

    test('일반 검색어는 재선택이 아니다', () {
      expect(parseVoiceMemberReselect('홍길동 찾아줘'), isFalse);
      expect(parseVoiceMemberReselect('오늘 브리핑'), isFalse);
      expect(parseVoiceMemberReselect('예약'), isFalse);
    });
  });

  group('parseVoiceCandidateMaps', () {
    test('Map이 아닌 항목은 건너뛴다', () {
      final parsed = parseVoiceCandidateMaps([
        {'id': 'm1', 'name': '홍'},
        'not-a-map',
        3,
        {'id': 'm2', 'name': '길'},
      ]);
      expect(parsed.length, 2);
      expect(parsed.first['id'], 'm1');
      expect(parsed.last['id'], 'm2');
    });

    test('List가 아니면 빈 목록이다', () {
      expect(parseVoiceCandidateMaps(null), isEmpty);
      expect(parseVoiceCandidateMaps({'id': 'm1'}), isEmpty);
    });

    test('id가 없으면 voiceCandidateId는 null이다', () {
      expect(voiceCandidateId({'name': '홍'}), isNull);
      expect(voiceCandidateId({'id': '  '}), isNull);
      expect(voiceCandidateId({'id': 12}), '12');
    });
  });

  group('parseVoiceMetricFields', () {
    test('todayReservations와 totalMembers를 예약·회원 필드로 읽는다', () {
      final fields = parseVoiceMetricFields({
        'todayReservations': 2,
        'totalMembers': 10,
      });
      expect(fields.map((f) => f.key).toList(), ['reservation', 'member']);
      expect(fields.first.value, 2);
      expect(fields.last.value, 10);
    });

    test('0도 필드로 남긴다', () {
      final fields = parseVoiceMetricFields({
        'todayReservations': 0,
        'importantMemoCount': 0,
      });
      expect(fields, hasLength(2));
      expect(fields.every((f) => f.value == 0), isTrue);
    });

    test('data가 없거나 visits 리스트만 있으면 필드가 없다', () {
      expect(parseVoiceMetricFields(null), isEmpty);
      expect(
        parseVoiceMetricFields({
          'visits': [
            {'id': 'v1'},
          ],
        }),
        isEmpty,
      );
    });

    test('문자 숫자는 파싱하고 같은 종류는 spec 앞 키만 쓴다', () {
      expect(parseVoiceMetricFields({'visitCount': '3'}).single.value, 3);
      final fields = parseVoiceMetricFields({
        'visitCount': '3',
        'todayVisits': 9,
      });
      expect(fields, hasLength(1));
      expect(fields.first.value, 9);
    });
  });

  group('shouldPinVoiceResultPanel', () {
    test('브리핑·통계 발화면 data가 없어도 고정한다', () {
      expect(
        shouldPinVoiceResultPanel(userText: '오늘 브리핑 알려줘', data: null),
        isTrue,
      );
      expect(
        shouldPinVoiceResultPanel(userText: '홈 통계 알려줘', data: null),
        isTrue,
      );
    });

    test('회원 검색 발화는 필드가 없으면 고정하지 않는다', () {
      expect(
        shouldPinVoiceResultPanel(userText: '홍길동 찾아줘', data: null),
        isFalse,
      );
    });

    test('필드가 있으면 발화와 관계없이 고정한다', () {
      expect(
        shouldPinVoiceResultPanel(
          userText: '음',
          data: {'todayReservations': 1},
        ),
        isTrue,
      );
    });

    test('제목은 통계/브리핑/결과 순으로 고른다', () {
      expect(voiceResultPanelTitle('홈 통계 알려줘'), '홈 통계');
      expect(voiceResultPanelTitle('오늘 브리핑'), '오늘 브리핑');
      expect(voiceResultPanelTitle('음'), '결과');
    });
  });

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

  group('resolveVoiceErrorGuidance', () {
    test('AI_UNAVAILABLE은 재시도 안내를 주고 autoRestart를 막는다', () {
      final guidance = resolveVoiceErrorGuidance(errorCode: 'AI_UNAVAILABLE');
      expect(guidance.nextAction, contains('마이크'));
      expect(guidance.allowAutoRestart, isFalse);
    });

    test('RATE_LIMIT은 잠시 기다리라는 다음 행동을 준다', () {
      final guidance = resolveVoiceErrorGuidance(errorCode: 'RATE_LIMIT');
      expect(guidance.nextAction, contains('1분'));
      expect(guidance.allowAutoRestart, isFalse);
    });

    test('DAILY_LIMIT과 DAILY_LIMIT_EXCEEDED는 내일 재시도를 안내한다', () {
      final daily = resolveVoiceErrorGuidance(errorCode: 'DAILY_LIMIT');
      expect(daily.nextAction, contains('내일'));
      expect(daily.nextAction, isNot(contains('직접 입력')));
      expect(
        resolveVoiceErrorGuidance(errorCode: 'DAILY_LIMIT_EXCEEDED')
            .allowAutoRestart,
        isFalse,
      );
    });

    test('NO_BUSINESS_PLACE는 사업장 선택을 다음 행동으로 준다', () {
      final guidance =
          resolveVoiceErrorGuidance(errorCode: 'NO_BUSINESS_PLACE');
      expect(guidance.nextAction, contains('사업장'));
      expect(guidance.allowAutoRestart, isFalse);
    });

    test('UNKNOWN_COMMAND는 구체적 발화를 다음 행동으로 주고 autoRestart를 허용한다', () {
      final guidance =
          resolveVoiceErrorGuidance(errorCode: 'UNKNOWN_COMMAND');
      expect(guidance.nextAction, contains('브리핑'));
      expect(guidance.allowAutoRestart, isTrue);
    });
  });

  group('VoiceCommandScreen 상태머신', () {
    late _VoiceHarness harness;

    setUp(() {
      harness = _VoiceHarness();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness.app());
      await tester.pump();
      await tester.pump();
    }

    Future<void> tapMic(WidgetTester tester) async {
      await tester.tap(find.byKey(kVoiceMicButtonKey));
      await tester.pump();
    }

    Future<void> finishUtterance(
      WidgetTester tester, {
      required String text,
    }) async {
      await tapMic(tester);
      expect(find.text('듣고 있습니다...'), findsWidgets);
      harness.speech.emitResult(text, finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> completeTts(WidgetTester tester) async {
      harness.tts.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('permissionDenied이면 권한 안내와 설정 버튼이 보인다', (tester) async {
      harness.permission.outcome = VoicePermissionOutcome.denied;
      await pumpScreen(tester);

      expect(find.text('마이크 권한이 거부되었습니다'), findsWidgets);
      expect(find.text('권한 설정'), findsOneWidget);
      expect(find.text('설정에서 마이크 권한을 허용해주세요'), findsWidgets);
      expect(find.text('권한 필요'), findsOneWidget);

      await tester.tap(find.text('권한 설정'));
      await tester.pump();

      expect(find.text('마이크 권한 필요'), findsOneWidget);
      expect(find.text('설정으로 이동'), findsOneWidget);
    });

    testWidgets('영구 거부면 권한 다이얼로그가 바로 뜬다', (tester) async {
      harness.permission.outcome = VoicePermissionOutcome.permanentlyDenied;
      await pumpScreen(tester);

      expect(find.text('마이크 권한이 필요합니다'), findsWidgets);
      expect(find.text('마이크 권한 필요'), findsOneWidget);
    });

    testWidgets('listening 중 취소하면 ready로 돌아가고 autoRestart가 다시 listen하지 않는다',
        (tester) async {
      await pumpScreen(tester);
      await tapMic(tester);

      expect(find.text('듣고 있습니다...'), findsWidgets);
      expect(harness.speech.listenCount, 1);

      await tapMic(tester);

      expect(find.text('음성 인식 중지됨'), findsWidgets);
      expect(find.text('탭하여 시작'), findsOneWidget);
      expect(harness.speech.listenCount, 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('processing 중 마이크 재탭은 새 명령을 보내지 않는다', (tester) async {
      harness.api.pending = Completer<VoiceCommandResponse>();
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');

      expect(find.text('분석 중...'), findsWidgets);
      expect(harness.api.sendCount, 1);

      await tapMic(tester);
      await tester.pump();

      expect(harness.api.sendCount, 1);
      expect(find.text('분석 중...'), findsWidgets);

      harness.api.pending!.complete(
        VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '오늘 브리핑입니다.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('speaking 중 마이크는 TTS를 중단하고 청취를 시작한다', (tester) async {
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');

      expect(harness.tts.spoken, isNotEmpty);
      expect(find.text('건너뛰기'), findsOneWidget);

      await tapMic(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(harness.tts.stopCount, greaterThan(0));
      expect(find.text('듣는 중...'), findsWidgets);
      expect(harness.speech.listenCount, 2);

      await completeTts(tester);
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('브리핑 TTS가 끝나면 autoRestart가 바로 listen하지 않는다', (tester) async {
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');

      expect(harness.speech.listenCount, 1);
      expect(find.text('건너뛰기'), findsOneWidget);
      await completeTts(tester);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(harness.speech.listenCount, 1);
      expect(find.text('듣는 중...'), findsNothing);
      expect(find.text('탭하여 시작'), findsOneWidget);
      expect(find.text('다시 듣기'), findsOneWidget);
    });

    testWidgets('listening 고착(notListening/done)이면 ready로 동기화한다', (tester) async {
      await pumpScreen(tester);
      await tapMic(tester);
      expect(find.text('듣고 있습니다...'), findsWidgets);

      harness.speech.emitStatus('notListening');
      await tester.pump();

      expect(find.text('음성 인식 완료'), findsWidgets);
      expect(find.text('탭하여 시작'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    });

    testWidgets('STT no_match 오류 후 ready로 복귀하고 autoRestart가 listen한다',
        (tester) async {
      await pumpScreen(tester);
      await tapMic(tester);

      harness.speech.emitError('error_no_match');
      await tester.pump();

      expect(find.text('음성을 인식하지 못했습니다. 다시 말씀해주세요'), findsWidgets);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(harness.speech.listenCount, 2);
      expect(find.text('듣고 있습니다...'), findsWidgets);
    });

    testWidgets('에러 후 마이크 탭이면 다시 청취한다', (tester) async {
      harness.api.handler = () => throw VoiceCommandException(
            'AI 서버가 응답하지 않습니다. 잠시 후 다시 시도해주세요.',
            'AI_UNAVAILABLE',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');
      await completeTts(tester);

      expect(find.text('잠시 후 마이크를 다시 눌러 주세요'), findsWidgets);

      await tapMic(tester);
      await tester.pump();
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('AI_UNAVAILABLE이 화면에 다음 행동을 준다', (tester) async {
      harness.api.handler = () => throw VoiceCommandException(
            'down',
            'AI_UNAVAILABLE',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');
      await completeTts(tester);

      expect(find.text('AI 서버가 응답하지 않습니다. 잠시 후 다시 시도해주세요.'), findsWidgets);
      expect(find.text('잠시 후 마이크를 다시 눌러 주세요'), findsWidgets);
      expect(find.text('오류 발생'), findsOneWidget);
    });

    testWidgets('RATE_LIMIT이 화면에 다음 행동을 준다', (tester) async {
      harness.api.handler = () => throw VoiceCommandException(
            'too many',
            'RATE_LIMIT',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');
      await completeTts(tester);

      expect(find.text('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.'), findsWidgets);
      expect(find.text('1분 뒤에 다시 말씀해주세요'), findsWidgets);
    });

    testWidgets('DAILY_LIMIT이 화면에 다음 행동을 준다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.error,
            message: 'limit',
            errorCode: 'DAILY_LIMIT_EXCEEDED',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');
      await completeTts(tester);

      expect(find.text('오늘의 AI 분석 사용량을 초과했습니다. 내일 다시 시도해주세요.'), findsWidgets);
      expect(find.text('내일 다시 시도해 주세요'), findsWidgets);
      expect(find.textContaining('직접 입력'), findsNothing);
    });

    testWidgets('NO_BUSINESS_PLACE가 화면에 다음 행동을 준다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.error,
            message: 'no place',
            errorCode: 'NO_BUSINESS_PLACE',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍길동 찾아줘');
      await completeTts(tester);

      expect(
        find.text('사업장 정보가 없어 명령을 처리할 수 없습니다. 사업장을 먼저 선택해주세요.'),
        findsWidgets,
      );
      expect(find.text('홈에서 사업장을 선택한 뒤 다시 시도하세요'), findsWidgets);
    });

    testWidgets('STT permission 오류는 permissionDenied로 고정하고 재청취하지 않는다',
        (tester) async {
      await pumpScreen(tester);
      await tapMic(tester);

      harness.speech.emitError('error_permission');
      await tester.pump();

      expect(find.text('마이크 권한이 거부되었습니다'), findsWidgets);
      expect(find.text('마이크 권한 필요'), findsOneWidget);
      expect(harness.speech.listenCount, 1);

      await tester.tap(find.text('취소'));
      await tester.pump();

      await tapMic(tester);
      await tester.pump();
      expect(find.text('마이크 권한 필요'), findsOneWidget);
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('API processing 응답에 마이크가 고착되지 않는다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.processing,
            message: '처리 중입니다',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');

      expect(find.text('마이크를 눌러 다시 시도해주세요'), findsWidgets);
      expect(find.text('건너뛰기'), findsOneWidget);

      await tapMic(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('명령 처리 중 화면을 닫아도 setState 크래시가 나지 않는다', (tester) async {
      harness.api.pending = Completer<VoiceCommandResponse>();
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑');
      expect(find.text('분석 중...'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      harness.api.pending!.complete(
        VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '오늘 브리핑입니다.',
        ),
      );
      await tester.pump();
    });

    testWidgets('UNKNOWN_COMMAND가 화면에 다음 행동을 준다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.error,
            message: 'unknown',
            errorCode: 'UNKNOWN_COMMAND',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '음');

      expect(find.textContaining('구체적으로'), findsWidgets);

      await completeTts(tester);
      expect(find.textContaining('구체적으로'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    });

    testWidgets('빈 화면 예시 명령이 브리핑·통계·검색 순이다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('"오늘 브리핑 알려줘"'), findsOneWidget);
      expect(find.text('"홈 통계 알려줘"'), findsOneWidget);
      expect(find.text('"홍길동 회원 찾아줘"'), findsOneWidget);
      expect(find.text('"1234번 회원 찾아줘"'), findsOneWidget);
      expect(find.text('"홍길동 방문 체크해줘"'), findsNothing);
      expect(find.text('"김철수 회원 등록해줘"'), findsNothing);

      final briefing = tester.getTopLeft(find.text('"오늘 브리핑 알려줘"'));
      final stats = tester.getTopLeft(find.text('"홈 통계 알려줘"'));
      final search = tester.getTopLeft(find.text('"홍길동 회원 찾아줘"'));
      expect(briefing.dy, lessThan(stats.dy));
      expect(stats.dy, lessThan(search.dy));
    });

    testWidgets('채팅이 생긴 뒤 분석 중/듣는 중이 하단 한 줄로 남는다', (tester) async {
      harness.api.pending = Completer<VoiceCommandResponse>();
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');

      expect(find.byKey(kVoiceCompactStatusKey), findsOneWidget);
      expect(find.text('분석 중...'), findsWidgets);

      harness.api.pending!.complete(
        VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '오늘 브리핑입니다. 방문 3건입니다.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('답변을 읽고 있습니다'), findsOneWidget);

      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await tapMic(tester);
      await tester.pump();

      expect(find.byKey(kVoiceCompactStatusKey), findsOneWidget);
      expect(find.text('듣고 있습니다. 지금 말씀하세요'), findsOneWidget);
    });

    testWidgets('브리핑 다시 듣기는 같은 내용을 말하고 채팅을 복제하지 않는다', (tester) async {
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('오늘 브리핑입니다. 방문 3건입니다.'), findsOneWidget);
      final spokenBefore = harness.tts.spoken.length;

      await tester.tap(find.byKey(kVoiceReplayButtonKey));
      await tester.pump();

      expect(harness.tts.spoken.length, spokenBefore + 1);
      expect(harness.tts.spoken.last, '오늘 브리핑입니다. 방문 3건입니다.');
      expect(find.text('오늘 브리핑입니다. 방문 3건입니다.'), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget);
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('회원 후보 TTS가 끝나면 번호 대답을 위해 listen한다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '회원을 선택해주세요',
            data: {
              'candidates': [
                {'id': 'm1', 'name': '홍길동', 'memberNumber': '1'},
                {'id': 'm2', 'name': '홍길순', 'memberNumber': '2'},
              ],
              'searchKeyword': '홍',
            },
            selectionOptions: SelectionOptions(targetEntityType: 'member'),
            context: ConversationContext(
              conversationId: 'c-search',
              currentStep: ConversationStep(
                stepType: 'member_selection',
                stepNumber: 1,
                targetEntityType: 'member',
              ),
            ),
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍 찾아줘');

      expect(find.text('회원 선택'), findsOneWidget);
      expect(harness.speech.listenCount, 1);

      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(harness.speech.listenCount, 2);
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('빈 TTS 응답이면 processing에 고착되지 않는다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.completed,
            message: '',
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');

      expect(find.text('분석 중...'), findsNothing);
      expect(find.text('탭하여 시작'), findsOneWidget);

      await tapMic(tester);
      await tester.pump();
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('확인 단계에서 예약은 파괴 확인으로 보내지 않는다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '홍길동 회원을 삭제할까요?',
            context: ConversationContext(
              conversationId: 'c-del',
              currentStep: ConversationStep(
                stepType: 'confirmation',
                stepNumber: 1,
              ),
            ),
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍길동 삭제해줘');

      expect(find.text('예'), findsOneWidget);
      expect(find.text('아니오'), findsOneWidget);

      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(harness.speech.listenCount, 2);
      harness.speech.emitResult('예약', finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.api.sentTexts, ['홍길동 삭제해줘']);
      expect(find.textContaining('예 또는 아니오'), findsWidgets);
    });

    testWidgets('확인 단계에서 예. 문장부호는 확인으로 보낸다', (tester) async {
      var stage = 0;
      harness.api.handler = () async {
        stage++;
        if (stage == 1) {
          return VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '홍길동 회원을 삭제할까요?',
            context: ConversationContext(
              conversationId: 'c-del',
              currentStep: ConversationStep(
                stepType: 'confirmation',
                stepNumber: 1,
              ),
            ),
          );
        }
        return VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '삭제 대기 상태로 전환되었습니다.',
        );
      };
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍길동 삭제해줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      harness.speech.emitResult('예.', finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.api.sentTexts, ['홍길동 삭제해줘', '예']);
    });

    testWidgets('빈 화면 상태 카드를 누르면 바로 듣는다', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(kVoiceListenPolicyHintKey), findsOneWidget);
      expect(find.text('대화만'), findsOneWidget);

      await tester.tap(find.byKey(kVoiceStatusCardKey));
      await tester.pump();

      expect(find.text('듣고 있습니다...'), findsWidgets);
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('브리핑 후 대화만 칩을 다시 켜도 listen하지 않는다', (tester) async {
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(harness.speech.listenCount, 1);
      expect(find.text('새 명령을 말하려면 마이크를 누르세요'), findsOneWidget);

      await tester.tap(find.byKey(kVoiceAutoRestartChipKey));
      await tester.pump();
      expect(find.text('수동'), findsOneWidget);
      expect(harness.speech.listenCount, 1);

      await tester.tap(find.byKey(kVoiceAutoRestartChipKey));
      await tester.pump();
      expect(find.text('대화만'), findsOneWidget);
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('listening 중지 뒤에도 대화만 칩은 유지된다', (tester) async {
      await pumpScreen(tester);
      await tapMic(tester);
      await tapMic(tester);

      expect(find.text('음성 인식 중지됨'), findsWidgets);
      expect(find.text('대화만'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('후보 목록에서는 다시 듣기가 처음으로와 같이 보인다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '회원을 선택해주세요',
            data: {
              'candidates': [
                {'id': 'm1', 'name': '홍길동', 'memberNumber': '1'},
                {'id': 'm2', 'name': '홍길순', 'memberNumber': '2'},
              ],
              'searchKeyword': '홍',
            },
            selectionOptions: SelectionOptions(targetEntityType: 'member'),
            context: ConversationContext(
              conversationId: 'c-search',
              currentStep: ConversationStep(
                stepType: 'member_selection',
                stepNumber: 1,
                targetEntityType: 'member',
              ),
            ),
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍 찾아줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('처음으로'), findsWidgets);
      expect(find.text('다시 듣기'), findsOneWidget);
      expect(find.text('듣는 중...'), findsWidgets);
    });

    testWidgets('잘못된 회원 선택 후 다른 회원으로 후보를 되돌린다', (tester) async {
      var stage = 0;
      harness.api.handler = () async {
        stage++;
        if (stage == 1) {
          return VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '홍 회원이 2명 있습니다',
            data: {
              'candidates': [
                {
                  'id': 'm1',
                  'name': '홍길동',
                  'memberNumber': '1',
                  'phone': '010',
                },
                {
                  'id': 'm2',
                  'name': '홍길순',
                  'memberNumber': '2',
                  'phone': '010',
                },
              ],
              'searchKeyword': '홍',
            },
            selectionOptions: SelectionOptions(targetEntityType: 'member'),
            context: ConversationContext(
              conversationId: 'c-search',
              currentStep: ConversationStep(
                stepType: 'member_selection',
                stepNumber: 1,
                targetEntityType: 'member',
              ),
              originalIntent: {'category': 'MEMBER', 'action': 'SEARCH'},
            ),
          );
        }
        return VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '홍길동 회원님 정보입니다.',
          data: {
            'member': {
              'id': 'm1',
              'name': '홍길동',
              'memberNumber': '1',
              'phone': '010-0000-0000',
            },
          },
        );
      };

      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍 찾아줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      harness.speech.emitResult('1번', finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(kVoicePinnedMemberCardKey), findsOneWidget);
      expect(find.text('다른 회원'), findsOneWidget);

      await tester.tap(find.byKey(kVoiceReselectMemberKey));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('회원 선택'), findsOneWidget);
      expect(find.text('번호로 다시 선택해주세요.'), findsWidgets);
      expect(find.byKey(kVoicePinnedMemberCardKey), findsNothing);
    });

    testWidgets('후보 Map이 아니면 화면이 죽지 않고 다시 검색을 안내한다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.clarificationNeeded,
            message: '회원을 선택해주세요',
            data: {
              'candidates': ['bad', 1],
              'searchKeyword': '홍',
            },
            selectionOptions: SelectionOptions(targetEntityType: 'member'),
            context: ConversationContext(
              conversationId: 'c-search',
              currentStep: ConversationStep(
                stepType: 'member_selection',
                stepNumber: 1,
                targetEntityType: 'member',
              ),
            ),
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍 찾아줘');

      expect(tester.takeException(), isNull);
      expect(find.textContaining('다시 검색'), findsWidgets);
    });

    testWidgets('분석 중에는 처음으로로 끊을 수 있다', (tester) async {
      harness.api.pending = Completer<VoiceCommandResponse>();
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      expect(find.text('분석 중...'), findsWidgets);
      expect(find.text('처음으로'), findsWidgets);

      await tester.tap(find.text('처음으로').first);
      await tester.pump();

      expect(find.text('마이크 버튼을 눌러 시작하세요'), findsWidgets);
      harness.api.pending!.complete(
        VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '늦게 온 브리핑',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('늦게 온 브리핑'), findsNothing);
    });

    testWidgets('자동 듣기 칩 높이는 44 이상이다', (tester) async {
      await pumpScreen(tester);
      final size = tester.getSize(find.byKey(kVoiceAutoRestartChipKey));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('브리핑 필드가 있으면 결과 카드로 고정하고 채팅 단락이 아니다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.completed,
            message: '오늘 예약은 2건이고, 등록된 회원은 10명입니다. 중요 메모는 1개입니다.',
            data: {
              'todayReservations': 2,
              'totalMembers': 10,
              'importantMemoCount': 1,
            },
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(kVoiceResultPanelKey), findsOneWidget);
      expect(find.byKey(kVoiceResultMetricsKey), findsOneWidget);
      expect(find.byKey(kVoiceResultLineKey), findsNothing);
      expect(find.text('오늘 브리핑'), findsOneWidget);
      expect(find.text('2건'), findsOneWidget);
      expect(find.text('예약'), findsOneWidget);
      expect(find.text('10명'), findsOneWidget);
      expect(find.text('회원'), findsOneWidget);
      expect(find.text('1개'), findsOneWidget);
      expect(find.text('중요 메모'), findsOneWidget);
      expect(
        find.text('오늘 예약은 2건이고, 등록된 회원은 10명입니다. 중요 메모는 1개입니다.'),
        findsNothing,
      );
      expect(find.text('다시 듣기'), findsOneWidget);
      expect(harness.speech.listenCount, 1);
    });

    testWidgets('브리핑 필드가 없으면 마지막 TTS 결과 줄과 다시 듣기가 보인다', (tester) async {
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(kVoiceResultPanelKey), findsOneWidget);
      expect(find.byKey(kVoiceResultLineKey), findsOneWidget);
      expect(find.byKey(kVoiceResultMetricsKey), findsNothing);
      expect(find.text('오늘 브리핑입니다. 방문 3건입니다.'), findsOneWidget);
      expect(find.text('다시 듣기'), findsOneWidget);
      expect(find.text('"오늘 브리핑 알려줘"'), findsNothing);
    });

    testWidgets('홈 통계 필드가 있으면 예약·회원 카드로 고정한다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.completed,
            message: '오늘 예약은 4건이고, 등록된 회원은 8명입니다.',
            data: {
              'todayReservations': 4,
              'totalMembers': 8,
            },
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홈 통계 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('홈 통계'), findsOneWidget);
      expect(find.text('4건'), findsOneWidget);
      expect(find.text('8명'), findsOneWidget);
      expect(find.text('오늘 예약은 4건이고, 등록된 회원은 8명입니다.'), findsNothing);
    });

    testWidgets('채팅 뒤 UNKNOWN_COMMAND에서 브리핑·통계·검색 예시가 다시 보인다', (tester) async {
      var stage = 0;
      harness.api.handler = () async {
        stage++;
        if (stage == 1) {
          return VoiceCommandResponse(
            status: VoiceCommandStatus.completed,
            message: '오늘 브리핑입니다. 방문 3건입니다.',
          );
        }
        return VoiceCommandResponse(
          status: VoiceCommandStatus.error,
          message: 'unknown',
          errorCode: 'UNKNOWN_COMMAND',
        );
      };
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('"오늘 브리핑 알려줘"'), findsNothing);

      await tapMic(tester);
      harness.speech.emitResult('음', finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(kVoiceRecoveryExamplesKey), findsOneWidget);
      expect(find.text('"오늘 브리핑 알려줘"'), findsOneWidget);
      expect(find.text('"홈 통계 알려줘"'), findsOneWidget);
      expect(find.text('"홍길동 회원 찾아줘"'), findsOneWidget);
    });

    testWidgets('채팅 뒤 AI_UNAVAILABLE에서도 회복 예시가 보인다', (tester) async {
      var stage = 0;
      harness.api.handler = () {
        stage++;
        if (stage == 1) {
          return Future.value(
            VoiceCommandResponse(
              status: VoiceCommandStatus.completed,
              message: '오늘 브리핑입니다. 방문 3건입니다.',
            ),
          );
        }
        throw VoiceCommandException('down', 'AI_UNAVAILABLE');
      };
      await pumpScreen(tester);
      await finishUtterance(tester, text: '오늘 브리핑 알려줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await tapMic(tester);
      harness.speech.emitResult('홈 통계 알려줘', finalResult: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await completeTts(tester);
      await tester.pump();

      expect(find.byKey(kVoiceRecoveryExamplesKey), findsOneWidget);
      expect(find.text('"오늘 브리핑 알려줘"'), findsOneWidget);
      expect(find.text('잠시 후 마이크를 다시 눌러 주세요'), findsWidgets);
    });

    testWidgets('회원 검색 완료는 통계 카드가 아니라 회원 카드다', (tester) async {
      harness.api.handler = () async => VoiceCommandResponse(
            status: VoiceCommandStatus.completed,
            message: '홍길동 회원님 정보입니다.',
            data: {
              'member': {
                'id': 'm1',
                'name': '홍길동',
                'memberNumber': '1',
                'phone': '010-0000-0000',
              },
            },
          );
      await pumpScreen(tester);
      await finishUtterance(tester, text: '홍길동 회원 찾아줘');
      await completeTts(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(kVoicePinnedMemberCardKey), findsOneWidget);
      expect(find.byKey(kVoiceResultPanelKey), findsNothing);
      expect(find.byKey(kVoiceResultMetricsKey), findsNothing);
      expect(find.text('홍길동 회원님 정보입니다.'), findsOneWidget);
    });
  });
}

class _VoiceHarness {
  _VoiceHarness() {
    permission.outcome = VoicePermissionOutcome.granted;
    api.handler = () async => VoiceCommandResponse(
          status: VoiceCommandStatus.completed,
          message: '오늘 브리핑입니다. 방문 3건입니다.',
        );
  }

  final speech = _FakeSpeech();
  final tts = _FakeTts();
  final permission = _FakePermission();
  final api = _FakeVoiceApi();

  Widget app() {
    final viewModel = UserViewModel()
      ..setUser(
        User(
          id: 'user-1',
          username: 'tester',
          email: 'tester@example.com',
          phone: '010-0000-0000',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      );

    return MaterialApp(
      home: ChangeNotifierProvider<UserViewModel>.value(
        value: viewModel,
        child: VoiceCommandScreen(
          speech: speech,
          tts: tts,
          permission: permission,
          voiceCommandApi: api,
        ),
      ),
    );
  }
}

class _FakeSpeech implements VoiceSpeechPort {
  int listenCount = 0;
  int stopCount = 0;
  bool listening = false;
  bool available = true;
  void Function(String status)? onStatus;
  void Function(VoiceSpeechError error)? onError;
  void Function(VoiceSpeechListenResult result)? onResult;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceSpeechError error) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    return available;
  }

  @override
  Future<void> listen({
    required void Function(VoiceSpeechListenResult result) onResult,
  }) async {
    listenCount++;
    listening = true;
    this.onResult = onResult;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    listening = false;
    onStatus?.call('notListening');
    onStatus?.call('done');
  }

  @override
  bool get isListening => listening;

  void emitResult(String words, {bool finalResult = false}) {
    onResult?.call(
      VoiceSpeechListenResult(
        recognizedWords: words,
        finalResult: finalResult,
      ),
    );
  }

  void emitStatus(String status) => onStatus?.call(status);

  void emitError(String msg) => onError?.call(VoiceSpeechError(msg));
}

class _FakeTts implements VoiceTtsPort {
  VoidCallback? completionHandler;
  final spoken = <String>[];
  int stopCount = 0;

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  void setCompletionHandler(VoidCallback handler) {
    completionHandler = handler;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void complete() => completionHandler?.call();
}

class _FakePermission implements VoicePermissionPort {
  VoicePermissionOutcome outcome = VoicePermissionOutcome.granted;
  int openSettingsCount = 0;

  @override
  Future<VoicePermissionOutcome> requestMicrophoneAndSpeech() async =>
      outcome;

  @override
  Future<void> openSettings() async {
    openSettingsCount++;
  }
}

class _FakeVoiceApi implements VoiceCommandApi {
  int sendCount = 0;
  final sentTexts = <String>[];
  Future<VoiceCommandResponse> Function()? handler;
  Completer<VoiceCommandResponse>? pending;

  @override
  Future<VoiceCommandResponse> sendVoiceCommand({
    required String text,
    ConversationContext? context,
    String? userId,
  }) {
    sendCount++;
    sentTexts.add(text);
    if (pending != null) return pending!.future;
    if (handler != null) return handler!();
    return Future.value(
      VoiceCommandResponse(
        status: VoiceCommandStatus.completed,
        message: '완료',
      ),
    );
  }
}
