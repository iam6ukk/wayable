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

      // 카카오 사용자 정보(me) 조회와 Cloud Functions 커스텀 토큰 발급은
      // 서로 결과값에 의존하지 않고 둘 다 accessToken만 있으면 되므로
      // 동시에 실행해 대기 시간을 줄인다.
      final meFuture = kakao.UserApi.instance.me();
      final tokenFuture = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('kakaoCustomToken').call({
        'kakaoAccessToken': token.accessToken,
      });

      final kakaoUser = await meFuture;
      final result = await tokenFuture;

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
          email: kakaoUser.kakaoAccount?.email,
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
