import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wayable/model/user/user.dart';
import 'package:wayable/services/user_service.dart';
import 'package:wayable/utils/app_logger.dart';

class KakaoAuthService {
  final _userService = UserService();

  Future<({AppUser? user, bool isNewUser})> signInWithKakao() async {
    try {
      kakao.OAuthToken token;

      // 카카오톡 설치 여부 확인
      if (await kakao.isKakaoTalkInstalled()) {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

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

      final uid = userCredential.user!.uid;
      AppLogger.debug('[Auth] Kakao login success');

      final exists = await _userService.userExists(uid);

      if (!exists) {
        final newUser = AppUser(
          uid: uid,
          nickname: kakaoUser.kakaoAccount?.profile?.nickname,
          email: null,
          provider: 'kakao',
        );

        // 저장 전 데이터 확인
        AppLogger.debug('[Auth] 저장할 유저 데이터: ${newUser.toFirestore()}');

        await _userService.createUser(newUser);
        AppLogger.info('[Auth] 신규 카카오 유저 저장 완료');
        return (user: newUser, isNewUser: true);
      } else {
        // 기존 유저 → Firestore에서 불러오기
        final existingUser = await _userService.getUser(uid);
        AppLogger.debug('[UserService] 문서 존재 여부: ${existingUser != null}');
        AppLogger.info('[Auth] 기존 카카오 유저 로그인');
        return (user: existingUser, isNewUser: false);
      }
    } catch (e) {
      AppLogger.error('[Auth] Kakao login failed', error: e);
      AppLogger.debug('[Auth] 에러 타입: ${e.runtimeType}');
      return (user: null, isNewUser: false);
    }
  }

  Future<void> signOut() async {
    try {
      await kakao.UserApi.instance.logout();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      AppLogger.error('[Auth] Kakao sign out failed', error: e);
    }
  }
}
