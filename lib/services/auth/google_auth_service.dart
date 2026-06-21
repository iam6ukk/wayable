import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wayable/model/user.dart';
import 'package:wayable/constants/app_constants.dart';

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

      return AppUser(
        uid: firebaseUser.uid,
        nickname: firebaseUser.displayName,
        email: firebaseUser.email,
      );
    } on GoogleSignInException catch (e) {
      print('Google Sign-In 오류: ${e.code} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase 인증 오류: ${e.message}');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
