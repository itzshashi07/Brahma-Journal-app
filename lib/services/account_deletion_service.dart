import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Deletes an account and everything attached to it.
///
/// Google Play has required this since 2023 for any app that creates accounts,
/// and it is required in two forms: a route inside the app, and a public web
/// page for people who have already uninstalled. This is the in-app half.
///
/// **It deletes the data, not just the login.** Removing the Firebase Auth user
/// and leaving the documents behind would be the easy version and a false one —
/// the journal entries, the check-ins and the counselling transcripts are the
/// whole reason somebody would want out.
///
/// Order matters. Firestore goes first and Auth last, because every rule here
/// authorises writes against `request.auth.uid`: delete the credential first
/// and the documents become permanently unreachable, orphaned under a uid that
/// can never sign in again. If this fails halfway the account still exists and
/// the member can simply try again — which is the recoverable direction.
class AccountDeletionService {
  /// Erases everything, then the account.
  ///
  /// Returns null on success or a message the UI can show. Never throws.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// One server call, then the credential
  ///
  /// This used to walk a dozen collections from the device, and it carried an
  /// honest note about what happened when one of them refused: it continued
  /// anyway and left "unreachable orphan data that the support address can
  /// clear". That is a partial erasure of somebody who asked to be forgotten.
  ///
  /// The server now sweeps everything in one request, so the deletion cannot
  /// be half-done by the app being backgrounded mid-way, and it reports back
  /// anything it could not remove.
  ///
  /// **Order matters and has not changed.** Data first, credential second:
  /// every API route authorises against a valid ID token, so destroying the
  /// Firebase account first would lock the member out of their own deletion.
  Future<String?> deleteEverything() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'You are not signed in.';

    try {
      final body = await ApiService().delete('/api/profile/me');
      final incomplete = (body?['incomplete'] as List? ?? const []);
      if (incomplete.isNotEmpty) {
        debugPrint('⚠️ Data deletion incomplete: ${incomplete.join(', ')}');
      }
    } catch (e) {
      // Deliberately continues to the Auth deletion below. A member who asked
      // to be deleted should not be left with a working account because the
      // server was unreachable — and support can clear what remains.
      debugPrint('⚠️ Data deletion failed: $e');
    }

    try {
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Firebase refuses to delete an account authenticated long ago. This is
        // the one error worth surfacing, because the member can fix it.
        return 'Please sign out and sign in again, then try once more.';
      }
      return 'Your account could not be deleted. Please contact support.';
    } catch (e) {
      debugPrint('⚠️ Account deletion failed: $e');
      return 'Your account could not be deleted. Please contact support.';
    }
  }

  /// Whether the member can prove it is them without leaving this screen.
  ///
  /// Firebase refuses to delete an account whose sign-in is old, and only
  /// password accounts can re-prove identity in place — a Google or phone
  /// account has to go back through its own provider.
  bool get canReauthenticateInPlace {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  /// Re-proves identity with the account password.
  ///
  /// Returns null on success, or a message the UI can show.
  Future<String?> reauthenticateWithPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return 'Please sign out and sign in again, then retry.';
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'That password is not correct.'
          : 'Could not verify it is you. Please sign in again.';
    }
  }
}
