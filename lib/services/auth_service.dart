import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication.
///
/// Note there is no "admin" path here of any kind. Privilege comes from a
/// custom claim minted server-side; signing in is only ever about proving who
/// you are.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    // Google keeps its own session; without this, "sign out" silently signs the
    // same account straight back in on the next attempt.
    await _googleSignIn.signOut().catchError((_) => null);
    await _auth.signOut();
  }

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ─────────────────────── password reset ───────────────────────

  /// Sends a password reset link.
  ///
  /// Firebase deliberately does not reveal whether an address is registered,
  /// and neither does the UI on top of this — an endpoint that answers "no such
  /// user" is an account enumeration oracle.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─────────────────────── Google sign-in ───────────────────────

  /// Returns null if the user dismissed the account chooser.
  Future<UserCredential?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  // No phone / OTP.
  //
  // `startPhoneVerification` and `confirmSmsCode` lived here and are gone with
  // the screen that called them. Phone was a *second identity* Firebase could
  // not join to an existing one: somebody who signed up with an email and later
  // tapped "Phone" was handed a new account with an empty journal and no route
  // back to what they had written. It also bills per SMS and is the one sign-in
  // a stranger can trigger against a number that is not theirs.
  //
  // Email and Google both resolve to one account per person, which is the
  // property that actually matters here.

  // ─────────────────────── email link ───────────────────────

  /// Sends a passwordless sign-in link.
  ///
  /// Requires an App Links domain: Firebase Dynamic Links was shut down, so the
  /// `url` below must be a domain you control that serves a valid
  /// `/.well-known/assetlinks.json` for this package. Until that is configured
  /// the link will open in a browser rather than the app — see SECURITY.md.
  Future<void> sendSignInLink(String email, {required String continueUrl}) async {
    await _auth.sendSignInLinkToEmail(
      email: email.trim(),
      actionCodeSettings: ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.brahma.brahmaApp',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      ),
    );
  }

  bool isSignInLink(String link) => _auth.isSignInWithEmailLink(link);

  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String link,
  }) async {
    return await _auth.signInWithEmailLink(email: email.trim(), emailLink: link);
  }
}
