import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:voca_crm/data/datasource/voice_command_service.dart';
import 'package:voca_crm/domain/entity/conversation_context.dart';
import 'package:voca_crm/domain/entity/voice_command_response.dart';

enum VoicePermissionOutcome { granted, denied, permanentlyDenied }

class VoiceSpeechListenResult {
  const VoiceSpeechListenResult({
    required this.recognizedWords,
    required this.finalResult,
  });

  final String recognizedWords;
  final bool finalResult;
}

class VoiceSpeechError {
  const VoiceSpeechError(this.errorMsg);

  final String errorMsg;
}

abstract class VoiceSpeechPort {
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceSpeechError error) onError,
  });

  Future<void> listen({
    required void Function(VoiceSpeechListenResult result) onResult,
  });

  Future<void> stop();

  bool get isListening;
}

abstract class VoiceTtsPort {
  Future<void> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  void setCompletionHandler(VoidCallback handler);
  Future<void> speak(String text);
  Future<void> stop();
}

abstract class VoicePermissionPort {
  Future<VoicePermissionOutcome> requestMicrophoneAndSpeech();
  Future<void> openSettings();
}

abstract class VoiceCommandApi {
  Future<VoiceCommandResponse> sendVoiceCommand({
    required String text,
    ConversationContext? context,
    String? userId,
  });
}

class VoiceErrorGuidance {
  const VoiceErrorGuidance({
    required this.errorCode,
    required this.statusMessage,
    required this.nextAction,
    required this.allowAutoRestart,
  });

  final String errorCode;
  final String statusMessage;
  final String nextAction;
  final bool allowAutoRestart;
}

/// 음성 API/예외 errorCode를 화면 안내와 다음 행동으로 변환한다.
VoiceErrorGuidance resolveVoiceErrorGuidance({
  String? errorCode,
  String? fallbackMessage,
}) {
  switch (errorCode) {
    case 'AI_UNAVAILABLE':
      return const VoiceErrorGuidance(
        errorCode: 'AI_UNAVAILABLE',
        statusMessage: 'AI 서버가 응답하지 않습니다. 잠시 후 다시 시도해주세요.',
        nextAction: '잠시 후 마이크를 다시 눌러 주세요',
        allowAutoRestart: false,
      );
    case 'RATE_LIMIT':
      return const VoiceErrorGuidance(
        errorCode: 'RATE_LIMIT',
        statusMessage: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
        nextAction: '1분 뒤에 다시 말씀해주세요',
        allowAutoRestart: false,
      );
    case 'DAILY_LIMIT':
    case 'DAILY_LIMIT_EXCEEDED':
      return VoiceErrorGuidance(
        errorCode: errorCode!,
        statusMessage: '오늘의 AI 분석 사용량을 초과했습니다. 내일 다시 시도해주세요.',
        nextAction: '내일 다시 시도해 주세요',
        allowAutoRestart: false,
      );
    case 'NO_BUSINESS_PLACE':
      return const VoiceErrorGuidance(
        errorCode: 'NO_BUSINESS_PLACE',
        statusMessage: '사업장 정보가 없어 명령을 처리할 수 없습니다. 사업장을 먼저 선택해주세요.',
        nextAction: '홈에서 사업장을 선택한 뒤 다시 시도하세요',
        allowAutoRestart: false,
      );
    case 'UNKNOWN_COMMAND':
      return const VoiceErrorGuidance(
        errorCode: 'UNKNOWN_COMMAND',
        statusMessage: '명령을 이해하지 못했습니다. 다시 말씀해주세요.',
        nextAction: '브리핑, 회원 검색처럼 구체적으로 말씀해주세요',
        allowAutoRestart: true,
      );
    default:
      return VoiceErrorGuidance(
        errorCode: errorCode ?? 'UNKNOWN',
        statusMessage:
            fallbackMessage ?? '명령 처리 중 오류가 발생했습니다. 다시 시도해주세요.',
        nextAction: '마이크를 눌러 다시 시도해주세요',
        allowAutoRestart: true,
      );
  }
}

class PluginVoiceSpeechPort implements VoiceSpeechPort {
  PluginVoiceSpeechPort({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(VoiceSpeechError error) onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(VoiceSpeechError(error.errorMsg)),
    );
  }

  @override
  Future<void> listen({
    required void Function(VoiceSpeechListenResult result) onResult,
  }) async {
    await _speech.listen(
      onResult: (result) => onResult(
        VoiceSpeechListenResult(
          recognizedWords: result.recognizedWords,
          finalResult: result.finalResult,
        ),
      ),
      localeId: 'ko_KR',
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
  }

  @override
  bool get isListening => _speech.isListening;
}

class PluginVoiceTtsPort implements VoiceTtsPort {
  PluginVoiceTtsPort({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  @override
  void setCompletionHandler(VoidCallback handler) {
    _tts.setCompletionHandler(handler);
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

class PluginVoicePermissionPort implements VoicePermissionPort {
  @override
  Future<VoicePermissionOutcome> requestMicrophoneAndSpeech() async {
    final statuses = await [
      Permission.microphone,
      Permission.speech,
    ].request();

    final micStatus = statuses[Permission.microphone]!;
    final speechStatus = statuses[Permission.speech]!;

    if (micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied) {
      return VoicePermissionOutcome.permanentlyDenied;
    }
    if (micStatus.isGranted && speechStatus.isGranted) {
      return VoicePermissionOutcome.granted;
    }
    return VoicePermissionOutcome.denied;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

class VoiceCommandServiceApi implements VoiceCommandApi {
  VoiceCommandServiceApi({VoiceCommandService? service})
      : _service = service ?? VoiceCommandService();

  final VoiceCommandService _service;

  @override
  Future<VoiceCommandResponse> sendVoiceCommand({
    required String text,
    ConversationContext? context,
    String? userId,
  }) {
    return _service.sendVoiceCommand(
      text: text,
      context: context,
      userId: userId,
    );
  }
}
