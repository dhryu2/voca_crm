import 'package:flutter/foundation.dart';

class ApiConstants {
  /// 개발 환경 API URL (Android Emulator에서 localhost 접근용)
  static const String _devUrl = 'http://10.0.2.2:8080';

  /// 운영 환경 API URL
  static const String _prodUrl = 'https://voca-api.dhryu.dev';

  /// 현재 환경에 맞는 API Base URL 반환
  static String get apiBaseUrl {
    return kReleaseMode ? _prodUrl : _devUrl;
  }
}
