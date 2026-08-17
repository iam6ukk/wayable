import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wayable/model/user/user.dart';
import 'package:wayable/services/bookmark/bookmark_service.dart';
import 'package:wayable/services/user_service.dart';
import 'package:wayable/utils/app_logger.dart';

class KakaoAuthService {
  final _userService = UserService();
  final _bookmarkService = BookmarkService();

  // 로그인
  Future<({AppUser? user, bool isNewUser})> signInWithKakao() async {
    try {
      kakao.OAuthToken token;

      // 1. 카카오톡 설치 여부 확인
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          // 사용자가 명시적으로 취소한 경우는 폴백하지 않고 그대로 종료
          if (error is PlatformException && error.code == 'CANCELED') {
            AppLogger.debug('[Auth] 카카오톡 로그인 사용자 취소');
            return (user: null, isNewUser: false);
          }

          // 카카오톡은 설치돼 있지만 계정 미연동(NotSupportError) 등으로
          // Talk 로그인이 실패한 경우 카카오계정(웹) 로그인으로 폴백
          AppLogger.debug('[Auth] 카카오톡 로그인 실패, 카카오계정 로그인으로 폴백: $error');
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      final meFuture = kakao.UserApi.instance.me();
      final tokenFuture =
          FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('kakaoCustomToken')
              .call({'kakaoAccessToken': token.accessToken});

      final kakaoUser = await meFuture;
      final result = await tokenFuture;

      final firebaseToken = result.data['firebaseToken'];

      // 2. Firebase Custom Token으로 로그인
      final userCredential = await FirebaseAuth.instance.signInWithCustomToken(
        firebaseToken,
      );

      final uid = userCredential.user!.uid;
      AppLogger.debug('[Auth] 카카오 로그인 성공');

      final exists = await _userService.userExists(uid);

      // 3. 신규/기존 유저에 따라 분기 처리
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
        var existingUser = await _userService.getUser(uid);
        AppLogger.debug('[UserService] 문서 존재 여부: ${existingUser != null}');
        AppLogger.info('[Auth] 기존 카카오 유저 로그인');

        // 가입 당시 닉네임 동의항목이 없었거나 응답이 비어 저장을 못 한 경우,
        // 이번 로그인에서 받아온 닉네임으로 보정한다.
        final freshNickname = kakaoUser.kakaoAccount?.profile?.nickname;
        if (existingUser != null &&
            (existingUser.nickname == null ||
                existingUser.nickname!.isEmpty) &&
            freshNickname != null &&
            freshNickname.isNotEmpty) {
          existingUser = existingUser.copyWith(nickname: freshNickname);
          await _userService.updateUser(existingUser);
          AppLogger.info('[Auth] 기존 카카오 유저 닉네임 보정 완료');
        }

        return (user: existingUser, isNewUser: false);
      }
    } catch (e) {
      AppLogger.error('[Auth] 카카오 로그인 실패', error: e);
      AppLogger.debug('[Auth] 에러 타입: ${e.runtimeType}');
      return (user: null, isNewUser: false);
    }
  }

  // 회원탈퇴
  // 북마크 삭제 → Firestore 유저 문서 삭제 → Firebase 계정 삭제 → 카카오 연결 해제
  Future<bool> deleteAccount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // 유저 문서보다 먼저 지워야, 중간에 앱이 죽어 재시도하더라도
        // 이미 지운 문서는 멱등하게 건너뛰고 남은 것만 마저 정리된다.
        await _bookmarkService.deleteAllBookmarks(uid);
        await _userService.deleteUser(uid);
      }

      await FirebaseAuth.instance.currentUser?.delete();
      await kakao.UserApi.instance.unlink();
      // 카카오 unlink를 먼저 하면 세션은 남았는데 앱-계정 연결만 끊김
      // 이후 재로그인 시 데이터 정리가 애매해져 마지막에 수행

      AppLogger.info('[Auth] 카카오 회원탈퇴 완료');
      return true;
    } catch (e) {
      AppLogger.error('[Auth] 카카오 회원탈퇴 실패', error: e);
      return false;
    }
  }

  // 로그아웃
  Future<bool> logout() async {
    try {
      await kakao.UserApi.instance.logout();
      await FirebaseAuth.instance.signOut();

      AppLogger.info('[Auth] 카카오 로그아웃 완료');
      return true;
    } catch (e) {
      AppLogger.error('[Auth] 카카오 로그아웃 실패', error: e);
      return false;
    }
  }
}
