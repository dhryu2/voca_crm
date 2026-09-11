import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/memo_service.dart';
import 'package:voca_crm/data/datasource/voice_command_service.dart';
import 'package:voca_crm/data/repository/memo_repository_impl.dart';
import 'package:voca_crm/domain/entity/conversation_context.dart';
import 'package:voca_crm/domain/entity/member.dart';
import 'package:voca_crm/domain/entity/memo.dart';
import 'package:voca_crm/domain/entity/selected_entity.dart';
import 'package:voca_crm/domain/entity/voice_command_response.dart';
import 'package:voca_crm/presentation/screens/voice/voice_session_ports.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

const kVoiceMicButtonKey = Key('voice_mic_button');
const kVoiceStatusMessageKey = Key('voice_status_message');
const kVoiceErrorNextActionKey = Key('voice_error_next_action');
const kVoiceCompactStatusKey = Key('voice_compact_status');
const kVoiceReplayButtonKey = Key('voice_replay_button');
const kVoiceStatusCardKey = Key('voice_status_card');
const kVoiceAutoRestartChipKey = Key('voice_auto_restart_chip');
const kVoiceListenPolicyHintKey = Key('voice_listen_policy_hint');
const kVoiceReselectMemberKey = Key('voice_reselect_member');
const kVoicePinnedMemberCardKey = Key('voice_pinned_member_card');
const kVoiceConfirmationPromptKey = Key('voice_confirmation_prompt');
const kVoiceResultPanelKey = Key('voice_result_panel');
const kVoiceResultLineKey = Key('voice_result_line');
const kVoiceResultMetricsKey = Key('voice_result_metrics');
const kVoiceRecoveryExamplesKey = Key('voice_recovery_examples');

const kVoiceMinTouchTarget = 44.0;

enum VoiceState {
  ready,
  listening,
  processing,
  speaking,
  error,
  permissionDenied,
}

/// 명령 완료 응답 데이터에서 카드에 반영할 member/memo 데이터를 추출한다.
///
/// 단일 액션 응답은 data['member']/data['memo']를 그대로 사용하고,
/// 멀티액션 응답(data['steps'])은 단계를 순회하며 마지막으로 회원/메모가
/// 포함된 단계를 각각 독립적으로 유지한다. (memo 없는 후속 회원 단계가
/// 앞선 메모를 null로 덮어쓰지 않도록)
({dynamic member, dynamic memo}) resolveMemberAndMemoData(
  Map<String, dynamic>? data,
) {
  var memberData = data?['member'];
  var memoData = data?['memo'];

  if (memberData == null && data?['steps'] is List) {
    final steps = data!['steps'] as List<dynamic>;
    for (final step in steps) {
      final stepData = (step as Map<String, dynamic>)['data'];
      if (stepData is Map<String, dynamic>) {
        if (stepData['member'] != null) {
          memberData = stepData['member'];
        }
        if (stepData['memo'] != null) {
          memoData = stepData['memo'];
        }
      }
    }
  }

  return (member: memberData, memo: memoData);
}

/// STT가 붙이는 마침표·물음표·공백을 없앤 뒤 비교한다.
String normalizeVoiceUtterance(String text) {
  return text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[.。,，!?？~…·]'), '');
}

/// 다중 후보에서 "첫 번째", "1번", "1" 같은 발화를 1-based 번호로 변환한다.
/// STT는 "첫 번째"처럼 띄어 쓰므로 공백을 제거한 뒤 완전일치한다.
int? parseVoiceSelectionNumber(String text) {
  final normalized = normalizeVoiceUtterance(text);
  if (normalized.isEmpty) return null;

  const numberMap = {
    '1': 1,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    '1번': 1,
    '2번': 2,
    '3번': 3,
    '4번': 4,
    '5번': 5,
    '6번': 6,
    '7번': 7,
    '8번': 8,
    '9번': 9,
    '10번': 10,
    '첫번째': 1,
    '두번째': 2,
    '세번째': 3,
    '네번째': 4,
    '다섯번째': 5,
    '여섯번째': 6,
    '일곱번째': 7,
    '여덟번째': 8,
    '아홉번째': 9,
    '열번째': 10,
    '첫째': 1,
    '둘째': 2,
    '셋째': 3,
    '넷째': 4,
    '다섯째': 5,
    '하나': 1,
    '둘': 2,
    '셋': 3,
    '넷': 4,
    '다섯': 5,
  };

  if (numberMap.containsKey(normalized)) return numberMap[normalized];

  final match = RegExp(r'^(\d+)(번|번째)?$').firstMatch(normalized);
  if (match != null) {
    final parsed = int.tryParse(match.group(1)!);
    if (parsed != null && parsed >= 1 && parsed <= 10) return parsed;
  }

  return null;
}

/// 확인 단계 발화를 수락/거절로만 해석한다.
/// "예약"처럼 '예'가 포함된 일반 말은 null — 파괴 확인으로 치지 않는다.
bool? parseVoiceConfirmation(String text) {
  final normalized = normalizeVoiceUtterance(text);
  if (normalized.isEmpty) return null;

  const rejectExact = {
    '아니',
    '아니요',
    '아니오',
    '아뇨',
    '취소',
    '싫어',
    '싫음',
    '안돼',
    '안됨',
    '안맞어',
    '안맞아',
    '안맞아요',
    '아닌데',
    '노',
    'no',
  };
  const acceptExact = {
    '예',
    '네',
    '응',
    '맞아',
    '맞아요',
    '맞습니다',
    '좋아요',
    '좋아',
    '그래',
    '확인',
    '오케이',
    'ok',
    'yes',
  };

  if (rejectExact.contains(normalized)) return false;
  if (acceptExact.contains(normalized)) return true;
  if (normalized.startsWith('아니')) return false;
  if (normalized.startsWith('취소')) return false;
  return null;
}

/// 잘못된 회원 선택 후 "다른 사람"으로 후보 목록을 되돌린다.
bool parseVoiceMemberReselect(String text) {
  const reselectExact = {
    '아니',
    '아니요',
    '아니오',
    '아뇨',
    '다른회원',
    '다른사람',
    '다른거',
    '다시',
    '다시선택',
    '다시골라',
    '틀렸어',
    '잘못',
    '아닌데',
  };
  return reselectExact.contains(normalizeVoiceUtterance(text));
}

