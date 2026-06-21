import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wayable/model/user.dart';

class KakaoAuthService {
  Future<AppUser?> signInWithKakao() async {
    try {
      kakao.OAuthToken token;

      // 카카오톡 설치 여부 확인
      if (await kakao.isKakaoTalkInstalled()) {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      print('카카오 로그인 성공! 토큰: ${token.accessToken}');

      // 카카오 사용자 정보 가져오기 (닉네임 등)
      kakao.User kakaoUser = await kakao.UserApi.instance.me();

      // Cloud Functions 호출 -> Firebase Custom Token 받기
      final callable = FirebaseFunctions.instance.httpsCallable(
        'kakaoCustomToken',
      );
      final result = await callable.call({
        'kakaoAccessToken': token.accessToken,
      });

      final firebaseToken = result.data['firebaseToken'];

      // Firebase Custom Token으로 로그인
      final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
        firebaseToken,
      );

      print('Firebase 로그인 성공! UID: ${userCredential.user?.uid}');

      return AppUser(
        uid: userCredential.user!.uid,
        nickname: kakaoUser.kakaoAccount?.profile?.nickname,
      );
    } catch (e) {
      print('카카오 로그인 실패: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await kakao.UserApi.instance.logout();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('카카오 로그아웃 실패: $e');
    }
  }
}
