import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

enum VoiceState {
  ready,
  listening,
  processing,
  speaking,
  error,
  permissionDenied,
}

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with TickerProviderStateMixin {
  // Speech & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  // Services
  final _voiceCommandService = VoiceCommandService();
  final _memoRepository = MemoRepositoryImpl(MemoService());

  // State
  VoiceState _currentState = VoiceState.ready;
  bool _speechAvailable = false;
  bool _autoRestart = true;
  double _ttsSpeed = 0.5;

  // Voice Recognition
  String _recognizedText = '';
  String _statusMessage = '마이크 버튼을 눌러 시작하세요';

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

  // Conversation History (for chat UI)
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  // Command Examples
  final List<CommandExample> _commandExamples = [
    CommandExample(icon: Icons.search, text: '1234번 회원 찾아줘', category: '검색'),
    CommandExample(icon: Icons.person, text: '홍길동 회원 찾아줘', category: '검색'),
    CommandExample(
      icon: Icons.note_add,
      text: '홍길동에게 예약 확인이라고 메모',
      category: '메모',
    ),
    CommandExample(
      icon: Icons.check_circle,
      text: '홍길동 방문 체크해줘',
      category: '방문',
    ),
    CommandExample(icon: Icons.today, text: '오늘 브리핑 알려줘', category: '통계'),
    CommandExample(icon: Icons.person_add, text: '김철수 회원 등록해줘', category: '등록'),
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
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
  }

  /// 권한 확인 및 초기화
  Future<void> _checkPermissionsAndInitialize() async {
    // 마이크 권한 확인
    var micStatus = await Permission.microphone.status;

    if (micStatus.isDenied) {
      // 권한 요청
      micStatus = await Permission.microphone.request();
    }

    if (micStatus.isPermanentlyDenied) {
      // 영구 거부된 경우
      setState(() {
        _currentState = VoiceState.permissionDenied;
        _statusMessage = '마이크 권한이 필요합니다';
      });
      _showPermissionDeniedDialog();
      return;
    }

    if (micStatus.isDenied) {
      setState(() {
        _currentState = VoiceState.permissionDenied;
        _statusMessage = '마이크 권한이 거부되었습니다';
      });
      return;
    }

    // 권한 승인됨 - 초기화 진행

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
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
              openAppSettings();
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
          if (!mounted) return;
          if (status == 'done' && _currentState == VoiceState.listening) {
            setState(() {
              _currentState = VoiceState.ready;
              _statusMessage = '음성 인식 완료';
            });
            _stopAnimations();

            if (_autoRestart && _recognizedText.isEmpty) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted && _currentState == VoiceState.ready) {
                  _startListening();
                }
              });
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _currentState = VoiceState.error;
            _statusMessage = '음성 인식 오류';
          });
          _stopAnimations();

          // 권한 관련 에러인지 확인
          if (error.errorMsg.contains('permission') ||
              error.errorMsg.contains('Permission')) {
            _showPermissionDeniedDialog();
          } else if (_autoRestart) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _currentState = VoiceState.ready);
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
      if (mounted) {
        setState(() {
          _currentState = VoiceState.ready;
          _statusMessage = '명령을 기다리고 있습니다';
        });
        _stopAnimations();

        if (_autoRestart) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _currentState == VoiceState.ready) {
              _startListening();
            }
          });
        }
      }
    });
  }

  void _stopAnimations() {
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    // 채팅 메시지 추가
    _addChatMessage(text, isUser: false);

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
      _statusMessage = '듣고 있습니다...';
    });

    _waveController.repeat();
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          if (_recognizedText.isNotEmpty) {
            _statusMessage = '"$_recognizedText"';
          }
        });

        if (result.finalResult && _recognizedText.isNotEmpty) {
          _processVoiceCommand(_recognizedText);
        }
      },
      listenMode: stt.ListenMode.confirmation,
      localeId: 'ko_KR',
      cancelOnError: false,
      partialResults: true,
      listenFor: const Duration(seconds: 10),
    );
  }

  void _stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    setState(() {
      _currentState = VoiceState.ready;
      _statusMessage = '음성 인식 중지됨';
      _autoRestart = false;
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

    // 스크롤 애니메이션
    Future.delayed(const Duration(milliseconds: 100), () {
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
    // 사용자 메시지 추가
    _addChatMessage(text, isUser: true);

    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = '처리 중...';
    });
    _stopAnimations();

    // 번호 응답 대기 중인 경우
    if (_isWaitingForNumberResponse) {
      await _handleNumberResponse(text);
      return;
    }

    // 확인 단계인 경우
    if (_isConfirmationStep) {
      final confirmed = _isConfirmationResponse(text);
      if (confirmed != null) {
        await _handleConfirmationResponse(confirmed);
        return;
      }
    }

    try {
      final userViewModel = context.read<UserViewModel>();
      final userId = userViewModel.user?.providerId;

      final response = await _voiceCommandService.sendVoiceCommand(
        text: text,
        context: _conversationContext,
        userId: userId,
      );

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else if (response.isError) {
        await _speak(response.message);
      }
    } catch (e, stackTrace) {
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
      await _speak('명령 처리 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  bool? _isConfirmationResponse(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('예') ||
        lower.contains('네') ||
        lower.contains('응') ||
        lower.contains('맞') ||
        lower.contains('좋') ||
        lower.contains('ok') ||
        lower.contains('yes') ||
        lower.contains('확인')) {
      return true;
    }
    if (lower.contains('아니') ||
        lower.contains('취소') ||
        lower.contains('no') ||
        lower.contains('싫') ||
        lower.contains('안')) {
      return false;
    }
    return null;
  }

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

    final selectedId = candidates[number - 1]['id'] as String;

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

    final candidates = response.data?['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      await _speak('정보를 찾을 수 없습니다.');
      return;
    }

    final searchKeyword = response.data?['searchKeyword'] as String?;

    setState(() {
      _isConfirmationStep = false;
      _isWaitingForNumberResponse = true;
      _lastSearchKeyword = searchKeyword;

      if (response.isMemberSelection) {
        _candidateMembers = candidates
            .map((c) => c as Map<String, dynamic>)
            .toList();
        _candidateMemos = [];
      } else if (response.isMemoSelection) {
        _candidateMemos = candidates
            .map((c) => c as Map<String, dynamic>)
            .toList();
        _candidateMembers = [];
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

    final memberData = response.data?['member'];
    final memoData = response.data?['memo'];

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

    await _speak(response.message);
  }

  Future<void> _selectCandidate(Map<String, dynamic> candidate) async {
    final id = candidate['id'] as String;
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
    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = '처리 중...';
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

      final response = await _voiceCommandService.sendVoiceCommand(
        text: selectAll ? '전체' : selectedIds.join(','),
        context: updatedContext,
        userId: userId,
      );

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else if (response.isError) {
        await _speak(response.message);
      }
    } catch (e, stackTrace) {
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
      await _speak('선택 처리 중 오류가 발생했습니다.');
    }
  }

  Future<void> _handleConfirmationResponse(bool confirmed) async {
    setState(() {
      _currentState = VoiceState.processing;
      _statusMessage = confirmed ? '진행 중...' : '취소 중...';
    });

    try {
      final userViewModel = context.read<UserViewModel>();
      final userId = userViewModel.user?.providerId;

      final response = await _voiceCommandService.sendVoiceCommand(
        text: confirmed ? '예' : '아니오',
        context: _conversationContext,
        userId: userId,
      );

      setState(() => _isConfirmationStep = false);

      if (response.isClarificationNeeded) {
        await _handleClarificationNeeded(response);
      } else if (response.isCompleted) {
        await _handleCommandCompleted(response);
      } else if (response.isError) {
        await _speak(response.message);
      }
    } catch (e, stackTrace) {
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
      await _speak('확인 처리 중 오류가 발생했습니다.');
      setState(() => _isConfirmationStep = false);
    }
  }

  void _cancelConversation() {
    setState(() {
      _conversationContext = null;
      _candidateMembers = [];
      _candidateMemos = [];
      _selectedIds.clear();
      _isConfirmationStep = false;
      _isWaitingForNumberResponse = false;
      _lastSearchKeyword = null;
      _currentMember = null;
      _currentMemo = null;
      _statusMessage = '대화가 취소되었습니다';
    });

    _flutterTts.stop();
    if (_speech.isListening) _speech.stop();
    _stopAnimations();

    _addChatMessage('대화가 취소되었습니다.', isUser: false);
  }

  void _clearChat() {
    setState(() {
      _chatMessages.clear();
      _currentMember = null;
      _currentMemo = null;
    });
  }

  int? _parseNumberFromText(String text) {
    final normalized = text.trim().toLowerCase();

    final Map<String, int> numberMap = {
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
      '일': 1,
      '이': 2,
      '삼': 3,
      '사': 4,
      '오': 5,
      '육': 6,
      '칠': 7,
      '팔': 8,
      '구': 9,
      '십': 10,
      '일번': 1,
      '이번': 2,
      '삼번': 3,
      '사번': 4,
      '오번': 5,
      '육번': 6,
      '칠번': 7,
      '팔번': 8,
      '구번': 9,
      '십번': 10,
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
      '여섯': 6,
      '일곱': 7,
      '여덟': 8,
      '아홉': 9,
      '열': 10,
    };

    if (numberMap.containsKey(normalized)) return numberMap[normalized];

    final match = RegExp(r'^(\d+)').firstMatch(normalized);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed >= 1 && parsed <= 10) return parsed;
    }

    for (final entry in numberMap.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    return null;
  }

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
    _pulseController.dispose();
    _waveController.dispose();
    _chatScrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
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
                      _candidateMembers.isEmpty &&
                      _candidateMemos.isEmpty
                  ? _buildEmptyState()
                  : _buildChatView(),
            ),
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
                      '취소',
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
            icon: Icons.repeat,
            label: _autoRestart ? 'ON' : 'OFF',
            isActive: _autoRestart,
            onTap: () => setState(() {
              _autoRestart = !_autoRestart;
              if (_autoRestart && _currentState == VoiceState.ready) {
                _startListening();
              }
            }),
          ),
          SizedBox(width: screenWidth * 0.02),
          _buildSpeedSelector(),
          if (_chatMessages.isNotEmpty) ...[
            SizedBox(width: screenWidth * 0.02),
            GestureDetector(
              onTap: _clearChat,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: ThemeColor.neutral100,
                  borderRadius: BorderRadius.circular(screenWidth * 0.02),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: screenWidth * 0.045,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025, vertical: screenHeight * 0.008),
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
    );
  }

  Widget _buildSpeedSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return PopupMenuButton<double>(
      offset: Offset(0, screenHeight * 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.03)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.025, vertical: screenHeight * 0.008),
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
                  ? '느림'
                  : _ttsSpeed == 0.7
                  ? '빠름'
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
    final bottomNavPadding = MainScreen.navBarHeight + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: screenWidth * 0.05,
        bottom: bottomNavPadding,
      ),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.025),

          // 상태 표시 카드
          _buildStatusCard(),

          SizedBox(height: screenHeight * 0.03),

          // 명령어 예시
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.05),
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
                SizedBox(height: screenHeight * 0.02),
                ...List.generate(_commandExamples.length, (index) {
                  final example = _commandExamples[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _commandExamples.length - 1 ? screenHeight * 0.015 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => _processVoiceCommand(example.text),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.012,
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
              ],
            ),
          ),

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

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale:
              _currentState == VoiceState.listening ||
                  _currentState == VoiceState.speaking
              ? _pulseAnimation.value
              : 1.0,
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
                  child: Icon(icon, size: screenWidth * 0.1, color: iconColor),
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
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
      },
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
    final bottomNavPadding = MainScreen.navBarHeight + MediaQuery.of(context).padding.bottom;

    return ListView.builder(
      controller: _chatScrollController,
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: screenWidth * 0.04,
        bottom: bottomNavPadding,
      ),
      itemCount: _chatMessages.length + (_currentMember != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (_currentMember != null && index == 0) {
          return _buildMemberInfoCard();
        }

        final msgIndex = _currentMember != null ? index - 1 : index;
        final message = _chatMessages[msgIndex];
        return _buildChatBubble(message);
      },
    );
  }

  Widget _buildMemberInfoCard() {
    if (_currentMember == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
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
            height: screenHeight * 0.1,
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
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        border: Border(top: BorderSide(color: ThemeColor.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleConfirmationResponse(false),
              style: OutlinedButton.styleFrom(
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
                backgroundColor: ThemeColor.primary,
                foregroundColor: Colors.white,
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
        _isConfirmationStep;

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
                      ? GestureDetector(
                          onTap: _cancelConversation,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.012,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColor.errorSurface,
                              borderRadius: BorderRadius.circular(screenWidth * 0.06),
                              border: Border.all(
                                color: ThemeColor.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close,
                                  size: screenWidth * 0.04,
                                  color: ThemeColor.error,
                                ),
                                SizedBox(width: screenWidth * 0.015),
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
                      : const SizedBox(),
                ),

                SizedBox(width: screenWidth * 0.04),

                // 중앙: 마이크 버튼
                GestureDetector(
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
                          child: Icon(
                            _getMicIcon(),
                            size: screenWidth * 0.08,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(width: screenWidth * 0.04),

                // 오른쪽: TTS 건너뛰기 버튼 또는 상태 텍스트
                Expanded(
                  child: showSkipButton
                      ? GestureDetector(
                          onTap: _stopTtsAndStartListening,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.012,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColor.warningSurface,
                              borderRadius: BorderRadius.circular(screenWidth * 0.06),
                              border: Border.all(
                                color: ThemeColor.warning.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.skip_next,
                                  size: screenWidth * 0.04,
                                  color: ThemeColor.warning,
                                ),
                                SizedBox(width: screenWidth * 0.015),
                                Text(
                                  '건너뛰기',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.033,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeColor.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  String _getShortStatusMessage() {
    switch (_currentState) {
      case VoiceState.listening:
        return '듣는 중...';
      case VoiceState.speaking:
        return '말하는 중...';
      case VoiceState.processing:
        return '처리 중...';
      case VoiceState.error:
        return '오류 발생';
      case VoiceState.permissionDenied:
        return '권한 필요';
      default:
        return '탭하여 시작';
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
        _checkPermissionsAndInitialize();
        break;
      default:
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
