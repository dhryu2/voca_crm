import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/core/utils/message_handler.dart';
import 'package:voca_crm/data/datasource/auth_service.dart';
import 'package:voca_crm/data/datasource/biometric_service.dart';
import 'package:voca_crm/data/datasource/user_service.dart';
import 'package:voca_crm/domain/entity/user.dart';
import 'package:voca_crm/presentation/viewmodels/user_view_model.dart';
import 'package:voca_crm/presentation/widgets/character_count_text_field.dart';
import 'package:voca_crm/presentation/widgets/settings_widgets.dart';

import '../admin/system_admin_screen.dart';
import '../auth/login_screen.dart';

class MyPageScreen extends StatefulWidget {
  final User user;

  const MyPageScreen({super.key, required this.user});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final UserService _userService = UserService();
  final BiometricService _biometricService = BiometricService();
  final AuthService _authService = AuthService();

  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isUpdatingPushSetting = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadPushNotificationSetting();
  }

  void _loadPushNotificationSetting() {
    final userViewModel = context.read<UserViewModel>();
    final currentUser = userViewModel.user ?? widget.user;
    setState(() {
      _pushNotifications = currentUser.pushNotificationEnabled;
    });
  }

  Future<void> _checkBiometric() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    setState(() {
      _isBiometricAvailable = available;
      _isBiometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isBiometricEnabled) {
      // Disable biometric
      final confirm = await showDialog<bool>(
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
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
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
                          color: ThemeColor.errorSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint_outlined,
                          size: screenWidth * 0.08,
                          color: ThemeColor.error,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      // Title
                      Text(
                        '생체인식 해제',
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                          letterSpacing: screenWidth * -0.0012,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      // Subtitle
                      Text(
                        '생체인식 로그인을 해제하시겠습니까?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
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
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: ThemeColor.border!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: ThemeColor.textSecondary,
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
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeColor.error,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '해제',
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

      if (confirm == true) {
        await _biometricService.disableBiometric();
        setState(() => _isBiometricEnabled = false);
        if (mounted) {
          AppMessageHandler.showSuccessSnackBar(context, '생체인식이 해제되었습니다');
        }
      }
    } else {
      // Enable biometric
      final confirm = await showDialog<bool>(
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
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.close, color: ThemeColor.textSecondary),
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
                          color: ThemeColor.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint,
                          size: screenWidth * 0.08,
                          color: ThemeColor.primary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      // Title
                      Text(
                        '자동 로그인 사용',
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                          letterSpacing: screenWidth * -0.0012,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      // Subtitle
                      Text(
                        '디바이스의 인증으로 로그인을 하시겠습니까?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
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
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: ThemeColor.border!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: ThemeColor.textSecondary,
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
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeColor.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.03,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '등록',
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

      if (confirm == true) {
        final authenticated = await _biometricService.authenticate();
        if (authenticated) {
          await _biometricService.enableBiometric();
          setState(() => _isBiometricEnabled = true);
          if (mounted) {
            AppMessageHandler.showSuccessSnackBar(context, '등록되었습니다');
          }
        } else {
          if (mounted) {
            AppMessageHandler.showErrorSnackBar(context, '인증에 실패했습니다');
          }
        }
      }
    }
  }

  Future<void> _togglePushNotification(bool value) async {
    if (_isUpdatingPushSetting) return;

    setState(() => _isUpdatingPushSetting = true);

    try {
      final userViewModel = context.read<UserViewModel>();
      final currentUser = userViewModel.user ?? widget.user;

      final updatedUser = await _userService.updatePushNotificationSetting(
        userId: currentUser.providerId,
        enabled: value,
      );

      userViewModel.updateUser(updatedUser);
      setState(() {
        _pushNotifications = value;
        _isUpdatingPushSetting = false;
      });

      if (mounted) {
        AppMessageHandler.showSuccessSnackBar(
          context,
          value ? '알림이 활성화되었습니다' : '알림이 비활성화되었습니다',
        );
      }
    } catch (e, stackTrace) {
      setState(() => _isUpdatingPushSetting = false);
      if (mounted) {
        await AppMessageHandler.handleErrorWithLogging(
          context,
          e,
          stackTrace,
          screenName: 'MyPageScreen',
          action: '알림 설정 변경',
          userId: widget.user.id,
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final userViewModel = context.read<UserViewModel>();
    final currentUser = userViewModel.user ?? widget.user;

    final usernameController = TextEditingController(
      text: currentUser.username,
    );
    final emailController = TextEditingController(text: currentUser.email);
    final phoneController = TextEditingController(text: currentUser.phone);

    await showDialog(
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
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.9,
            maxHeight: screenHeight * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button at top right
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: ThemeColor.textSecondary,
                    size: screenWidth * 0.06,
                  ),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.08,
                    0,
                    screenWidth * 0.08,
                    screenWidth * 0.08,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Large circular icon
                      Container(
                        width: screenWidth * 0.16,
                        height: screenWidth * 0.16,
                        decoration: BoxDecoration(
                          color: ThemeColor.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: screenWidth * 0.08,
                          color: ThemeColor.primary,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Large title
                      Text(
                        '프로필 수정',
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.textPrimary,
                          letterSpacing: screenWidth * -0.0012,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      // Subtitle
                      Text(
                        '개인정보를 수정하세요',
                        style: TextStyle(
                          fontSize: screenWidth * 0.038,
                          color: ThemeColor.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Name input field
                      CharacterCountTextField(
                        controller: usernameController,
                        labelText: '이름 *',
                        hintText: '예: 홍길동',
                        maxLength: InputLimits.username,
                        validationType: ValidationType.name,
                        isRequired: true,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Phone input field
                      CharacterCountTextField(
                        controller: phoneController,
                        labelText: '전화번호 *',
                        hintText: '예: 010-1234-5678',
                        maxLength: InputLimits.phone,
                        keyboardType: TextInputType.phone,
                        validationType: ValidationType.phone,
                        isRequired: true,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Email input field
                      CharacterCountTextField(
                        controller: emailController,
                        labelText: '이메일 (선택)',
                        hintText: '예: example@email.com',
                        maxLength: InputLimits.email,
                        keyboardType: TextInputType.emailAddress,
                        validationType: ValidationType.email,
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Full-width primary button at bottom
                      SizedBox(
                        width: double.infinity,
                        height: screenHeight * 0.065,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (usernameController.text.isEmpty) {
                              AppMessageHandler.showErrorSnackBar(
                                context,
                                '이름은 필수입니다',
                              );
                              return;
                            }

                            if (phoneController.text.isEmpty) {
                              AppMessageHandler.showErrorSnackBar(
                                context,
                                '전화번호는 필수입니다',
                              );
                              return;
                            }

                            try {
                              final updatedUser = await _userService.updateUser(
                                userId: currentUser.providerId,
                                username: usernameController.text,
                                phone: phoneController.text,
                                email: emailController.text.isEmpty
                                    ? null
                                    : emailController.text,
                              );

                              // UserViewModel 갱신
                              userViewModel.updateUser(updatedUser);

                              if (context.mounted) {
                                Navigator.pop(context);
                                AppMessageHandler.showSuccessSnackBar(
                                  context,
                                  '프로필이 업데이트되었습니다',
                                );
                              }
                            } catch (e, stackTrace) {
                              if (context.mounted) {
                                await AppMessageHandler.handleErrorWithLogging(
                                  context,
                                  e,
                                  stackTrace,
                                  screenName: 'MyPageScreen',
                                  action: '프로필 수정',
                                  userId: currentUser.id,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColor.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                            ),
                          ),
                          child: Text(
                            '저장하기',
                            style: TextStyle(
                              fontSize: screenWidth * 0.043,
                              fontWeight: FontWeight.w700,
                              letterSpacing: screenWidth * -0.0008,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final confirm = await showDialog<bool>(
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
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close, color: ThemeColor.textSecondary),
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
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_outlined,
                        size: screenWidth * 0.08,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    // Title
                    Text(
                      '회원 탈퇴',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                        letterSpacing: screenWidth * -0.0012,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    // Subtitle
                    Text(
                      '정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        color: ThemeColor.textSecondary,
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
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: ThemeColor.border!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: ThemeColor.textSecondary,
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
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColor.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                ),
                              ),
                              child: Text(
                                '탈퇴',
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

    if (confirm == true) {
      try {
        final userViewModel = context.read<UserViewModel>();
        await _userService.deleteUser(
          userViewModel.user?.providerId ?? widget.user.providerId,
        );
        await _authService.logout();
        userViewModel.clearUser();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          AppMessageHandler.showSuccessSnackBar(context, '회원 탈퇴가 완료되었습니다');
        }
      } catch (e, stackTrace) {
        if (mounted) {
          await AppMessageHandler.handleErrorWithLogging(
            context,
            e,
            stackTrace,
            screenName: 'MyPageScreen',
            action: '회원 탈퇴',
            userId: widget.user.id,
          );
        }
      }
    }
  }

  void _handleLogout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
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
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: ThemeColor.textSecondary),
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
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout,
                        size: screenWidth * 0.08,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    // Title
                    Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.textPrimary,
                        letterSpacing: screenWidth * -0.0012,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    // Subtitle
                    Text(
                      '정말 로그아웃 하시겠습니까?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038,
                        color: ThemeColor.textSecondary,
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
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: ThemeColor.border!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                ),
                              ),
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: ThemeColor.textSecondary,
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
                              onPressed: () {
                                _authService.logout();
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColor.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    screenWidth * 0.03,
                                  ),
                                ),
                              ),
                              child: Text(
                                '로그아웃',
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ThemeColor.background,
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/app_logo2.png',
          height: screenHeight * 0.04,
          fit: BoxFit.contain,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: screenHeight * 0.04),
        child: Column(
          children: [
            // Profile Header
            Consumer<UserViewModel>(
              builder: (context, userViewModel, child) {
                final currentUser = userViewModel.user ?? widget.user;
                return Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(screenWidth * 0.06),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              ThemeColor.primary,
                              ThemeColor.primary.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeColor.primary.withValues(alpha: 0.3),
                              blurRadius: screenWidth * 0.03,
                              offset: Offset(0, screenHeight * 0.005),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: screenWidth * 0.09,
                          backgroundColor: Colors.transparent,
                          child: Text(
                            currentUser.username.isNotEmpty
                                ? currentUser.username.substring(0, 1)
                                : '?',
                            style: TextStyle(
                              fontSize: screenWidth * 0.07,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.05),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.username,
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.bold,
                                color: ThemeColor.textPrimary,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.007),
                            Text(
                              currentUser.email,
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: ThemeColor.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: ThemeColor.neutral100,
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: screenWidth * 0.05,
                          ),
                          onPressed: _showEditProfileDialog,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: screenHeight * 0.015),

            // Account Settings
            SettingsSection(
              title: '계정',
              tiles: [
                SettingsTile(
                  icon: Icons.person_outline,
                  title: '개인정보 수정',
                  onTap: _showEditProfileDialog,
                ),
                SettingsTile(
                  icon: Icons.delete_outline,
                  title: '회원 탈퇴',
                  iconColor: ThemeColor.error,
                  titleColor: ThemeColor.error,
                  showDivider: false,
                  onTap: _handleDeleteAccount,
                ),
              ],
            ),

            SizedBox(height: screenHeight * 0.015),

            // Security Settings
            if (_isBiometricAvailable)
              SettingsSection(
                title: '보안',
                tiles: [
                  SettingsTile(
                    icon: Icons.lock_person,
                    title: '생체인식 로그인',
                    trailing: Switch(
                      value: _isBiometricEnabled,
                      activeColor: ThemeColor.primary,
                      onChanged: (value) => _toggleBiometric(),
                    ),
                    showDivider: false,
                    onTap: () => _toggleBiometric(),
                  ),
                ],
              ),

            if (_isBiometricAvailable) SizedBox(height: screenHeight * 0.015),

            // App Settings
            SettingsSection(
              title: '앱 설정',
              tiles: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 설정',
                  trailing: _isUpdatingPushSetting
                      ? SizedBox(
                          width: screenWidth * 0.06,
                          height: screenWidth * 0.06,
                          child: CircularProgressIndicator(
                            strokeWidth: screenWidth * 0.005,
                            color: ThemeColor.primary,
                          ),
                        )
                      : Switch(
                          value: _pushNotifications,
                          activeColor: ThemeColor.primary,
                          onChanged: _togglePushNotification,
                        ),
                  showDivider: false,
                  onTap: _isUpdatingPushSetting
                      ? null
                      : () => _togglePushNotification(!_pushNotifications),
                ),
                // SettingsTile(
                //   icon: Icons.dark_mode_outlined,
                //   title: '다크 모드',
                //   trailing: Switch(
                //     value: _darkMode,
                //     activeColor: ThemeColor.primary,
                //     onChanged: (value) {
                //       setState(() => _darkMode = value);
                //     },
                //   ),
                //   onTap: () {
                //     setState(() => _darkMode = !_darkMode);
                //   },
                // ),
                // SettingsTile(
                //   icon: Icons.language,
                //   title: '언어 및 지역',
                //   trailing: Icon(
                //     Icons.chevron_right,
                //     color: ThemeColor.textTertiary,
                //   ),
                //   showDivider: false,
                //   onTap: () {
                //     AppMessageHandler.showSnackBar(context, '언어 및 지역 설정 준비 중');
                //   },
                // ),
              ],
            ),

            SizedBox(height: screenHeight * 0.015),

            // System Admin (시스템 관리자만 표시)
            Consumer<UserViewModel>(
              builder: (context, userViewModel, child) {
                final currentUser = userViewModel.user ?? widget.user;
                if (!currentUser.isSystemAdmin) return const SizedBox.shrink();

                return Column(
                  children: [
                    SettingsSection(
                      title: '시스템 관리',
                      tiles: [
                        SettingsTile(
                          icon: Icons.admin_panel_settings_outlined,
                          title: '공지사항 관리',
                          trailing: Icon(
                            Icons.chevron_right,
                            color: ThemeColor.textTertiary,
                          ),
                          iconColor: ThemeColor.primary,
                          showDivider: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SystemAdminScreen(user: widget.user),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.015),
                  ],
                );
              },
            ),

            // App Info
            SettingsSection(
              title: '앱 정보',
              tiles: [
                SettingsTile(
                  icon: Icons.info_outline,
                  title: '버전 정보',
                  showDivider: false,
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                      color: ThemeColor.textSecondary,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                  onTap: () {},
                ),
                // SettingsTile(
                //   icon: Icons.description_outlined,
                //   title: '이용약관',
                //   onTap: () {},
                // ),
                // SettingsTile(
                //   icon: Icons.privacy_tip_outlined,
                //   title: '개인정보 처리방침',
                //   onTap: () {},
                // ),
                // SettingsTile(
                //   icon: Icons.help_outline,
                //   title: '문의하기',
                //   showDivider: false,
                //   onTap: () {},
                // ),
              ],
            ),

            SizedBox(height: screenHeight * 0.04),

            // Logout Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThemeColor.error,
                    side: BorderSide(
                      color: ThemeColor.error.withValues(alpha: 0.5),
                      width: screenWidth * 0.004,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: screenWidth * 0.055),
                      SizedBox(width: screenWidth * 0.03),
                      Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.03),
            Text(
              'VocaCRM v1.0.0',
              style: TextStyle(
                color: ThemeColor.textTertiary,
                fontSize: screenWidth * 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