/// API candidates가 List<Map>이 아니어도 화면이 죽지 않게 건다.
List<Map<String, dynamic>> parseVoiceCandidateMaps(dynamic raw) {
  if (raw is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
}

String? voiceCandidateId(Map<String, dynamic> candidate) {
  final id = candidate['id'];
  if (id == null) return null;
  final value = id.toString().trim();
  return value.isEmpty ? null : value;
}

int? parseVoiceMetricInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// 브리핑/홈통계 data에서 스캔할 숫자 필드만 꺼낸다. visits 리스트 길이는 세지 않는다.
List<VoiceMetricField> parseVoiceMetricFields(Map<String, dynamic>? data) {
  if (data == null) return const [];

  const specs = <(List<String>, String, String, String)>[
    (['todayVisits', 'visitCount', 'todayVisitCount'], '방문', '건', 'visit'),
    (['todayReservations', 'reservationCount'], '예약', '건', 'reservation'),
    (['totalMembers', 'memberCount'], '회원', '명', 'member'),
    (['importantMemoCount'], '중요 메모', '개', 'memo'),
  ];

  final out = <VoiceMetricField>[];
  for (final spec in specs) {
    for (final key in spec.$1) {
      if (!data.containsKey(key)) continue;
      final parsed = parseVoiceMetricInt(data[key]);
      if (parsed == null) continue;
      out.add(
        VoiceMetricField(
          key: spec.$4,
          label: spec.$2,
          value: parsed,
          unit: spec.$3,
        ),
      );
      break;
    }
  }
  return out;
}

bool isVoiceBriefingOrStatsUtterance(String text) {
  final normalized = normalizeVoiceUtterance(text);
  return normalized.contains('브리핑') || normalized.contains('통계');
}

bool shouldPinVoiceResultPanel({
  required String userText,
  Map<String, dynamic>? data,
}) {
  if (parseVoiceMetricFields(data).isNotEmpty) return true;
  return isVoiceBriefingOrStatsUtterance(userText);
}

String voiceResultPanelTitle(String userText) {
  final normalized = normalizeVoiceUtterance(userText);
  if (normalized.contains('통계')) return '홈 통계';
  if (normalized.contains('브리핑')) return '오늘 브리핑';
  return '결과';
}

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({
    super.key,
    this.speech,
    this.tts,
    this.permission,
    this.voiceCommandApi,
  });

  final VoiceSpeechPort? speech;
  final VoiceTtsPort? tts;
  final VoicePermissionPort? permission;
  final VoiceCommandApi? voiceCommandApi;

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with TickerProviderStateMixin {
  // Speech & TTS
  late VoiceSpeechPort _speech;
  late VoiceTtsPort _flutterTts;
  late VoicePermissionPort _permission;
  late VoiceCommandApi _voiceApi;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _processingController;
  late Animation<double> _pulseAnimation;

  // Services
  final _memoRepository = MemoRepositoryImpl(MemoService());

  // State
  VoiceState _currentState = VoiceState.ready;
  bool _speechAvailable = false;
  bool _autoRestart = true;
  double _ttsSpeed = 0.5;

  // Voice Recognition
  String _recognizedText = '';
  String _statusMessage = '마이크 버튼을 눌러 시작하세요';
  String? _errorNextAction;
  VoiceErrorGuidance? _lastErrorGuidance;
  bool _disposing = false;
  int _commandEpoch = 0;
  bool _ignoreListenEnd = false;
  String _pendingUserText = '';
  String _lastSpokenText = '';
  String _lastUserCommand = '';
  VoicePinnedResult? _pinnedResult;
  bool _showRecoveryExamples = false;

  // Conversation
  List<Member> _recentMembers = [];
  Member? _currentMember;
  Memo? _currentMemo;
  ConversationContext? _conversationContext;
  List<Map<String, dynamic>> _candidateMembers = [];
  List<Map<String, dynamic>> _candidateMemos = [];
  Set<String> _selectedIds = {};
  bool _isConfirmationStep = false;
  bool _isWaitingForNumberResponse = false;
  String? _lastSearchKeyword;
  List<Map<String, dynamic>> _lastMemberCandidates = [];
  ConversationContext? _lastMemberSelectionContext;
  String? _lastMemberSearchKeyword;

  // Conversation History (for chat UI)
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  final List<CommandExample> _commandExamples = kVoiceOwnerCommandExamples;

  @override
  void initState() {
    super.initState();
    _speech = widget.speech ?? PluginVoiceSpeechPort();
    _flutterTts = widget.tts ?? PluginVoiceTtsPort();
    _permission = widget.permission ?? PluginVoicePermissionPort();
    _voiceApi = widget.voiceCommandApi ?? VoiceCommandServiceApi();
    _initAnimations();
    _checkPermissionsAndInitialize();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  /// 권한 확인 및 초기화
  Future<void> _checkPermissionsAndInitialize() async {
    final outcome = await _permission.requestMicrophoneAndSpeech();
    if (!mounted) return;

    if (outcome == VoicePermissionOutcome.permanentlyDenied) {
      setState(() {
        _currentState = VoiceState.permissionDenied;
        _statusMessage = '마이크 권한이 필요합니다';
        _errorNextAction = '설정에서 마이크 권한을 허용해주세요';
      });
      _showPermissionDeniedDialog();
      return;
    }

    if (outcome == VoicePermissionOutcome.denied) {
      setState(() {
        _currentState = VoiceState.permissionDenied;
        _statusMessage = '마이크 권한이 거부되었습니다';
        _errorNextAction = '설정에서 마이크 권한을 허용해주세요';
      });
      return;
    }

    await _initSpeech();
    await _initTts();
  }

  /// 권한 거부 다이얼로그
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColor.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.mic_off, color: ThemeColor.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('마이크 권한 필요'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '음성 명령 기능을 사용하려면 마이크 권한이 필요합니다.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              '설정에서 마이크 권한을 허용해주세요.',
              style: TextStyle(fontSize: 14, color: ThemeColor.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: ThemeColor.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _permission.openSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || _disposing) return;
          // 엔진이 세션을 닫으면 'notListening' 또는 'done'이 온다.
          // listening 상태로 남아있으면 어느 쪽이든 UI를 ready로 동기화해
          // "종료음은 났는데 UI는 인식중" 불일치를 막는다.
          if ((status == 'done' || status == 'notListening') &&
              _currentState == VoiceState.listening) {
            setState(() {
              _currentState = VoiceState.ready;
              _statusMessage = '음성 인식 완료';
            });
            _stopAnimations();

            if (_ignoreListenEnd) {
              _ignoreListenEnd = false;
              return;
            }

            if (_autoRestart && _recognizedText.isEmpty) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted &&
                    _autoRestart &&
                    _currentState == VoiceState.ready) {
                  _startListening();
                }
              });
            }
          }
        },
        onError: (error) {
          if (!mounted || _disposing) return;
          _stopAnimations();

          // 권한 관련 에러인지 확인
          if (error.errorMsg.toLowerCase().contains('permission')) {
            _speechAvailable = false;
            setState(() {
              _currentState = VoiceState.permissionDenied;
              _statusMessage = '마이크 권한이 거부되었습니다';
              _errorNextAction = '설정에서 마이크 권한을 허용해주세요';
            });
            _showPermissionDeniedDialog();
            return;
          }

          // error_no_match / error_speech_timeout은 발화가 안 잡혔을 뿐인
          // 일상적 에러 — error 화면에 가두지 않고 ready로 복귀시킨다.
          setState(() {
            _currentState = VoiceState.ready;
            _statusMessage = '음성을 인식하지 못했습니다. 다시 말씀해주세요';
          });

          if (_autoRestart) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted &&
                  _autoRestart &&
                  _currentState == VoiceState.ready) {
                _startListening();
              }
            });
          }
        },
      );

      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _currentState = VoiceState.error;
        _statusMessage = '음성 인식을 사용할 수 없습니다';
      });
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(_ttsSpeed);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (!mounted || _disposing) return;
      if (_currentState != VoiceState.speaking) return;
      _stopAnimations();

      final blockingError = _lastErrorGuidance != null &&
          !_lastErrorGuidance!.allowAutoRestart;
      if (blockingError) {
        setState(() {
          _currentState = VoiceState.error;
          _statusMessage = _lastErrorGuidance!.statusMessage;
          _errorNextAction = _lastErrorGuidance!.nextAction;
        });
        return;
      }

      // 완료된 브리핑/검색 직후 500ms listen은 오청취를 만든다.
      // 이어지는 대화(번호·확인)와 회복 가능한 에러만 자동 재청취한다.
      final shouldRestart = _shouldAutoRestartListening();
      _lastErrorGuidance = null;
      setState(() {
        _currentState = VoiceState.ready;
        _statusMessage = '명령을 기다리고 있습니다';
      });

      if (shouldRestart) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted &&
              _autoRestart &&
              _currentState == VoiceState.ready) {
            _startListening();
          }
        });
      }
    });
  }

  bool _shouldAutoRestartListening() {
    if (!_autoRestart) return false;
    if (_lastErrorGuidance != null && !_lastErrorGuidance!.allowAutoRestart) {
      return false;
    }
    if (_isWaitingForNumberResponse || _isConfirmationStep) return true;
    if (_conversationContext != null) return true;
    if (_lastErrorGuidance != null && _lastErrorGuidance!.allowAutoRestart) {
      return true;
    }
    return false;
  }

  void _stopAnimations() {
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();
  }

  Future<void> _speak(String text, {bool addToChat = true}) async {
    if (!mounted || _disposing) return;
    if (text.isEmpty) {
      if (_currentState == VoiceState.processing) {
        setState(() {
          _currentState = VoiceState.ready;
          _statusMessage = '명령을 기다리고 있습니다';
        });
      }
      return;
    }

    if (addToChat) {
      _addChatMessage(text, isUser: false);
    }
    _lastSpokenText = text;

    setState(() {
      _currentState = VoiceState.speaking;
      _statusMessage = text;
    });

    if (_speech.isListening) {
      await _speech.stop();
    }

    _pulseController.repeat(reverse: true);
    await _flutterTts.speak(text);
  }

  bool _isCurrentEpoch(int epoch) =>
      mounted && !_disposing && epoch == _commandEpoch;

  bool get _canReselectMember =>
      _lastMemberCandidates.isNotEmpty &&
      _lastMemberSelectionContext != null &&
      !_isWaitingForNumberResponse &&
      !_isConfirmationStep &&
      _currentMember != null &&
      _conversationContext == null;

  bool get _shouldShowRecoveryExamples =>
      _showRecoveryExamples &&
      _chatMessages.isNotEmpty &&
      _candidateMembers.isEmpty &&
      _candidateMemos.isEmpty &&
      !_isConfirmationStep;

  Future<void> _replayLastSpeech() async {
    if (_lastSpokenText.isEmpty) return;
    if (_currentState == VoiceState.processing ||
        _currentState == VoiceState.permissionDenied) {
      return;
    }
    if (_currentState == VoiceState.listening) {
      _ignoreListenEnd = true;
      if (_speech.isListening) {
        await _speech.stop();
      }
      if (!mounted || _disposing) return;
      _stopAnimations();
      setState(() {
        _currentState = VoiceState.ready;
      });
    }
    if (_currentState != VoiceState.ready &&
        _currentState != VoiceState.error) {
      return;
    }
    await _speak(_lastSpokenText, addToChat: false);
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _showPermissionDeniedDialog();
      return;
    }

    if (_currentState == VoiceState.permissionDenied) {
      _showPermissionDeniedDialog();
      return;
    }

    if (_currentState != VoiceState.ready) return;

    setState(() {
      _currentState = VoiceState.listening;
      _recognizedText = '';
      _pendingUserText = '';
      _statusMessage = '듣고 있습니다...';
      _errorNextAction = null;
      _lastErrorGuidance = null;
    });

    _waveController.repeat();
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted || _disposing) return;
        setState(() {
          _recognizedText = result.recognizedWords;
          if (_recognizedText.isNotEmpty) {
            _statusMessage = '"$_recognizedText"';
            _pendingUserText = _recognizedText;
          }
        });

        if (_pendingUserText.isNotEmpty) {
          _scrollToBottom();
        }

        if (result.finalResult && _recognizedText.isNotEmpty) {
          _processVoiceCommand(_recognizedText);
        }
      },
    );
  }

  void _stopListening() async {
    _ignoreListenEnd = true;
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() {
      _currentState = VoiceState.ready;
      _statusMessage = '음성 인식 중지됨';
      _pendingUserText = '';
    });
    _stopAnimations();
  }

  Future<void> _stopTtsAndStartListening() async {
    await _flutterTts.stop();
    _stopAnimations();

    setState(() {
      _currentState = VoiceState.ready;
      _statusMessage = _isWaitingForNumberResponse
          ? '번호로 대답해주세요'
          : '명령을 기다리고 있습니다';
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && _currentState == VoiceState.ready) {
      _startListening();
    }
  }

  void _addChatMessage(String text, {required bool isUser}) {
    setState(() {
      _chatMessages.add(
        ChatMessage(text: text, isUser: isUser, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _disposing) return;
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processVoiceCommand(String text) async {
    if (_currentState == VoiceState.processing) return;
    final epoch = ++_commandEpoch;

    // 실시간 입력 버블 제거 후 확정 메시지로 추가
    setState(() {
      _pendingUserText = '';
      _lastUserCommand = text;
      _showRecoveryExamples = false;
    });
    _addChatMessage(text, isUser: true);

    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = '분석 중...';
    });
    _stopAnimations();

    // 번호 응답 대기 중인 경우
    if (_isWaitingForNumberResponse) {
      await _handleNumberResponse(text);
      return;
    }

    if (_isConfirmationStep) {
      final confirmed = _isConfirmationResponse(text);
      if (confirmed != null) {
        await _handleConfirmationResponse(confirmed);
        return;
      }
      await _speak('예 또는 아니오로 대답해주세요.');
      return;
    }

    if (_canReselectMember && parseVoiceMemberReselect(text)) {
      await _restoreMemberCandidates();
      return;
    }

    try {
      final userViewModel = context.read<UserViewModel>();
      final userId = userViewModel.user?.providerId;

      final response = await _voiceApi.sendVoiceCommand(
        text: text,
        context: _conversationContext,
        userId: userId,
      );
      if (!_isCurrentEpoch(epoch)) return;

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else {
        await _presentVoiceError(
          response.errorCode,
          fallbackMessage: response.message,
        );
      }
    } on VoiceCommandException catch (e) {
      if (!_isCurrentEpoch(epoch)) return;
      await _presentVoiceError(e.errorCode, fallbackMessage: e.message);
    } catch (e, stackTrace) {
      if (!_isCurrentEpoch(epoch)) return;
      if (mounted) {
        final userViewModel = context.read<UserViewModel>();
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'VoiceCommandScreen',
          action: '명령 실행',
          userId: userViewModel.user?.id,
        );
      }
      await _presentVoiceError(
        null,
        fallbackMessage: '명령 처리 중 오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }

  Future<void> _presentVoiceError(
    String? errorCode, {
    String? fallbackMessage,
  }) async {
    final guidance = resolveVoiceErrorGuidance(
      errorCode: errorCode,
      fallbackMessage: fallbackMessage,
    );
    _lastErrorGuidance = guidance;
    if (!mounted) return;
    setState(() {
      _errorNextAction = guidance.nextAction;
      _statusMessage = guidance.statusMessage;
      _showRecoveryExamples = true;
    });
    await _speak('${guidance.statusMessage} ${guidance.nextAction}');
  }

  bool? _isConfirmationResponse(String text) => parseVoiceConfirmation(text);

  Future<void> _handleNumberResponse(String text) async {
    final candidates = _candidateMembers.isNotEmpty
        ? _candidateMembers
        : _candidateMemos;

    if (candidates.isEmpty) {
      setState(() => _isWaitingForNumberResponse = false);
      await _speak('선택할 항목이 없습니다.');
      return;
    }

    final number = _parseNumberFromText(text);

    if (number == null || number < 1 || number > candidates.length) {
      await _speak('1부터 ${candidates.length}까지 번호로 말씀해주세요.');
      return;
    }

    final selectedId = voiceCandidateId(candidates[number - 1]);
    if (selectedId == null) {
      await _speak('선택한 항목 정보가 없습니다. 다른 번호로 말씀해주세요.');
      return;
    }

    setState(() {
      _isWaitingForNumberResponse = false;
      _lastSearchKeyword = null;
    });

    await _submitSelection([selectedId]);
  }

  Future<void> _handleClarificationNeeded(VoiceCommandResponse response) async {
    final currentStepType = response.context?.currentStep?.stepType;

    if (currentStepType == 'confirmation') {
      setState(() {
        _isConfirmationStep = true;
        _isWaitingForNumberResponse = false;
        _conversationContext = response.context;
      });
      await _speak(response.message);
      return;
    }

    if (currentStepType == 'content_input') {
      setState(() {
        _isConfirmationStep = false;
        _isWaitingForNumberResponse = false;
        _conversationContext = response.context;
      });
      _addChatMessage(response.message, isUser: false);
      await _speak(response.message);
      return;
    }

    final candidates = parseVoiceCandidateMaps(response.data?['candidates']);

    if (candidates.isEmpty) {
      await _speak('정보를 찾을 수 없습니다. 마이크를 눌러 다시 검색해 주세요.');
      return;
    }

    final searchKeyword = response.data?['searchKeyword'] as String?;

    setState(() {
      _isConfirmationStep = false;
      _isWaitingForNumberResponse = true;
      _lastSearchKeyword = searchKeyword;

      if (response.isMemberSelection) {
        _candidateMembers = candidates;
        _candidateMemos = [];
        _lastMemberCandidates = List<Map<String, dynamic>>.from(candidates);
        _lastMemberSelectionContext = response.context;
        _lastMemberSearchKeyword = searchKeyword;
      } else if (response.isMemoSelection) {
        _candidateMemos = candidates;
        _candidateMembers = [];
      } else {
        _candidateMembers = candidates;
        _candidateMemos = [];
      }

      _conversationContext = response.context;
      _selectedIds.clear();
    });

    final entityType = response.isMemberSelection ? 'member' : 'memo';
    final ttsMessage = _buildCandidateTtsMessage(entityType);
    await _speak(ttsMessage);
  }

  Future<void> _handleCommandCompleted(VoiceCommandResponse response) async {
    setState(() {
      _conversationContext = null;
      _candidateMembers = [];
      _candidateMemos = [];
      _isConfirmationStep = false;
      _isWaitingForNumberResponse = false;
    });

    final resolved = resolveMemberAndMemoData(response.data);
    final memberData = resolved.member;
    final memoData = resolved.memo;

    if (memberData != null) {
      final member = Member.fromJson(memberData as Map<String, dynamic>);
      setState(() {
        _currentMember = member;

        if (!_recentMembers.any((m) => m.id == member.id)) {
          _recentMembers.insert(0, member);
          if (_recentMembers.length > 5) {
            _recentMembers.removeLast();
          }
        }

        if (memoData != null) {
          _currentMemo = Memo.fromJson(memoData as Map<String, dynamic>);
        } else {
          _currentMemo = null;
        }
      });
    }

    final metrics = parseVoiceMetricFields(response.data);
    final pinBriefing = memberData == null &&
        shouldPinVoiceResultPanel(
          userText: _lastUserCommand,
          data: response.data,
        ) &&
        (response.message.isNotEmpty || metrics.isNotEmpty);

    setState(() {
      _showRecoveryExamples = false;
      _pinnedResult = pinBriefing
          ? VoicePinnedResult(
              title: voiceResultPanelTitle(_lastUserCommand),
              spokenText: response.message,
              metrics: metrics,
            )
          : null;
    });

    await _speak(response.message, addToChat: !pinBriefing);
  }

  Future<void> _selectCandidate(Map<String, dynamic> candidate) async {
    final id = voiceCandidateId(candidate);
    if (id == null) {
      await _speak('선택한 항목 정보가 없습니다. 다른 번호로 말씀해주세요.');
      return;
    }
    final selectionOptions = _conversationContext?.currentStep;

    if (_currentState == VoiceState.speaking) {
      await _flutterTts.stop();
      _stopAnimations();
    }

    setState(() {
      _isWaitingForNumberResponse = false;
      _lastSearchKeyword = null;
    });

    if (selectionOptions?.allowMultipleSelection == true) {
      setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });
      return;
    }

    await _submitSelection([id]);
  }

  Future<void> _submitSelection(
    List<String> selectedIds, {
    bool selectAll = false,
  }) async {
    final epoch = ++_commandEpoch;
    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = '분석 중...';
    });

    try {
      final entityType =
          _conversationContext?.currentStep?.targetEntityType ?? 'unknown';

      final selectedEntity = {
        'entityType': entityType,
        'ids': selectedIds,
        'selectAll': selectAll,
      };

      final selectedEntities = List<Map<String, dynamic>>.from(
        _conversationContext?.selectedEntities
                .map((e) => e.toJson())
                .toList() ??
            [],
      );
      selectedEntities.add(selectedEntity);

      final updatedContext = _conversationContext?.copyWith(
        selectedEntities: selectedEntities.map((json) {
          return SelectedEntity(
            entityType: json['entityType'] as String,
            ids: (json['ids'] as List<dynamic>).cast<String>(),
            selectAll: json['selectAll'] as bool? ?? false,
          );
        }).toList(),
      );

      final userViewModel = context.read<UserViewModel>();
      final userId = userViewModel.user?.providerId;

      final response = await _voiceApi.sendVoiceCommand(
        text: selectAll ? '전체' : selectedIds.join(','),
        context: updatedContext,
        userId: userId,
      );
      if (!_isCurrentEpoch(epoch)) return;

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else {
        await _presentVoiceError(
          response.errorCode,
          fallbackMessage: response.message,
        );
      }
    } on VoiceCommandException catch (e) {
      if (!_isCurrentEpoch(epoch)) return;
      await _presentVoiceError(e.errorCode, fallbackMessage: e.message);
    } catch (e, stackTrace) {
      if (!_isCurrentEpoch(epoch)) return;
      if (mounted) {
        final userViewModel = context.read<UserViewModel>();
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'VoiceCommandScreen',
          action: '명령 실행',
          userId: userViewModel.user?.id,
        );
      }
      await _presentVoiceError(
        null,
        fallbackMessage: '선택 처리 중 오류가 발생했습니다.',
      );
    }
  }

  Future<void> _handleConfirmationResponse(bool confirmed) async {
    final epoch = ++_commandEpoch;
    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = confirmed ? '진행 중...' : '취소 중...';
    });

    try {
      final userViewModel = context.read<UserViewModel>();
      final userId = userViewModel.user?.providerId;

      final response = await _voiceApi.sendVoiceCommand(
        text: confirmed ? '예' : '아니오',
        context: _conversationContext,
        userId: userId,
      );
      if (!_isCurrentEpoch(epoch)) return;

      setState(() => _isConfirmationStep = false);

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else {
        await _presentVoiceError(
          response.errorCode,
          fallbackMessage: response.message,
        );
      }
    } on VoiceCommandException catch (e) {
      if (!_isCurrentEpoch(epoch)) return;
      setState(() => _isConfirmationStep = false);
      await _presentVoiceError(e.errorCode, fallbackMessage: e.message);
    } catch (e, stackTrace) {
      if (!_isCurrentEpoch(epoch)) return;
      if (mounted) {
        final userViewModel = context.read<UserViewModel>();
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'VoiceCommandScreen',
          action: '명령 실행',
          userId: userViewModel.user?.id,
        );
      }
      await _presentVoiceError(
        null,
        fallbackMessage: '확인 처리 중 오류가 발생했습니다.',
      );
      setState(() => _isConfirmationStep = false);
    }
  }

  Future<void> _restoreMemberCandidates() async {
    if (_lastMemberCandidates.isEmpty || _lastMemberSelectionContext == null) {
      await _speak('다시 고를 회원 목록이 없습니다.');
      return;
    }

    if (_currentState == VoiceState.speaking) {
      await _flutterTts.stop();
      _stopAnimations();
    }

    setState(() {
      _candidateMembers = List<Map<String, dynamic>>.from(
        _lastMemberCandidates,
      );
      _candidateMemos = [];
      _conversationContext = _lastMemberSelectionContext;
      _isWaitingForNumberResponse = true;
      _isConfirmationStep = false;
      _lastSearchKeyword = _lastMemberSearchKeyword;
      _currentMember = null;
      _currentMemo = null;
      _selectedIds.clear();
      _currentState = VoiceState.ready;
    });

    await _speak('번호로 다시 선택해주세요.');
  }

  void _cancelConversation() {
    _commandEpoch++;
    _ignoreListenEnd = true;
    _flutterTts.stop();
    if (_speech.isListening) _speech.stop();
    _stopAnimations();

    setState(() {
      _conversationContext = null;
      _candidateMembers = [];
      _candidateMemos = [];
      _selectedIds.clear();
      _isConfirmationStep = false;
      _isWaitingForNumberResponse = false;
      _lastSearchKeyword = null;
      _lastMemberCandidates = [];
      _lastMemberSelectionContext = null;
      _lastMemberSearchKeyword = null;
      _currentMember = null;
      _currentMemo = null;
      _pendingUserText = '';
      _lastSpokenText = '';
      _lastUserCommand = '';
      _pinnedResult = null;
      _showRecoveryExamples = false;
      _chatMessages.clear();
      _currentState = VoiceState.ready;
      _statusMessage = '마이크 버튼을 눌러 시작하세요';
      _errorNextAction = null;
      _lastErrorGuidance = null;
    });
  }

  void _clearChat() {
    setState(() {
      _chatMessages.clear();
      _currentMember = null;
      _currentMemo = null;
      _pendingUserText = '';
    });
  }

  int? _parseNumberFromText(String text) => parseVoiceSelectionNumber(text);

  String _buildCandidateTtsMessage(String entityType) {
    final candidates = entityType == 'member'
        ? _candidateMembers
        : _candidateMemos;
    if (candidates.isEmpty) return '';

    final buffer = StringBuffer();

    if (entityType == 'member') {
      if (_lastSearchKeyword != null) {
        buffer.write('$_lastSearchKeyword 회원이 ${candidates.length}명 있습니다. ');
      } else {
        buffer.write('회원이 ${candidates.length}명 있습니다. ');
      }
      buffer.write('번호로 선택해주세요. ');

      for (int i = 0; i < candidates.length; i++) {
        final name = candidates[i]['name'] as String? ?? '이름 없음';
        buffer.write('${i + 1}번 $name');
        if (i < candidates.length - 1) buffer.write(', ');
      }
    } else {
      buffer.write('메모가 ${candidates.length}건 있습니다. 번호로 선택해주세요. ');

      for (int i = 0; i < candidates.length; i++) {
        final content = candidates[i]['content'] as String? ?? '내용 없음';
        final truncated = content.length > 20
            ? '${content.substring(0, 20)}...'
            : content;
        buffer.write('${i + 1}번 $truncated');
        if (i < candidates.length - 1) buffer.write(', ');
      }
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    _disposing = true;
    _speech.stop();
    _flutterTts.stop();
    _pulseController.dispose();
    _waveController.dispose();
    _processingController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        backgroundColor: ThemeColor.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        title: Builder(
          builder: (context) {
            final screenHeight = MediaQuery.of(context).size.height;
            return Image.asset(
              'assets/images/app_logo2.png',
              height: screenHeight * 0.04,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child:
                  _chatMessages.isEmpty &&
                      _pendingUserText.isEmpty &&
                      _candidateMembers.isEmpty &&
                      _candidateMemos.isEmpty
                  ? _buildEmptyState()
                  : _buildChatView(),
            ),
            if (_pinnedResult != null) _buildPinnedResultPanel(),
            if (_currentMember != null) _buildMemberInfoCard(),
            if (_shouldShowRecoveryExamples) _buildRecoveryExamples(),
            if (_candidateMembers.isNotEmpty || _candidateMemos.isNotEmpty)
              _buildCandidateSelector(),
            if (_isConfirmationStep) _buildConfirmationButtons(),
            _buildVoiceControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final hasActiveConversation =
        _conversationContext != null ||
        _candidateMembers.isNotEmpty ||
        _candidateMemos.isNotEmpty ||
        _isConfirmationStep ||
        _chatMessages.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        border: Border(bottom: BorderSide(color: ThemeColor.border, width: screenWidth * 0.0025)),
      ),
      child: Row(
        children: [
          // 타이틀 또는 취소 버튼
          if (hasActiveConversation)
            GestureDetector(
              onTap: _cancelConversation,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.03,
                  vertical: screenHeight * 0.008,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.errorSurface,
                  borderRadius: BorderRadius.circular(screenWidth * 0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: screenWidth * 0.04, color: ThemeColor.error),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      '처음으로',
                      style: TextStyle(
                        fontSize: screenWidth * 0.033,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.error,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: ThemeColor.primarySurface,
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                  child: Icon(Icons.mic, size: screenWidth * 0.05, color: ThemeColor.primary),
                ),
                SizedBox(width: screenWidth * 0.03),
                Text(
                  '음성 명령',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.textPrimary,
                  ),
                ),
              ],
            ),

          const Spacer(),

          // 설정 버튼들
          _buildSettingChip(
            key: kVoiceAutoRestartChipKey,
            icon: Icons.repeat,
            label: _autoRestart ? '대화만' : '수동',
            isActive: _autoRestart,
            semanticLabel: _autoRestart
                ? '자동 듣기: 번호와 확인만. 브리핑 뒤에는 마이크를 누르세요'
                : '자동 듣기 꺼짐. 말할 때마다 마이크를 누르세요',
            onTap: () {
              setState(() => _autoRestart = !_autoRestart);
              if (_autoRestart &&
                  _currentState == VoiceState.ready &&
                  _shouldAutoRestartListening()) {
                _startListening();
              }
            },
          ),
          SizedBox(width: screenWidth * 0.02),
          _buildSpeedSelector(),
        ],
      ),
    );
  }

  Widget _buildSettingChip({
    Key? key,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kVoiceMinTouchTarget,
            minWidth: kVoiceMinTouchTarget,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? ThemeColor.primarySurface : ThemeColor.neutral100,
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: screenWidth * 0.035,
                  color: isActive ? ThemeColor.primary : ThemeColor.textTertiary,
                ),
                SizedBox(width: screenWidth * 0.01),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.w600,
                    color: isActive ? ThemeColor.primary : ThemeColor.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return PopupMenuButton<double>(
      offset: Offset(0, screenHeight * 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.03)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kVoiceMinTouchTarget,
          minWidth: kVoiceMinTouchTarget,
        ),
        child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ThemeColor.neutral100,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: screenWidth * 0.035, color: ThemeColor.textTertiary),
            SizedBox(width: screenWidth * 0.01),
            Text(
              _ttsSpeed == 0.3
                  ? '느리게'
                  : _ttsSpeed == 0.7
                  ? '빠르게'
                  : '보통',
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                fontWeight: FontWeight.w600,
                color: ThemeColor.textTertiary,
              ),
            ),
          ],
        ),
        ),
      ),
      onSelected: (speed) async {
        setState(() => _ttsSpeed = speed);
        await _flutterTts.setSpeechRate(speed);
      },
      itemBuilder: (context) => [
        _buildSpeedMenuItem(0.3, '느리게'),
        _buildSpeedMenuItem(0.5, '보통'),
        _buildSpeedMenuItem(0.7, '빠르게'),
      ],
    );
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double speed, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    return PopupMenuItem(
      value: speed,
      child: Row(
        children: [
          Icon(
            _ttsSpeed == speed ? Icons.check_circle : Icons.circle_outlined,
            size: screenWidth * 0.045,
            color: _ttsSpeed == speed
                ? ThemeColor.primary
                : ThemeColor.textTertiary,
          ),
          SizedBox(width: screenWidth * 0.02),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: screenWidth * 0.05,
        bottom: screenWidth * 0.05,
      ),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.025),

          // 상태 표시 카드
          _buildStatusCard(),

          SizedBox(height: screenHeight * 0.03),

          _buildCommandExamplesCard(showListenHint: true),

          // 최근 조회 회원
          if (_recentMembers.isNotEmpty) ...[
            SizedBox(height: screenHeight * 0.03),
            _buildRecentMembers(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (_currentState) {
      case VoiceState.listening:
        bgColor = ThemeColor.successSurface;
        iconColor = ThemeColor.success;
        icon = Icons.mic;
        break;
      case VoiceState.speaking:
        bgColor = ThemeColor.infoSurface;
        iconColor = ThemeColor.info;
        icon = Icons.volume_up;
        break;
      case VoiceState.processing:
        bgColor = ThemeColor.warningSurface;
        iconColor = ThemeColor.warning;
        icon = Icons.hourglass_empty;
        break;
      case VoiceState.error:
      case VoiceState.permissionDenied:
        bgColor = ThemeColor.errorSurface;
        iconColor = ThemeColor.error;
        icon = Icons.error_outline;
        break;
      default:
        bgColor = ThemeColor.primarySurface;
        iconColor = ThemeColor.primary;
        icon = Icons.mic_none;
    }

    return GestureDetector(
      key: kVoiceStatusCardKey,
      onTap: () {
        if (_currentState == VoiceState.ready) {
          _startListening();
        } else if (_currentState == VoiceState.error ||
            _currentState == VoiceState.permissionDenied) {
          _handleMicButtonTap();
        }
      },
      child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: screenWidth * 0.2,
            height: screenWidth * 0.2,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: _currentState == VoiceState.processing
                ? RotationTransition(
                    turns: _processingController,
                    child: Icon(icon, size: screenWidth * 0.1, color: iconColor),
                  )
                : Icon(icon, size: screenWidth * 0.1, color: iconColor),
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _statusMessage,
            key: kVoiceStatusMessageKey,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
          if (_errorNextAction != null) ...[
            SizedBox(height: screenHeight * 0.01),
            Text(
              _errorNextAction!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.033,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
          if (_currentState == VoiceState.permissionDenied) ...[
            SizedBox(height: screenHeight * 0.015),
            ElevatedButton.icon(
              onPressed: _showPermissionDeniedDialog,
              icon: Icon(Icons.settings, size: screenWidth * 0.045),
              label: const Text('권한 설정'),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildRecentMembers() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: screenWidth * 0.045, color: ThemeColor.textSecondary),
              SizedBox(width: screenWidth * 0.02),
              Text(
                '최근 조회',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Wrap(
            spacing: screenWidth * 0.02,
            runSpacing: screenHeight * 0.01,
            children: _recentMembers.map((member) {
              return GestureDetector(
                onTap: () => _selectRecentMember(member),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.neutral50,
                    borderRadius: BorderRadius.circular(screenWidth * 0.05),
                    border: Border.all(color: ThemeColor.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.03,
                        backgroundColor: ThemeColor.primarySurface,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0] : '?',
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        member.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.033,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _selectRecentMember(Member member) async {
    setState(() {
      _currentMember = member;
      _currentState = VoiceState.processing;
      _statusMessage = '정보 로딩 중...';
    });

    try {
      final memo = await _memoRepository.getLatestMemoByMemberId(member.id);
      setState(() => _currentMemo = memo);

      String message = '${member.name} 회원님 정보입니다. ';
      if (memo != null) {
        message += '최신 메모: ${memo.content}';
      } else {
        message += '등록된 메모가 없습니다.';
      }

      await _speak(message);
    } catch (e) {
      setState(() => _currentMemo = null);
      await _speak('${member.name} 회원님 정보입니다. 등록된 메모가 없습니다.');
    }
  }

  Widget _buildChatView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final hasPending = _pendingUserText.isNotEmpty;
    final pendingOffset = hasPending ? 1 : 0;
    final totalCount = _chatMessages.length + pendingOffset;

    return ListView.builder(
      controller: _chatScrollController,
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: screenWidth * 0.04,
        bottom: screenWidth * 0.04,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (hasPending && index == _chatMessages.length) {
          return _buildPendingBubble();
        }

        final message = _chatMessages[index];
        return _buildChatBubble(message);
      },
    );
  }

  Widget _buildCommandExamplesCard({
    Key? key,
    bool showListenHint = false,
    bool compact = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final pad = compact ? screenWidth * 0.035 : screenWidth * 0.05;

    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: screenWidth * 0.05,
                color: ThemeColor.warning,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                '이렇게 말해보세요',
                style: TextStyle(
                  fontSize: screenWidth * 0.0375,
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? screenHeight * 0.012 : screenHeight * 0.02),
          ...List.generate(_commandExamples.length, (index) {
            final example = _commandExamples[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _commandExamples.length - 1
                    ? (compact ? screenHeight * 0.008 : screenHeight * 0.015)
                    : 0,
              ),
              child: GestureDetector(
                onTap: () => _processVoiceCommand(example.text),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: compact ? screenHeight * 0.008 : screenHeight * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.neutral50,
                    borderRadius: BorderRadius.circular(screenWidth * 0.025),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.015),
                        decoration: BoxDecoration(
                          color: ThemeColor.primarySurface,
                          borderRadius: BorderRadius.circular(screenWidth * 0.015),
                        ),
                        child: Icon(
                          example.icon,
                          size: screenWidth * 0.04,
                          color: ThemeColor.primary,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Expanded(
                        child: Text(
                          '"${example.text}"',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: screenHeight * 0.003,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColor.accentSurface,
                          borderRadius: BorderRadius.circular(screenWidth * 0.01),
                        ),
                        child: Text(
                          example.category,
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.w500,
                            color: ThemeColor.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (showListenHint) ...[
            SizedBox(height: screenHeight * 0.015),
            Text(
              '브리핑을 들은 뒤에는 마이크를 누르세요. 회원 번호와 예/아니오는 자동으로 듣습니다.',
              key: kVoiceListenPolicyHintKey,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                height: 1.4,
                color: ThemeColor.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinnedResultPanel() {
    final result = _pinnedResult;
    if (result == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final canReplay = _lastSpokenText.isNotEmpty &&
        _currentState != VoiceState.processing &&
        _currentState != VoiceState.permissionDenied &&
        _currentState != VoiceState.speaking;

    return Container(
      key: kVoiceResultPanelKey,
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        0,
        screenWidth * 0.04,
        screenHeight * 0.01,
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            style: TextStyle(
              fontSize: screenWidth * 0.033,
              fontWeight: FontWeight.w700,
              color: ThemeColor.textSecondary,
            ),
          ),
          SizedBox(height: screenHeight * 0.012),
          if (result.metrics.isNotEmpty)
            KeyedSubtree(
              key: kVoiceResultMetricsKey,
              child: Row(
                children: [
                  for (var i = 0; i < result.metrics.length; i++) ...[
                    if (i > 0) SizedBox(width: screenWidth * 0.02),
                    Expanded(child: _buildMetricCard(result.metrics[i])),
                  ],
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.spokenText,
                    key: kVoiceResultLineKey,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: screenWidth * 0.0375,
                      height: 1.4,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                ),
                if (canReplay) ...[
                  SizedBox(width: screenWidth * 0.02),
                  Semantics(
                    button: true,
                    label: '다시 듣기',
                    child: GestureDetector(
                      onTap: _replayLastSpeech,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kVoiceMinTouchTarget,
                          minWidth: kVoiceMinTouchTarget,
                        ),
                        child: Icon(
                          Icons.replay,
                          color: ThemeColor.primary,
                          size: screenWidth * 0.055,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(VoiceMetricField field) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.012,
        horizontal: screenWidth * 0.01,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.neutral50,
        borderRadius: BorderRadius.circular(screenWidth * 0.025),
      ),
      child: Column(
        children: [
          Text(
            '${field.value}${field.unit}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w700,
              color: ThemeColor.textPrimary,
            ),
          ),
          SizedBox(height: screenHeight * 0.004),
          Text(
            field.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryExamples() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        0,
        screenWidth * 0.04,
        screenHeight * 0.01,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.32),
        child: SingleChildScrollView(
          child: _buildCommandExamplesCard(
            key: kVoiceRecoveryExamplesKey,
            compact: true,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInfoCard() {
    if (_currentMember == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      key: kVoicePinnedMemberCardKey,
      margin: EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        0,
        screenWidth * 0.04,
        screenHeight * 0.01,
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        border: Border.all(color: ThemeColor.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowLight,
            blurRadius: screenWidth * 0.02,
            offset: Offset(0, screenHeight * 0.002),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: screenWidth * 0.06,
                backgroundColor: ThemeColor.primarySurface,
                child: Text(
                  _currentMember!.name.isNotEmpty
                      ? _currentMember!.name[0]
                      : '?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primary,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentMember!.name,
                      style: TextStyle(
                        fontSize: screenWidth * 0.043,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                      ),
                    ),
                    if (_currentMember!.memberNumber != null)
                      Text(
                        '회원번호: ${_currentMember!.memberNumber}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.033,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.025,
                      vertical: screenHeight * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: ThemeColor.successSurface,
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                    child: Text(
                      _currentMember!.grade ?? '일반',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.success,
                      ),
                    ),
                  ),
                  if (_canReselectMember) ...[
                    SizedBox(height: screenHeight * 0.008),
                    GestureDetector(
                      key: kVoiceReselectMemberKey,
                      onTap: _restoreMemberCandidates,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kVoiceMinTouchTarget,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '다른 회원',
                            style: TextStyle(
                              fontSize: screenWidth * 0.033,
                              fontWeight: FontWeight.w600,
                              color: ThemeColor.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (_currentMember!.phone != null) ...[
            SizedBox(height: screenHeight * 0.015),
            Row(
              children: [
                Icon(Icons.phone, size: screenWidth * 0.04, color: ThemeColor.textTertiary),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  _currentMember!.phone!,
                  style: TextStyle(fontSize: screenWidth * 0.035),
                ),
              ],
            ),
          ],
          if (_currentMemo != null) ...[
            Divider(height: screenHeight * 0.03),
            Row(
              children: [
                Icon(Icons.note, size: screenWidth * 0.04, color: ThemeColor.warning),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  '최신 메모',
                  style: TextStyle(fontSize: screenWidth * 0.033, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.01),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: ThemeColor.warningSurface,
                borderRadius: BorderRadius.circular(screenWidth * 0.02),
              ),
              child: Text(
                _currentMemo!.content,
                style: TextStyle(fontSize: screenWidth * 0.035),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.015),
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? ThemeColor.primary : ThemeColor.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(screenWidth * 0.04),
            topRight: Radius.circular(screenWidth * 0.04),
            bottomLeft: Radius.circular(message.isUser ? screenWidth * 0.04 : screenWidth * 0.01),
            bottomRight: Radius.circular(message.isUser ? screenWidth * 0.01 : screenWidth * 0.04),
          ),
          border: message.isUser ? null : Border.all(color: ThemeColor.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: screenWidth * 0.0375,
            color: message.isUser ? Colors.white : ThemeColor.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBubble() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.015),
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.015),
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.75,
        ),
        decoration: BoxDecoration(
          color: ThemeColor.primary.withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(screenWidth * 0.04),
            topRight: Radius.circular(screenWidth * 0.04),
            bottomLeft: Radius.circular(screenWidth * 0.04),
            bottomRight: Radius.circular(screenWidth * 0.01),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _pendingUserText,
                style: TextStyle(
                  fontSize: screenWidth * 0.0375,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.02),
            SizedBox(
              width: screenWidth * 0.03,
              height: screenWidth * 0.03,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final candidates = _candidateMembers.isNotEmpty
        ? _candidateMembers
        : _candidateMemos;
    final isMember = _candidateMembers.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        border: Border(top: BorderSide(color: ThemeColor.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMember ? Icons.people : Icons.note,
                size: screenWidth * 0.045,
                color: ThemeColor.primary,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                isMember ? '회원 선택' : '메모 선택',
                style: TextStyle(
                  fontSize: screenWidth * 0.0375,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${candidates.length}건',
                style: TextStyle(fontSize: screenWidth * 0.033, color: ThemeColor.textSecondary),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          SizedBox(
            height: screenHeight * 0.12,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => SizedBox(width: screenWidth * 0.025),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final isSelected = _selectedIds.contains(candidate['id']);

                return GestureDetector(
                  onTap: () => _selectCandidate(candidate),
                  child: Container(
                    width: screenWidth * 0.35,
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ThemeColor.primarySurface
                          : ThemeColor.neutral50,
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      border: Border.all(
                        color: isSelected
                            ? ThemeColor.primary
                            : ThemeColor.border,
                        width: isSelected ? screenWidth * 0.005 : screenWidth * 0.0025,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: screenWidth * 0.06,
                              height: screenWidth * 0.06,
                              decoration: BoxDecoration(
                                color: ThemeColor.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                size: screenWidth * 0.045,
                                color: ThemeColor.primary,
                              ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Text(
                          isMember
                              ? candidate['name'] as String? ?? '이름 없음'
                              : (candidate['content'] as String? ?? '내용 없음')
                                        .length >
                                    15
                              ? '${(candidate['content'] as String).substring(0, 15)}...'
                              : candidate['content'] as String? ?? '내용 없음',
                          style: TextStyle(
                            fontSize: screenWidth * 0.033,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isMember && candidate['memberNumber'] != null)
                          Text(
                            '${candidate['memberNumber']}번',
                            style: TextStyle(
                              fontSize: screenWidth * 0.028,
                              color: ThemeColor.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final prompt = _lastSpokenText.isNotEmpty
        ? _lastSpokenText
        : '이 작업을 진행할까요?';
    final isDestructive = prompt.contains('삭제');
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        border: Border(top: BorderSide(color: ThemeColor.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            key: kVoiceConfirmationPromptKey,
            style: TextStyle(
              fontSize: screenWidth * 0.033,
              fontWeight: FontWeight.w600,
              color: ThemeColor.textPrimary,
            ),
          ),
          SizedBox(height: screenHeight * 0.012),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleConfirmationResponse(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(kVoiceMinTouchTarget),
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                    side: BorderSide(color: ThemeColor.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                  ),
                  child: Text(
                    '아니오',
                    style: TextStyle(fontSize: screenWidth * 0.0375, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleConfirmationResponse(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDestructive ? ThemeColor.error : ThemeColor.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(kVoiceMinTouchTarget),
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                  ),
                  child: Text(
                    '예',
                    style: TextStyle(fontSize: screenWidth * 0.0375, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceControl() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool showSkipButton = _currentState == VoiceState.speaking;
    final bool showCancelButton =
        _conversationContext != null ||
        _candidateMembers.isNotEmpty ||
        _candidateMemos.isNotEmpty ||
        _isConfirmationStep ||
        _currentState == VoiceState.processing;
    final bool showCompactStatus =
        _chatMessages.isNotEmpty ||
        _pendingUserText.isNotEmpty ||
        _candidateMembers.isNotEmpty ||
        _candidateMemos.isNotEmpty;
    final bool canReplay =
        _lastSpokenText.isNotEmpty &&
        _currentState != VoiceState.processing &&
        _currentState != VoiceState.permissionDenied &&
        _currentState != VoiceState.speaking;
    final bool showReplayButton = canReplay && !showCancelButton;
    final bool showReplayBesideCancel = canReplay && showCancelButton;

    return Container(
      padding: EdgeInsets.fromLTRB(screenWidth * 0.05, screenHeight * 0.02, screenWidth * 0.05, screenHeight * 0.025),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        border: Border(top: BorderSide(color: ThemeColor.border)),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowLight,
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, -screenHeight * 0.002),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCompactStatus) ...[
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.012),
                child: Text(
                  _getCompactStatusMessage(),
                  key: kVoiceCompactStatusKey,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.033,
                    fontWeight: FontWeight.w600,
                    color: (_currentState == VoiceState.error ||
                            _currentState == VoiceState.permissionDenied)
                        ? ThemeColor.error
                        : ThemeColor.textPrimary,
                  ),
                ),
              ),
            ],
            if (_errorNextAction != null &&
                (_currentState == VoiceState.error ||
                    _currentState == VoiceState.permissionDenied ||
                    _currentState == VoiceState.speaking)) ...[
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.012),
                child: Column(
                  children: [
                    if (_currentState == VoiceState.error) ...[
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.033,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.error,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.006),
                    ],
                    Text(
                      _errorNextAction!,
                      key: kVoiceErrorNextActionKey,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.033,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 후보 선택 모드 안내
            if (_isWaitingForNumberResponse)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.012,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.infoSurface,
                  borderRadius: BorderRadius.circular(screenWidth * 0.025),
                  border: Border.all(
                    color: ThemeColor.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: screenWidth * 0.045, color: ThemeColor.info),
                    SizedBox(width: screenWidth * 0.025),
                    Expanded(
                      child: Text(
                        '"1번", "첫번째", "두번째" 등 번호로 선택하세요',
                        style: TextStyle(
                          fontSize: screenWidth * 0.033,
                          color: ThemeColor.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 메인 컨트롤 영역
            Row(
              children: [
                // 왼쪽: 취소 버튼 또는 빈 공간
                Expanded(
                  child: showCancelButton
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDockAction(
                              label: '처음으로',
                              icon: Icons.close,
                              color: ThemeColor.error,
                              background: ThemeColor.errorSurface,
                              border: ThemeColor.error.withValues(alpha: 0.3),
                              onTap: _cancelConversation,
                            ),
                            if (showReplayBesideCancel) ...[
                              SizedBox(height: screenHeight * 0.008),
                              _buildDockAction(
                                key: kVoiceReplayButtonKey,
                                label: '다시 듣기',
                                icon: Icons.replay,
                                color: ThemeColor.primary,
                                background: ThemeColor.primarySurface,
                                border: ThemeColor.primary.withValues(alpha: 0.3),
                                onTap: _replayLastSpeech,
                              ),
                            ],
                          ],
                        )
                      : showReplayButton
                      ? _buildDockAction(
                          key: kVoiceReplayButtonKey,
                          label: '다시 듣기',
                          icon: Icons.replay,
                          color: ThemeColor.primary,
                          background: ThemeColor.primarySurface,
                          border: ThemeColor.primary.withValues(alpha: 0.3),
                          onTap: _replayLastSpeech,
                        )
                      : const SizedBox(),
                ),

                SizedBox(width: screenWidth * 0.04),

                // 중앙: 마이크 버튼
                Semantics(
                  button: true,
                  label: _micSemanticsLabel(),
                  child: GestureDetector(
                  key: kVoiceMicButtonKey,
                  onTap: _handleMicButtonTap,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _currentState == VoiceState.listening
                            ? _pulseAnimation.value
                            : 1.0,
                        child: Container(
                          width: screenWidth * 0.18,
                          height: screenWidth * 0.18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getMicButtonColors(),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getMicButtonColors().first.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: screenWidth * 0.04,
                                offset: Offset(0, screenHeight * 0.005),
                              ),
                            ],
                          ),
                          child: _currentState == VoiceState.processing
                              ? RotationTransition(
                                  turns: _processingController,
                                  child: Icon(
                                    _getMicIcon(),
                                    size: screenWidth * 0.08,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _getMicIcon(),
                                  size: screenWidth * 0.08,
                                  color: Colors.white,
                                ),
                        ),
                      );
                    },
                  ),
                ),
                ),

                SizedBox(width: screenWidth * 0.04),

                // 오른쪽: TTS 건너뛰기 버튼 또는 상태 텍스트
                Expanded(
                  child: showSkipButton
                      ? _buildDockAction(
                          label: '건너뛰기',
                          icon: Icons.skip_next,
                          color: ThemeColor.warning,
                          background: ThemeColor.warningSurface,
                          border: ThemeColor.warning.withValues(alpha: 0.3),
                          onTap: _stopTtsAndStartListening,
                        )
                      : Center(
                          child: Text(
                            _getShortStatusMessage(),
                            style: TextStyle(
                              fontSize: screenWidth * 0.033,
                              color: ThemeColor.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockAction({
    Key? key,
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
    required Color border,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kVoiceMinTouchTarget),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: screenWidth * 0.04, color: color),
                SizedBox(width: screenWidth * 0.015),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _micSemanticsLabel() {
    switch (_currentState) {
      case VoiceState.listening:
        return '듣고 있습니다. 누르면 중지합니다';
      case VoiceState.speaking:
        return '읽고 있습니다. 누르면 말을 시작합니다';
      case VoiceState.processing:
        return '분석 중입니다';
      case VoiceState.error:
        return '오류입니다. 누르면 다시 듣습니다';
      case VoiceState.permissionDenied:
        return '마이크 권한이 필요합니다';
      case VoiceState.ready:
        return '마이크. 누르면 듣기 시작합니다';
    }
  }

  String _getShortStatusMessage() {
    switch (_currentState) {
      case VoiceState.listening:
        return '듣는 중...';
      case VoiceState.speaking:
        return '말하는 중...';
      case VoiceState.processing:
        return '분석 중...';
      case VoiceState.error:
        return '오류 발생';
      case VoiceState.permissionDenied:
        return '권한 필요';
      default:
        return '탭하여 시작';
    }
  }

  String _getCompactStatusMessage() {
    switch (_currentState) {
      case VoiceState.listening:
        return '듣고 있습니다. 지금 말씀하세요';
      case VoiceState.speaking:
        return _lastErrorGuidance != null
            ? '안내를 읽고 있습니다'
            : '답변을 읽고 있습니다';
      case VoiceState.processing:
        return '분석 중...';
      case VoiceState.error:
        return _statusMessage;
      case VoiceState.permissionDenied:
        return '마이크 권한이 필요합니다';
      default:
        if (_isWaitingForNumberResponse) {
          return '번호로 선택하세요. 안 들리면 마이크를 누르세요';
        }
        if (_isConfirmationStep) {
          return '예 또는 아니오로 대답하세요';
        }
        if (_conversationContext?.currentStep?.stepType == 'content_input') {
          return '지금 내용을 말씀하세요';
        }
        return '새 명령을 말하려면 마이크를 누르세요';
    }
  }

  List<Color> _getMicButtonColors() {
    switch (_currentState) {
      case VoiceState.listening:
        return [ThemeColor.success, ThemeColor.successLight];
      case VoiceState.speaking:
        return [ThemeColor.info, ThemeColor.infoLight];
      case VoiceState.processing:
        return [ThemeColor.warning, ThemeColor.warningLight];
      case VoiceState.error:
      case VoiceState.permissionDenied:
        return [ThemeColor.error, ThemeColor.errorLight];
      default:
        return [ThemeColor.primary, ThemeColor.primaryLight];
    }
  }

  IconData _getMicIcon() {
    switch (_currentState) {
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.speaking:
        return Icons.volume_up;
      case VoiceState.processing:
        return Icons.hourglass_empty;
      case VoiceState.error:
      case VoiceState.permissionDenied:
        return Icons.mic_off;
      default:
        return Icons.mic_none;
    }
  }

  void _handleMicButtonTap() {
    switch (_currentState) {
      case VoiceState.ready:
        _startListening();
        break;
      case VoiceState.listening:
        _stopListening();
        break;
      case VoiceState.speaking:
        _stopTtsAndStartListening();
        break;
      case VoiceState.permissionDenied:
        _showPermissionDeniedDialog();
        break;
      case VoiceState.error:
        if (_speechAvailable) {
          setState(() {
            _currentState = VoiceState.ready;
            _errorNextAction = null;
            _lastErrorGuidance = null;
            _statusMessage = '명령을 기다리고 있습니다';
          });
          _startListening();
        } else {
          _checkPermissionsAndInitialize();
        }
        break;
      case VoiceState.processing:
        break;
    }
  }
}

// Helper Classes
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class VoiceMetricField {
  const VoiceMetricField({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String key;
  final String label;
  final int value;
  final String unit;
}

class VoicePinnedResult {
  const VoicePinnedResult({
    required this.title,
    required this.spokenText,
    required this.metrics,
  });

  final String title;
  final String spokenText;
  final List<VoiceMetricField> metrics;
}

class CommandExample {
  final IconData icon;
  final String text;
  final String category;

  CommandExample({
    required this.icon,
    required this.text,
    required this.category,
  });
}

final List<CommandExample> kVoiceOwnerCommandExamples = [
  CommandExample(icon: Icons.today, text: '오늘 브리핑 알려줘', category: '브리핑'),
  CommandExample(icon: Icons.bar_chart, text: '홈 통계 알려줘', category: '통계'),
  CommandExample(icon: Icons.person, text: '홍길동 회원 찾아줘', category: '검색'),
  CommandExample(icon: Icons.search, text: '1234번 회원 찾아줘', category: '검색'),
];
