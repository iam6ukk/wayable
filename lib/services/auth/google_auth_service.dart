import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wayable/model/user.dart';
import 'package:wayable/constants/app_constants.dart';
import 'package:wayable/utils/app_logger.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> initGoogleSignIn() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId: AppConstants.googleServiceClientId,
    );
    _initialized = true;
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      await initGoogleSignIn();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) return null;

      AppLogger.debug('[Auth] Google login success');
      AppLogger.debug('[Auth] uid: ${firebaseUser.uid}');

      return AppUser(
        uid: firebaseUser.uid,
        nickname: firebaseUser.displayName,
        email: firebaseUser.email,
      );
    } on GoogleSignInException catch (e) {
      AppLogger.error(
        '[Auth] Google Sign-In error (code: ${e.code}, message: ${e.description})',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      AppLogger.error(
        '[Auth] Firebase auth error (code: ${e.code}, message: ${e.message})',
      );
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
