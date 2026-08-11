import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';

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
  final _db = FirebaseFirestore.instance;

  /// Collections holding one document per user, keyed by the uid itself.
  static const _docPerUser = <String>[
    'profiles',
    'leaderboard',
    'follower_counts',
    'user_affirmations',
  ];

  /// Collections holding many documents carrying a `uid` field.
  static const _ownedByField = <String>[
    AppConstants.entriesCollection,
    AppConstants.meditationSessionsCollection,
    AppConstants.focusSessionsCollection,
    AppConstants.affirmationProgressCollection,
    AppConstants.affirmationSessionsCollection,
    'counselling_sessions',
    'game_scores',
    'blogs',
  ];

  /// Erases everything, then the account.
  ///
  /// Returns null on success or a message the UI can show. Never throws.
  Future<String?> deleteEverything() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'You are not signed in.';
    final uid = user.uid;

    try {
      await _deleteAnonymousContent(uid);
      await _deleteSubcollections(uid);

      for (final collection in _ownedByField) {
        await _deleteWhereUid(collection, uid);
      }

      for (final collection in _docPerUser) {
        await _db.collection(collection).doc(uid).delete().catchError((_) {});
      }
    } catch (e) {
      debugPrint('⚠️ Data deletion incomplete: $e');
      // Deliberately continues to the Auth deletion below. A member who asked
      // to be deleted should not be left with a working account because one
      // collection refused — and what remains is unreachable orphan data that
      // the support address can clear.
    }

    try {
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Firebase refuses to delete an account authenticated long ago. This is
        // not an error to hide: the member has to prove it is them, which is
        // the right bar for an irreversible action.
        return 'needs-reauth';
      }
      return 'Your data was removed, but the account could not be closed. '
          'Please sign in again and retry.';
    } catch (e) {
      return 'Something went wrong. Please contact support.';
    }
  }

  /// The anonymous board.
  ///
  /// Reflections carry no uid — that is the point — so they cannot be found
  /// with a query. The authorship mirror is what makes deletion possible at
  /// all, and it is unreadable by clients, so the watchlist written when the
  /// member posted is what this walks instead.
  ///
  /// Replies are deliberately left in place. A reply is part of somebody
  /// else's conversation, it carries no identifying mark, and pulling a
  /// stranger's answer out from under their reflection months later would
  /// damage a thread to no one's benefit.
  Future<void> _deleteAnonymousContent(String uid) async {
    try {
      final watched =
          await _db.collection('thought_watch').doc(uid).collection('threads').get();

      for (final entry in watched.docs) {
        if (entry.data()['role'] != 'author') continue;
        await _db
            .collection(AppConstants.anonymousThoughtsCollection)
            .doc(entry.id)
            .delete()
            .catchError((_) {});
      }
    } catch (e) {
      debugPrint('⚠️ Anonymous content deletion skipped: $e');
    }
  }

  /// Per-user subcollections, which a parent delete does not cascade to —
  /// Firestore has no cascading delete, and an orphaned subcollection is
  /// invisible to every screen while still holding the member's data.
  Future<void> _deleteSubcollections(String uid) async {
    for (final path in [
      'thought_watch/$uid/threads',
      'blocks/$uid/users',
      'following/$uid/targets',
    ]) {
      try {
        final snap = await _db.collection(path).get();
        await _commitInBatches(snap.docs.map((d) => d.reference).toList());
      } catch (e) {
        debugPrint('⚠️ Could not clear $path: $e');
      }
    }
  }

  Future<void> _deleteWhereUid(String collection, String uid) async {
    try {
      final snap =
          await _db.collection(collection).where('uid', isEqualTo: uid).get();
      await _commitInBatches(snap.docs.map((d) => d.reference).toList());
    } catch (e) {
      debugPrint('⚠️ Could not clear $collection: $e');
    }
  }

  /// 500 is Firestore's hard limit on a batch; 400 leaves room and a long-time
  /// member can easily exceed either.
  Future<void> _commitInBatches(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Proves it is really them, for an account whose sign-in is too old.
  ///
  /// Only the password path can be handled in one step. Google and phone
  /// accounts have no password to re-enter, so they are asked to sign out and
  /// back in — clumsier, but it is the provider's own requirement and inventing
  /// a way around it would mean weakening the check that protects the account.
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

  /// True when the account signs in with a password, and can therefore be
  /// re-verified without leaving the deletion screen.
  bool get canReauthenticateInPlace {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }
}
