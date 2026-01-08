import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/auth/token_manager.dart' as app_token;
import 'package:voca_crm/core/di/injection_container.dart' as di;
import 'package:voca_crm/core/error/error_boundary.dart';
import 'package:voca_crm/core/network/api_client.dart';
import 'package:voca_crm/core/network/network_monitor.dart';
import 'package:voca_crm/core/session/session_wrapper.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/data/datasource/error_log_service.dart';
import 'package:voca_crm/firebase_options.dart';
import 'package:voca_crm/presentation/screens/auth/login_screen.dart';
import 'package:voca_crm/presentation/screens/splash_screen.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

import 'core/utils/env_config.dart';

/// 전역 네비게이터 키 (세션 만료 시 로그인 화면으로 이동)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 인증 실패 시 로그인 화면으로 이동
void _navigateToLogin() {
  // TokenManager에서 토큰 삭제
  app_token.TokenManager.instance.clearTokens();

  // 네비게이터를 통해 로그인 화면으로 이동
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

// Custom MaterialColor for the primary app color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

void main() async {
  // runZonedGuarded로 비동기 오류도 캡처
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // .env 파일 로드
      await EnvConfig.load();

      // Firebase 초기화
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 디바이스 정보 초기화 (오류 로그에 포함)
      await ErrorLogService.initDeviceInfo();

      // 글로벌 에러 핸들러 초기화 (Firebase Crashlytics + AppErrorReporter 통합)
      GlobalErrorHandler.instance.initialize(
        onAuthenticationFailed: _navigateToLogin,
        onNetworkError: (error) {
          if (kDebugMode) {
            debugPrint('[NetworkError] ${error.userMessage}');
          }
        },
      );

      // 키 유효성 검증
      if (!EnvConfig.isKakaoKeyValid) {
        throw Exception(
          'Kakao Native App Key is not configured. '
          'Please check your .env file.',
        );
      }

      // Kakao SDK 초기화
      KakaoSdk.init(nativeAppKey: EnvConfig.kakaoNativeAppKey);

      // 의존성 주입 초기화
      await di.initializeDependencies();

      // 네트워크 모니터 초기화
      await NetworkMonitor.instance.initialize();

      // ApiClient 콜백 초기화
      ApiClient.instance.onAuthenticationFailed = _navigateToLogin;

      // TokenManager 콜백 초기화 (토큰 갱신 성공 시)
      app_token.TokenManager.instance.onTokensRefreshed = (tokens) {
        if (kDebugMode) {
          debugPrint('[TokenManager] Tokens refreshed successfully');
        }
      };

      runApp(const RootApp());
    } catch (e, stackTrace) {
      // 초기화 오류는 GlobalErrorHandler를 통해 처리 (로그 기록)
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stackTrace,
        screenName: 'Initialization',
        action: 'App Startup',
        isFatal: true,
      );

      // 에러 화면 표시
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '앱을 시작할 수 없습니다',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '문제가 지속되면 관리자에게 문의해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    // 디버그 모드에서만 기술 정보 표시
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '[DEBUG] $e',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }, GlobalErrorHandler.instance.handleZoneError);
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserViewModel(),
      child: SessionWrapper(
        onLogout: _navigateToLogin,
        onSessionExpired: _navigateToLogin,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'CRM Voice App',
        theme: ThemeData(
        // Primary Color based on #1c06b1
        primarySwatch: createMaterialColor(ThemeColor.primaryPurple),
        primaryColor: ThemeColor.primaryPurple,

        // Noto Sans Font application
        fontFamily:
            'NotoSansKR', // Make sure this matches your pubspec.yaml entry

        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: ThemeColor.whiteColor, // White background
        cardColor: ThemeColor.whiteColor, // White card background
        // AppBar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: ThemeColor.whiteColor, // White app bar
          foregroundColor: Colors.black, // Dark icons/text on app bar
          elevation: 0, // No shadow
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansKR', // Keep here for AppBar title specifically
          ),
        ),

        // Bottom Navigation Bar Theme
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: ThemeColor.whiteColor,
          selectedItemColor: ThemeColor.primaryPurple, // Active item color
          unselectedItemColor: Colors.grey[600], // Inactive item color
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansKR',
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontFamily: 'NotoSansKR',
          ),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),

        // ElevatedButton Theme (for 'Edit Contact' and 'Try Again')
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeColor.primaryPurple, // Filled button color
            foregroundColor:
                ThemeColor.whiteColor, // Text color on filled button
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: TextStyle(
              fontFamily: 'NotoSansKR',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // OutlinedButton Theme (for 'View Profile')
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor:
                ThemeColor.primaryPurple, // Text color for outline button
            side: BorderSide(color: ThemeColor.primaryPurple), // Border color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: TextStyle(
              fontFamily: 'NotoSansKR',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Define general text styles to ensure Noto Sans is used
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontFamily: 'NotoSansKR'),
          bodyMedium: TextStyle(fontFamily: 'NotoSansKR'),
          bodySmall: TextStyle(fontFamily: 'NotoSansKR'),
          displayLarge: TextStyle(fontFamily: 'NotoSansKR'),
          displayMedium: TextStyle(fontFamily: 'NotoSansKR'),
          displaySmall: TextStyle(fontFamily: 'NotoSansKR'),
          headlineLarge: TextStyle(fontFamily: 'NotoSansKR'),
          headlineMedium: TextStyle(fontFamily: 'NotoSansKR'),
          headlineSmall: TextStyle(fontFamily: 'NotoSansKR'),
          titleLarge: TextStyle(fontFamily: 'NotoSansKR'),
          titleMedium: TextStyle(fontFamily: 'NotoSansKR'),
          titleSmall: TextStyle(fontFamily: 'NotoSansKR'),
          labelLarge: TextStyle(fontFamily: 'NotoSansKR'),
          labelMedium: TextStyle(fontFamily: 'NotoSansKR'),
          labelSmall: TextStyle(fontFamily: 'NotoSansKR'),
        ).apply(bodyColor: Colors.black87, displayColor: Colors.black87),
      ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
