import 'package:flutter/material.dart';
import 'package:voca_crm/core/auth/token_manager.dart';
import 'package:voca_crm/core/session/session_manager.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/auth_service.dart';
import 'package:voca_crm/data/datasource/biometric_service.dart';
import 'package:voca_crm/domain/entity/tokens.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/screens/auth/login_screen.dart';

import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final TokenManager _tokenManager = TokenManager.instance;

  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _pulseAnimation;

  Tokens? _tokens;
  bool _isFailureBiometricLogin = false;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Fade controller for text and buttons
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Pulse animation for loading indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Logo scale animation with elastic effect
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Logo opacity animation
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Text opacity animation
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Pulse animation
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fadeController.forward();
    });

    _checkBiometricLogin();
  }

  Future<void> _checkBiometricLogin() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      // Get saved tokens
      _tokens = await _tokenManager.getTokens();
      // Check use biometric login
      final enabled = await _biometricService.isBiometricEnabled();
      if (!enabled || _tokens == null) {
        if (mounted) {
          _moveLoginPage();
        }
      } else {
        await _tryBiometricLogin();
      }
    } catch (e) {
      // Auto-login failed
    }
  }

  Future<void> _tryBiometricLogin() async {
    try {
      User? user = await _biometricLogin();
      if (!mounted) return;

      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen(user: user)),
        );
      } else {
        setState(() {
          _isFailureBiometricLogin = true;
        });
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, '시스템 오류로 인증 실패했습니다.');
      }
    }
  }

  Future<User?> _biometricLogin() async {
    if (_tokens == null) {
      _moveLoginPage();
      return null;
    }

    // 생체 인증 시도
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return null;

    try {
      // Refresh access token using saved refresh token
      final result = await _authService.refreshToken(_tokens!.refreshToken);

      // Update stored tokens with new access token
      await _tokenManager.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      // 세션 시작 (refreshToken에서도 호출되지만 명시적으로 시작)
      SessionManager.instance.startSession(accessToken: result.accessToken);

      if (mounted) {
        return result.user;
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleApiError(context, e);
        return null;
      }
    }
    return null;
  }

  void _moveLoginPage() {
    if (!mounted) return;  // mounted 체크 추가
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ThemeColor.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Main content area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with animation
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: Container(
                              width: screenWidth * 0.24,
                              height: screenWidth * 0.24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: ThemeColor.primaryGradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.06,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColor.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: screenWidth * 0.06,
                                    offset: Offset(0, screenWidth * 0.02),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(screenWidth * 0.05),
                              child: Image.asset(
                                'assets/images/app_logo1.png',
                                fit: BoxFit.contain,
                                color: Colors.white,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // App name with fade animation
                    AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                'VocaCRM',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.085,
                                  fontWeight: FontWeight.w800,
                                  color: ThemeColor.textPrimary,
                                  letterSpacing: screenWidth * -0.003,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.012),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.008,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColor.primarySurface,
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.05,
                                  ),
                                ),
                                child: Text(
                                  '음성으로 더 쉬운 고객 관리',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.034,
                                    fontWeight: FontWeight.w500,
                                    color: ThemeColor.primary,
                                    letterSpacing: screenWidth * -0.0005,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom section with buttons (when biometric fails)
            if (_isFailureBiometricLogin)
              AnimatedOpacity(
                opacity: _isFailureBiometricLogin ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.06,
                    0,
                    screenWidth * 0.06,
                    screenHeight * 0.05,
                  ),
                  child: Column(
                    children: [
                      // Biometric retry button (Primary)
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.065,
                        child: ElevatedButton(
                          onPressed: _tryBiometricLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColor.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: ThemeColor.primary.withValues(
                              alpha: 0.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.035,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, size: screenWidth * 0.06),
                              SizedBox(width: screenWidth * 0.025),
                              Text(
                                '생체 인증으로 시작하기',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: screenWidth * -0.0008,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Login page button (Secondary)
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.065,
                        child: TextButton(
                          onPressed: _moveLoginPage,
                          style: TextButton.styleFrom(
                            foregroundColor: ThemeColor.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.035,
                              ),
                              side: BorderSide(
                                color: ThemeColor.border,
                                width: screenWidth * 0.002,
                              ),
                            ),
                          ),
                          child: Text(
                            '아이디로 로그인',
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w500,
                              letterSpacing: screenWidth * -0.0008,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Modern loading indicator when checking biometric
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.08),
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacityAnimation.value,
                      child: Column(
                        children: [
                          // Modern dot loading indicator
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  return Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.01,
                                    ),
                                    child: Transform.scale(
                                      scale: index == 1
                                          ? _pulseAnimation.value
                                          : 1.0 -
                                                (_pulseAnimation.value - 0.8) *
                                                    0.5,
                                      child: Container(
                                        width: screenWidth * 0.02,
                                        height: screenWidth * 0.02,
                                        decoration: BoxDecoration(
                                          color: ThemeColor.primary.withValues(
                                            alpha: index == 1 ? 1.0 : 0.4,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          Text(
                            '로그인 정보를 확인하고 있습니다',
                            style: TextStyle(
                              fontSize: screenWidth * 0.032,
                              color: ThemeColor.textTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
