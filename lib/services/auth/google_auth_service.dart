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
        final existingUser = await _userService.getUser(uid);
        AppLogger.info('[Auth] 기존 구글 유저 로그인');
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

      await GoogleSignIn.instance.disconnect();

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
