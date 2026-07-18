import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wayable/model/user/user.dart';
import 'package:wayable/services/user_service.dart';
import 'package:wayable/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _userService = UserService();
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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
