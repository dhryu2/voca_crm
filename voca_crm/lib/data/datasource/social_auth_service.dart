import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthResult {
  final String idToken;
  final String? email;
  final String? displayName;
  final String provider;

  SocialAuthResult({
    required this.idToken,
    this.email,
    this.displayName,
    required this.provider,
  });
}

class SocialAuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Google 로그인
  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      // Google 로그인 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('사용자가 Google 로그인을 취소했습니다');
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 자격 증명 생성
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase 인증
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      // Firebase ID Token 가져오기
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        throw Exception('Firebase ID Token을 가져올 수 없습니다');
      }

      return SocialAuthResult(
        idToken: idToken,
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
        provider: 'google.com',
      );
    } catch (e) {
      if (e.toString().contains('취소')) {
        rethrow;
      }
      throw Exception('Google 로그인에 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// Kakao 로그인
  Future<SocialAuthResult> signInWithKakao() async {
    try {
      // Kakao 로그인 가능 여부 확인
      bool kakaoTalkInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (kakaoTalkInstalled) {
        // 카카오톡 앱으로 로그인
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        // 카카오 계정으로 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      //카카오 사용자 정보 가져오기
      User kakaoUser = await UserApi.instance.me();

      return SocialAuthResult(
        idToken: token.accessToken, // 실제로는 Firebase Custom Token이어야 함
        email: kakaoUser.kakaoAccount?.email,
        displayName: kakaoUser.kakaoAccount?.profile?.nickname,
        provider: 'kakao.com',
      );
    } catch (e) {
      if (e.toString().contains('취소') || e.toString().contains('cancel')) {
        throw Exception('사용자가 카카오 로그인을 취소했습니다');
      }
      throw Exception('카카오 로그인에 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// Apple 로그인 (iOS만 지원)
  Future<SocialAuthResult> signInWithApple() async {
    if (!Platform.isIOS) {
      throw Exception('Apple 로그인은 iOS에서만 지원됩니다');
    }

    try {
      // Apple 로그인 시작
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Firebase OAuthProvider 생성
      final oauthCredential = firebase_auth.OAuthProvider('apple.com')
          .credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );

      // Firebase 인증
      final userCredential = await _firebaseAuth.signInWithCredential(
        oauthCredential,
      );

      // Firebase ID Token 가져오기
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        throw Exception('Firebase ID Token을 가져올 수 없습니다');
      }

      // Apple은 첫 로그인 시에만 이름 정보를 제공
      String? displayName;
      if (appleCredential.givenName != null &&
          appleCredential.familyName != null) {
        displayName =
            '${appleCredential.familyName}${appleCredential.givenName}';
      }

      return SocialAuthResult(
        idToken: idToken,
        email: appleCredential.email ?? userCredential.user?.email,
        displayName: displayName ?? userCredential.user?.displayName,
        provider: 'apple.com',
      );
    } catch (e) {
      if (e.toString().contains('취소') || e.toString().contains('cancel')) {
        throw Exception('사용자가 Apple 로그인을 취소했습니다');
      }
      throw Exception('Apple 로그인에 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// 현재 로그인된 사용자의 ID Token 가져오기
  Future<String?> getCurrentUserIdToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    // Kakao 로그아웃은 필요시 추가
    // await UserApi.instance.logout();
  }
}
