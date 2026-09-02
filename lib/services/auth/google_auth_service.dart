import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wayable/model/user/user.dart';
import 'package:wayable/services/bookmark/bookmark_service.dart';
import 'package:wayable/services/user_service.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _userService = UserService();
  final _bookmarkService = BookmarkService();
  bool _initialized = false;

  Future<void> initGoogleSignIn() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_CLIENT_ID']!,
    );
    _initialized = true;
  }

  Future<({AppUser? user, bool isNewUser})> signInWithGoogle() async {
    try {
      await initGoogleSignIn();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) return (user: null, isNewUser: false);

      final uid = firebaseUser.uid;
      AppLogger.debug('[Auth] Google login success');

      final exists = await _userService.userExists(uid);

      if (!exists) {
        // 신규 유저 → Firestore에 저장
        final newUser = AppUser(
          uid: uid,
          nickname: firebaseUser.displayName,
          email: firebaseUser.email, // 구글은 이메일 바로 받을 수 있음
          provider: 'google',
        );
        await _userService.createUser(newUser);
        AppLogger.info('[Auth] 신규 구글 유저 저장 완료');
        return (user: newUser, isNewUser: true);
      } else {
        // 기존 유저 → Firestore에서 불러오기
        var existingUser = await _userService.getUser(uid);
        AppLogger.info('[Auth] 기존 구글 유저 로그인');

        // 가입 당시 표시 이름을 못 받아와 저장을 못 한 경우, 이번 로그인에서
        // 받아온 닉네임으로 보정한다.
        final freshNickname = firebaseUser.displayName;
        if (existingUser != null &&
            (existingUser.nickname == null ||
                existingUser.nickname!.isEmpty) &&
            freshNickname != null &&
            freshNickname.isNotEmpty) {
          existingUser = existingUser.copyWith(nickname: freshNickname);
          await _userService.updateUser(existingUser);
          AppLogger.info('[Auth] 기존 구글 유저 닉네임 보정 완료');
        }

        return (user: existingUser, isNewUser: false);
      }
    } on GoogleSignInException catch (e) {
      AppLogger.error(
        '[Auth] Google Sign-In error (code: ${e.code}, message: ${e.description})',
      );
      return (user: null, isNewUser: false);
    } on FirebaseAuthException catch (e) {
      AppLogger.error(
        '[Auth] Firebase auth error (code: ${e.code}, message: ${e.message})',
      );
      return (user: null, isNewUser: false);
    } catch (e) {
      AppLogger.error('[Auth] Unexpected error: $e');
      return (user: null, isNewUser: false);
    }
  }

  // 회원탈퇴
  // 북마크 삭제 → Firestore 유저 문서 삭제 → Firebase 계정 삭제 → 구글 연결 해제
  //
  // user.delete()까지 성공했다면 탈퇴는 이미 끝난 것으로 본다. 그 뒤의
  // GoogleSignIn.disconnect()(구글 쪽 연결 해제)는 부수적인 뒷정리라, 이게
  // 실패해도 전체를 실패로 리턴하면 안 된다 — 계정/데이터는 이미 다
  // 지워졌는데 사용자에게는 "탈퇴 실패"로 잘못 보고되고, 재시도해도 이미
  // 지워진 계정이라 매번 같은 실패가 반복되는 상태에 갇히기 때문이다.
  Future<bool> deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      if (uid != null) {
        // 유저 문서보다 먼저 지워야, 중간에 앱이 죽어 재시도하더라도
        // 이미 지운 문서는 멱등하게 건너뛰고 남은 것만 마저 정리된다.
        await _bookmarkService.deleteAllBookmarks(uid);
        await _userService.deleteUser(uid);
      }

      try {
        await user?.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          await _reauthenticateGoogle(user);
          await user?.delete();
        } else {
          rethrow;
        }
      }

      try {
        await GoogleSignIn.instance.disconnect();
      } catch (e) {
        AppLogger.error('[Auth] 구글 연결 해제 실패 (계정 탈퇴 자체는 완료됨)', error: e);
      }

      AppLogger.info('[Auth] 구글 회원탈퇴 완료');
      return true;
    } catch (e) {
      AppLogger.error('[Auth] 구글 회원탈퇴 실패', error: e);
      return false;
    }
  }

  Future<void> _reauthenticateGoogle(User? user) async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await user?.reauthenticateWithCredential(credential);
  }

  // 구글 로그아웃
  Future<bool> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();

      AppLogger.info('[Auth] 구글 로그아웃 완료');
      return true;
    } catch (e) {
      AppLogger.error('[Auth] 구글 로그아웃 실패', error: e);
      return false;
    }
  }
}
