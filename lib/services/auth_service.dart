import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn =
      GoogleSignIn();

  // =========================================
  // EMAIL LOGIN
  // =========================================

  Future<UserCredential> login({

    required String email,
    required String password,

  }) async {

    return await _auth
        .signInWithEmailAndPassword(

      email: email,
      password: password,
    );
  }

  // =========================================
  // EMAIL SIGNUP
  // =========================================

  Future<UserCredential> signup({

    required String email,
    required String password,

  }) async {

    return await _auth
        .createUserWithEmailAndPassword(

      email: email,
      password: password,
    );
  }

  // =========================================
  // GOOGLE LOGIN
  // =========================================

  Future<UserCredential?>
      signInWithGoogle() async {

    final GoogleSignInAccount?
        googleUser =
            await _googleSignIn.signIn();

    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication
        googleAuth =
            await googleUser.authentication;

    final credential =
        GoogleAuthProvider.credential(

      accessToken:
          googleAuth.accessToken,

      idToken:
          googleAuth.idToken,
    );

    return await _auth
        .signInWithCredential(
            credential);
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
    }
  }

  // =========================================
  // LOGOUT
  // =========================================

  Future<void> logout() async {

    await _googleSignIn.signOut();

    await _auth.signOut();
  }
}