import 'dart:io';

import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/auth_service.dart';
import 'package:voca_crm/data/datasource/social_auth_service.dart';
import 'package:voca_crm/presentation/screens/auth/login_screen.dart';
import 'package:voca_crm/presentation/screens/main_screen.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/custom_button.dart';
import 'package:voca_crm/presentation/widgets/phone_number_field.dart';
import 'package:voca_crm/presentation/widgets/signup_progress_indicator.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Firebase Auth Result
  String? _idToken;
  String? _displayName;
  String? _provider;

  // Step 2: User Info
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final SocialAuthService _firebaseAuthService = SocialAuthService();

  @override
  void initState() {
    super.initState();
    _emailController.clear();
    _usernameController.clear();
    _phoneController.clear();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

      // 소셜 인증 성공 - 정보 저장
      setState(() {
        _idToken = result.idToken;
        _displayName = result.displayName;
        _provider = result.provider;
        _isLoading = false;

        // displayName을 기본값으로 설정
        if (_displayName != null && _displayName!.isNotEmpty) {
          _usernameController.text = _displayName!;
        }

        // 이메일 설정 (중첩 setState 제거)
        _emailController.text = result.email ?? "";
      });

      // 다음 단계로 이동
      _nextStep();
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

  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (username.length < 2) {
      AppMessageHandler.showErrorSnackBar(context, '이름은 2자 이상 입력해주세요');
      return;
    }

    if (phone.isEmpty) {
      AppMessageHandler.showErrorSnackBar(context, '전화번호를 입력해주세요');
      return;
    }

    if (_idToken == null) {
      AppMessageHandler.showErrorSnackBar(context, '소셜 인증 정보가 없습니다. 다시 시도해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final loginResult = await _authService.signup(
        provider: _provider!,
        token: _idToken!,
        username: username,
        phone: phone,
        email: email.isNotEmpty ? email : null,
      );

      // JWT 토큰 저장
      await _authService.saveTokens(
        accessToken: loginResult.accessToken,
        refreshToken: loginResult.refreshToken,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(context, '회원가입이 완료되었습니다!');

        // MainScreen으로 이동 (user 정보 전달)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(user: loginResult.user),
          ),
          (route) => false,
        );
      }
    } on DuplicateUserException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));

        // 로그인 화면으로 이동
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        });
      }
    } on InvalidInputException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.showErrorSnackBar(context, AppMessageHandler.parseErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: ThemeColor.textPrimary,
            size: screenWidth * 0.06,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              SignupProgressIndicator(
                currentStep: _currentStep,
                totalSteps: 2,
                stepTitles: const ['소셜 인증', '정보 입력'],
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(constraints),
                    _buildStep2(constraints),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep1(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.08,
        vertical: screenHeight * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.02),
          Text(
            '회원가입 방법 선택',
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            '소셜 계정으로 간편하게 가입하세요',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: ThemeColor.textSecondary,
            ),
          ),
          SizedBox(height: screenHeight * 0.05),
          // Google 로그인 버튼
          _buildSocialSingUpButton(
            label: 'Google로 계속하기',
            path: "assets/images/google_logo.png",
            backgroundColor: Colors.white,
            textColor: ThemeColor.textPrimary,
            borderColor: ThemeColor.border,
            onPressed: _isLoading ? null : () => _handleSocialLogin('google'),
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
          SizedBox(height: screenHeight * 0.02),
          // Kakao 로그인 버튼
          _buildSocialSingUpButton(
            label: 'Kakao로 계속하기',
            path: "assets/images/kakao_logo.png",
            backgroundColor: const Color(0xFFFEE500),
            textColor: ThemeColor.textPrimary,
            borderColor: const Color(0xFFFEE500),
            onPressed: _isLoading ? null : () => _handleSocialLogin('kakao'),
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
          SizedBox(height: screenHeight * 0.02),
          // Apple 로그인 버튼 (iOS only)
          if (Platform.isIOS)
            _buildSocialSingUpButton(
              label: 'Apple로 계속하기',
              path: "assets/images/apple_logo.png",
              backgroundColor: Colors.black,
              textColor: Colors.white,
              borderColor: Colors.black,
              onPressed: _isLoading ? null : () => _handleSocialLogin('apple'),
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
        ],
      ),
    );
  }

  Widget _buildSocialSingUpButton({
    required String label,
    required String path,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback? onPressed,
    required double screenWidth,
    required double screenHeight,
  }) {
    final double logoSize = screenWidth * 0.06;
    final double spacing = screenWidth * 0.04;

    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.07,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          side: BorderSide(color: borderColor, width: screenWidth * 0.002),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
          ),
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: spacing),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset(path, height: logoSize, width: logoSize),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: logoSize, height: logoSize),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.08,
        vertical: screenHeight * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.02),
          Text(
            '기본 정보 입력',
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            '서비스 이용을 위한 정보를 입력해주세요',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: ThemeColor.textSecondary,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          // 사용자 이름
          CharacterCountTextField(
            controller: _usernameController,
            labelText: '이름 *',
            hintText: '이름을 입력하세요',
            maxLength: InputLimits.username,
            validationType: ValidationType.name,
            isRequired: true,
          ),
          SizedBox(height: screenHeight * 0.02),
          // 전화번호
          PhoneNumberField(
            controller: _phoneController,
            labelText: '전화번호 *',
            hintText: '010-0000-0000',
            isRequired: true,
          ),
          SizedBox(height: screenHeight * 0.02),
          // 이메일 (소셜 로그인에서 자동 입력됨)
          CharacterCountTextField(
            controller: _emailController,
            labelText: '이메일',
            hintText: 'hong@example.com',
            maxLength: InputLimits.email,
            keyboardType: TextInputType.emailAddress,
            validationType: ValidationType.email,
          ),
          SizedBox(height: screenHeight * 0.05),
          // 회원가입 버튼
          SizedBox(
            width: double.infinity,
            height: screenHeight * 0.07,
            child: CustomButton(
              onPressed: _isLoading ? null : _handleSignup,
              child: Text(_isLoading ? '처리 중...' : '회원가입'),
            ),
          ),
        ],
      ),
    );
  }
}
