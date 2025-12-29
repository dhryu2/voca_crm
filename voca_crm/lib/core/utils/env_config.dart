import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // .env 파일 로드
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // Kakao Native App Key 가져오기
  static String get kakaoNativeAppKey {
    return dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
  }

  // 키가 제대로 로드되었는지 확인
  static bool get isKakaoKeyValid {
    return kakaoNativeAppKey.isNotEmpty &&
        kakaoNativeAppKey != 'REPLACE_WITH_YOUR_KAKAO_KEY';
  }
}
