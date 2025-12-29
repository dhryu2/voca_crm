import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/auth_service.dart';
import 'package:voca_crm/data/datasource/social_auth_service.dart';
import 'package:voca_crm/presentation/screens/auth/signup_screen.dart';
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final SocialAuthService _firebaseAuthService = SocialAuthService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);

    try {
      SocialAuthResult result;

      switch (provider) {
        case 'google':
          result = await _firebaseAuthService.signInWithGoogle();
          break;
        case 'kakao':
          result = await _firebaseAuthService.signInWithKakao();
          break;
        case 'apple':
          result = await _firebaseAuthService.signInWithApple();
          break;
        default:
          throw Exception('지원하지 않는 로그인 방식입니다');
      }

      // Provider와 Token으로 백엔드 로그인
      final loginResult = await _authService.login(
        provider: result.provider,
        token: result.idToken,
      );

      // JWT 토큰 저장
      await _authService.saveTokens(
        accessToken: loginResult.accessToken,
        refreshToken: loginResult.refreshToken,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        // UserViewModel에 user 설정
        Provider.of<UserViewModel>(context, listen: false)
            .setUser(loginResult.user);

        // MainScreen으로 이동 (user 정보 전달)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(user: loginResult.user),
          ),
          (route) => false,
        );
      }
    } on UserNotFoundException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, '등록되지 않은 사용자입니다. 회원가입을 진행해주세요');
      }
    } on InvalidTokenException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, '유효하지 않은 인증 토큰입니다');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('취소')) {
          // 사용자가 취소한 경우 메시지 표시 안함
          return;
        }
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: screenHeight * 0.1),

                          // Logo Section
                          Container(
                            width: screenWidth * 0.2,
                            height: screenWidth * 0.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: ThemeColor.primaryGradient,
                              ),
                              borderRadius: BorderRadius.circular(screenWidth * 0.05),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColor.primary.withValues(alpha: 0.25),
                                  blurRadius: screenWidth * 0.05,
                                  offset: Offset(0, screenWidth * 0.02),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            child: Image.asset(
                              'assets/images/app_logo1.png',
                              fit: BoxFit.contain,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.035),

                          // App Name
                          Text(
                            'VocaCRM',
                            style: TextStyle(
                              fontSize: screenWidth * 0.08,
                              fontWeight: FontWeight.w800,
                              color: ThemeColor.textPrimary,
                              letterSpacing: screenWidth * -0.003,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.01),

                          // Tagline
                          Text(
                            '음성으로 더 쉬운 고객 관리',
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w400,
                              color: ThemeColor.textSecondary,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.08),

                          // Welcome Text
                          Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: screenWidth * 0.055,
                              fontWeight: FontWeight.w700,
                              color: ThemeColor.textPrimary,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.01),

                          Text(
                            '소셜 계정으로 간편하게 로그인하세요',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: ThemeColor.textSecondary,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.04),

                          // Social Login Buttons
                          _buildSocialLoginButton(
                            label: 'Google로 계속하기',
                            iconPath: 'assets/images/google_logo.png',
                            backgroundColor: ThemeColor.surface,
                            textColor: ThemeColor.textPrimary,
                            borderColor: ThemeColor.border,
                            onPressed: _isLoading
                                ? null
                                : () => _handleSocialLogin('google'),
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                          ),

                          SizedBox(height: screenHeight * 0.015),

                          _buildSocialLoginButton(
                            label: 'Kakao로 계속하기',
                            iconPath: 'assets/images/kakao_logo.png',
                            backgroundColor: const Color(0xFFFEE500),
                            textColor: const Color(0xFF191919),
                            borderColor: const Color(0xFFFEE500),
                            onPressed: _isLoading
                                ? null
                                : () => _handleSocialLogin('kakao'),
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                          ),

                          if (Platform.isIOS) ...[
                            SizedBox(height: screenHeight * 0.015),
                            _buildSocialLoginButton(
                              label: 'Apple로 계속하기',
                              iconPath: 'assets/images/apple_logo.png',
                              backgroundColor: ThemeColor.neutral900,
                              textColor: Colors.white,
                              borderColor: ThemeColor.neutral900,
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleSocialLogin('apple'),
                              screenWidth: screenWidth,
                              screenHeight: screenHeight,
                            ),
                          ],

                          SizedBox(height: screenHeight * 0.05),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: screenHeight * 0.001,
                                  color: ThemeColor.border,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                ),
                                child: Text(
                                  '또는',
                                  style: TextStyle(
                                    color: ThemeColor.textTertiary,
                                    fontSize: screenWidth * 0.032,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: screenHeight * 0.001,
                                  color: ThemeColor.border,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: screenHeight * 0.035),

                          // Signup Link
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignupScreen(),
                                      ),
                                    );
                                  },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: screenHeight * 0.015,
                                horizontal: screenWidth * 0.06,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColor.primarySurface,
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '처음이신가요?',
                                    style: TextStyle(
                                      color: ThemeColor.textSecondary,
                                      fontSize: screenWidth * 0.035,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(
                                    '회원가입',
                                    style: TextStyle(
                                      color: ThemeColor.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: screenWidth * 0.035,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: ThemeColor.primary,
                                    size: screenWidth * 0.04,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.04),

                          // Loading indicator
                          if (_isLoading)
                            Column(
                              children: [
                                SizedBox(
                                  width: screenWidth * 0.06,
                                  height: screenWidth * 0.06,
                                  child: CircularProgressIndicator(
                                    strokeWidth: screenWidth * 0.006,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ThemeColor.primary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.015),
                                Text(
                                  '로그인 중...',
                                  style: TextStyle(
                                    color: ThemeColor.textSecondary,
                                    fontSize: screenWidth * 0.032,
                                  ),
                                ),
                              ],
                            ),

                          SizedBox(height: screenHeight * 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required String label,
    required String iconPath,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback? onPressed,
    required double screenWidth,
    required double screenHeight,
  }) {
    final bool isDisabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.065,
      child: Material(
        color: isDisabled ? backgroundColor.withValues(alpha: 0.6) : backgroundColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.035),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(screenWidth * 0.035),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(screenWidth * 0.035),
              border: Border.all(
                color: isDisabled ? borderColor.withValues(alpha: 0.5) : borderColor,
                width: screenWidth * 0.004,
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: screenWidth * 0.05),
                Image.asset(
                  iconPath,
                  height: screenWidth * 0.055,
                  width: screenWidth * 0.055,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDisabled
                            ? textColor.withValues(alpha: 0.5)
                            : textColor,
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        letterSpacing: screenWidth * -0.0008,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.055 + screenWidth * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
