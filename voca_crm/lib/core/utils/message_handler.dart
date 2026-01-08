import 'dart:convert';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voca_crm/core/error/app_exception.dart';
import 'package:voca_crm/core/error/exception_parser.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/data/datasource/error_log_service.dart';
import 'package:voca_crm/domain/entity/error_log.dart';

import 'haptic_helper.dart';

/// 메시지 표시 유틸리티 클래스
///
/// 에러, 성공, 정보 메시지를 파싱하고 사용자에게 적절한 UI로 표시합니다.
///
/// 주요 기능:
/// - [showErrorSnackBar] : 에러 메시지 표시
/// - [showSuccessSnackBar] : 성공 메시지 표시
/// - [showInfoSnackBar] : 정보 메시지 표시
/// - [showErrorDialog] : 에러 다이얼로그 표시
/// - [showConfirmDialog] : 확인 다이얼로그 표시
/// - [handleAppException] : AppException 기반 에러 처리
/// - [showRetryableError] : 재시도 가능한 에러 표시
/// - [showNetworkError] : 네트워크 에러 전용 UI
class AppMessageHandler {
  /// Show a simple error flushbar for minor errors
  static Future<void> showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) async {
    if (message.isEmpty) return;
    HapticHelper.error();

    await Flushbar(
      message: message,
      duration: duration,
      icon: Icon(icon ?? Icons.error_outline, color: Colors.white, size: 28),
      backgroundColor: Colors.red.shade600,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          '확인',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// Show a success flushbar
  static Future<void> showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) async {
    if (message.isEmpty) return;
    HapticHelper.success();

    await Flushbar(
      message: message,
      duration: duration,
      icon: Icon(
        icon ?? Icons.check_circle_outline,
        color: Colors.white,
        size: 28,
      ),
      backgroundColor: Colors.green.shade600,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          '확인',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// Show an info flushbar (alias for showSnackBar with info styling)
  static Future<void> showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) async {
    if (message.isEmpty) return;
    HapticHelper.light();

    await Flushbar(
      message: message,
      duration: duration,
      icon: Icon(icon ?? Icons.info_outline, color: Colors.white, size: 28),
      backgroundColor: Colors.blue.shade600,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          '확인',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// Show a general info flushbar
  static Future<void> showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
    Color? backgroundColor,
  }) async {
    if (message.isEmpty) return;

    await Flushbar(
      message: message,
      duration: duration,
      icon: Icon(icon ?? Icons.info_outline, color: Colors.white, size: 28),
      backgroundColor: backgroundColor ?? ThemeColor.primaryPurple,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          '확인',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// Show an error dialog for important errors
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    HapticHelper.error();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Container(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm?.call();
                  },
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.08,
                  0,
                  screenWidth * 0.08,
                  screenWidth * 0.08,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: screenWidth * 0.16,
                      height: screenWidth * 0.16,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: screenWidth * 0.08,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    // Message
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          ),
                        ),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
  }) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: Container(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.08,
                  0,
                  screenWidth * 0.08,
                  screenWidth * 0.08,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: screenWidth * 0.16,
                      height: screenWidth * 0.16,
                      decoration: BoxDecoration(
                        color: ThemeColor.primaryPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.help_outline,
                        size: screenWidth * 0.08,
                        color: ThemeColor.primaryPurple,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    // Message
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: screenHeight * 0.06,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                ),
                              ),
                              child: Text(
                                cancelText,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Expanded(
                          child: SizedBox(
                            height: screenHeight * 0.06,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColor.primaryPurple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                ),
                              ),
                              child: Text(
                                confirmText,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) {
      HapticHelper.heavy();
    }
    return result ?? false;
  }

  /// Handle API errors and show appropriate UI
  ///
  /// 이 메서드는 기본적인 오류 처리만 수행합니다.
  /// 예기치 못한 오류 로깅이 필요한 경우 [handleErrorWithLogging]을 사용하세요.
  static void handleApiError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    // AppException으로 변환하여 userMessage 사용
    final appException = error is AppException
        ? error
        : ExceptionParser.fromException(error);
    showErrorSnackBar(context, appException.userMessage);
  }

  /// Parse error message from exception
  static String parseErrorMessage(dynamic error) {
    // AppException인 경우 userMessage 사용
    if (error is AppException) {
      return error.userMessage;
    }

    if (error == null) return '알 수 없는 오류가 발생했습니다.';

    String errorString = error.toString();

    // "Exception: " 접두사 제거
    if (errorString.startsWith('Exception: ')) {
      errorString = errorString.substring(11);
    }

    // Try to extract JSON error response from backend
    try {
      // Error format: "Failed to login: {json}" or just "{json}"
      if (errorString.contains('{') && errorString.contains('}')) {
        final jsonStart = errorString.indexOf('{');
        final jsonEnd = errorString.lastIndexOf('}') + 1;
        final jsonString = errorString.substring(jsonStart, jsonEnd);

        final errorData = jsonDecode(jsonString);

        // fieldErrors가 있으면 첫 번째 필드 오류 메시지 반환
        if (errorData['fieldErrors'] is Map && (errorData['fieldErrors'] as Map).isNotEmpty) {
          final fieldErrors = errorData['fieldErrors'] as Map;
          return fieldErrors.values.first.toString();
        }

        // If backend sent a user-friendly message, use it
        if (errorData['message'] != null && errorData['message'].toString().isNotEmpty) {
          return errorData['message'];
        }
      }
    } catch (e) {
      // JSON parsing failed, continue with fallback logic
    }

    // JSON이 아닌 경우 직접 메시지 반환 (service에서 이미 추출한 경우)
    // "Failed to XXX: 메시지" 형식에서 메시지만 추출 시도하지 않고 그대로 반환
    // (service에서 이미 사용자 친화적 메시지로 변환됨)

    // Network-related errors
    if (errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup') ||
        errorString.contains('Connection refused') ||
        errorString.contains('No address associated with hostname')) {
      return '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
    }

    if (errorString.contains('TimeoutException') ||
        errorString.contains('timeout')) {
      return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
    }

    // HTTP error codes
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return '인증에 실패했습니다. 다시 로그인해주세요.';
    }

    if (errorString.contains('403') || errorString.contains('Forbidden')) {
      return '접근 권한이 없습니다.';
    }

    if (errorString.contains('404') || errorString.contains('Not Found')) {
      return '요청한 정보를 찾을 수 없습니다.';
    }

    if (errorString.contains('429') || errorString.contains('Too Many Requests')) {
      return '요청 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.';
    }

    if (errorString.contains('500') ||
        errorString.contains('Internal Server Error')) {
      return '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (errorString.contains('503') ||
        errorString.contains('Service Unavailable')) {
      return '서버를 사용할 수 없습니다. 잠시 후 다시 시도해주세요.';
    }

    // Fallback for unknown errors
    return '오류가 발생했습니다. 문제가 지속되면 관리자에게 문의해주세요.';
  }

  // ============ 새로운 AppException 기반 메서드 ============

  /// AppException을 처리하고 적절한 UI를 표시
  static Future<void> handleAppException(
    BuildContext context,
    AppException error, {
    VoidCallback? onRetry,
    VoidCallback? onLogin,
  }) async {
    // 인증 필요 시 로그인 콜백 호출
    if (error.requiresLogin && onLogin != null) {
      onLogin();
      return;
    }

    // 재시도 가능한 에러
    if (error.isRetryable && onRetry != null) {
      await showRetryableError(context, error, onRetry: onRetry);
      return;
    }

    // 일반 에러 표시
    await showErrorSnackBar(context, error.userMessage);
  }

  /// 재시도 가능한 에러 표시
  static Future<void> showRetryableError(
    BuildContext context,
    AppException error, {
    required VoidCallback onRetry,
    Duration duration = const Duration(seconds: 5),
  }) async {
    HapticHelper.error();

    await Flushbar(
      message: error.userMessage,
      duration: duration,
      icon: Icon(_getErrorIcon(error), color: Colors.white, size: 28),
      backgroundColor: _getErrorColor(error),
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onRetry();
        },
        child: const Text(
          '재시도',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// 네트워크 에러 전용 표시
  static Future<void> showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    HapticHelper.error();

    await Flushbar(
      title: '네트워크 연결 오류',
      message: '인터넷 연결을 확인해주세요.',
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.wifi_off, color: Colors.white, size: 28),
      backgroundColor: Colors.orange.shade700,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: onRetry != null
          ? TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text(
                '재시도',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      titleColor: Colors.white,
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// 로그인 필요 에러 표시
  static Future<void> showAuthError(
    BuildContext context, {
    required VoidCallback onLogin,
  }) async {
    HapticHelper.medium();

    await Flushbar(
      title: '로그인 필요',
      message: '세션이 만료되었습니다. 다시 로그인해주세요.',
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
      backgroundColor: Colors.orange.shade700,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black26,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
      mainButton: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onLogin();
        },
        child: const Text(
          '로그인',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      titleColor: Colors.white,
      messageColor: Colors.white,
      messageSize: 14,
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ).show(context);
  }

  /// 에러 타입에 따른 아이콘 반환
  static IconData _getErrorIcon(AppException error) {
    if (error is NoInternetException) return Icons.wifi_off;
    if (error is NetworkException) return Icons.cloud_off;
    if (error is UnauthorizedException) return Icons.lock_outline;
    if (error is ForbiddenException) return Icons.block;
    if (error is NotFoundException) return Icons.search_off;
    if (error is RateLimitException) return Icons.speed;
    if (error is ServerException) return Icons.dns;
    if (error is ValidationException) return Icons.warning_amber;
    return Icons.error_outline;
  }

  /// 에러 타입에 따른 색상 반환
  static Color _getErrorColor(AppException error) {
    if (error is NoInternetException) return Colors.orange.shade700;
    if (error is NetworkException) return Colors.red.shade600;
    if (error is UnauthorizedException) return Colors.orange.shade700;
    if (error is ForbiddenException) return Colors.red.shade700;
    if (error is NotFoundException) return Colors.blue.shade600;
    if (error is RateLimitException) return Colors.orange.shade600;
    if (error is ServerException) return Colors.red.shade600;
    if (error is ValidationException) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  /// dynamic 에러를 AppException으로 변환하고 처리
  static Future<void> handleDynamicError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    VoidCallback? onLogin,
  }) async {
    final appException = error is AppException
        ? error
        : ExceptionParser.fromException(error);

    await handleAppException(
      context,
      appException,
      onRetry: onRetry,
      onLogin: onLogin,
    );
  }

  /// 예기치 못한 오류를 서버에 로깅하고 사용자에게 표시
  ///
  /// [screenName]: 오류가 발생한 화면 이름
  /// [action]: 수행 중이던 작업 (예: "사업장 생성", "회원 조회")
  /// [userId]: 현재 사용자 ID (선택)
  /// [businessPlaceId]: 현재 사업장 ID (선택)
  static Future<void> handleUnexpectedError(
    BuildContext context,
    dynamic error,
    StackTrace? stackTrace, {
    required String screenName,
    String? action,
    String? userId,
    String? businessPlaceId,
  }) async {
    // AppException으로 변환
    final appException = error is AppException
        ? error
        : ExceptionParser.fromException(error, stackTrace);

    // UnknownException이거나 ServerException인 경우 서버에 로깅
    if (appException is UnknownException || appException is ServerException) {
      try {
        await ErrorLogService.instance.logException(
          userId: userId,
          businessPlaceId: businessPlaceId,
          screenName: screenName,
          action: action,
          exception: error,
          stackTrace: stackTrace,
          severity: appException is ServerException
              ? ErrorSeverity.critical
              : ErrorSeverity.error,
        );
      } catch (logError) {
        // 로그 전송 실패 시 무시 (콘솔에만 출력)
        if (kDebugMode) {
          debugPrint('Failed to log error: $logError');
        }
      }
    }

    // 사용자에게 에러 메시지 표시
    if (context.mounted) {
      await showErrorSnackBar(context, appException.userMessage);
    }
  }

  /// catch 블록에서 사용하기 위한 간편 메서드
  ///
  /// 사용 예:
  /// ```dart
  /// try {
  ///   await someOperation();
  /// } catch (e, stackTrace) {
  ///   AppMessageHandler.handleErrorWithLogging(
  ///     context, e, stackTrace,
  ///     screenName: 'BusinessPlaceManagement',
  ///     action: '사업장 생성',
  ///   );
  /// }
  /// ```
  static Future<void> handleErrorWithLogging(
    BuildContext context,
    dynamic error,
    StackTrace? stackTrace, {
    required String screenName,
    String? action,
    String? userId,
    String? businessPlaceId,
    bool showSnackbar = true,
  }) async {
    final appException = error is AppException
        ? error
        : ExceptionParser.fromException(error, stackTrace);

    // 의도된 비즈니스 예외가 아닌 경우에만 로깅
    // BadRequestException, ForbiddenException 등은 의도된 예외이므로 로깅하지 않음
    final shouldLog = appException is UnknownException ||
        appException is ServerException ||
        appException is BadGatewayException ||
        appException is ServiceUnavailableException ||
        appException is GatewayTimeoutException;

    if (shouldLog) {
      try {
        await ErrorLogService.instance.logException(
          userId: userId,
          businessPlaceId: businessPlaceId,
          screenName: screenName,
          action: action,
          exception: error,
          stackTrace: stackTrace,
          severity: _getSeverity(appException),
        );
      } catch (logError) {
        if (kDebugMode) {
          debugPrint('Failed to log error: $logError');
        }
      }
    }

    // 사용자에게 에러 메시지 표시
    if (showSnackbar && context.mounted) {
      await showErrorSnackBar(context, appException.userMessage);
    }
  }

  /// 예외 타입에 따른 심각도 반환
  static ErrorSeverity _getSeverity(AppException error) {
    if (error is ServerException || error is BadGatewayException) {
      return ErrorSeverity.critical;
    }
    if (error is ServiceUnavailableException || error is GatewayTimeoutException) {
      return ErrorSeverity.critical;
    }
    if (error is UnknownException) {
      return ErrorSeverity.error;
    }
    return ErrorSeverity.warning;
  }
}
