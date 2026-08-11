import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class AffirmationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> getUserAffirmations(String uid) async =>
      (await getUserAffirmationSet(uid)).affirmations;

  /// Affirmations together with the background chosen for each.
  ///
  /// Backgrounds are a list aligned by index rather than a map keyed by the
  /// affirmation text: Firestore map keys cannot contain '.' or '/', and
  /// affirmations are sentences. One read serves both, and the list is always
  /// returned at the same length as the affirmations so the caller never has to
  /// bounds-check.
  Future<({List<String> affirmations, List<String?> backgroundIds})>
      getUserAffirmationSet(String uid) async {
    try {
      final doc = await _db
          .collection(AppConstants.userAffirmationsCollection)
          .doc(uid)
          .get();
      final data = doc.exists ? doc.data() : null;
      final affirmations = data?['affirmations'] is List
          ? List<String>.from(data!['affirmations'])
          : AppConstants.defaultAffirmations;
      final stored = data?['backgroundIds'] is List
          ? List<dynamic>.from(data!['backgroundIds'])
          : const <dynamic>[];
      return (
        affirmations: affirmations,
        backgroundIds: _alignBackgrounds(stored, affirmations.length),
      );
    } catch (e) {
      return (
        affirmations: AppConstants.defaultAffirmations,
        backgroundIds: _alignBackgrounds(
            const <dynamic>[], AppConstants.defaultAffirmations.length),
      );
    }
  }

  static List<String?> _alignBackgrounds(List<dynamic> stored, int length) {
    return List<String?>.generate(length, (i) {
      if (i >= stored.length) return null;
      final v = stored[i];
      return v is String && v.isNotEmpty ? v : null;
    });
  }

  Future<void> saveUserAffirmations(
    String uid,
    List<String> affirmations, {
    List<String?>? backgroundIds,
  }) async {
    try {
      await _db.collection(AppConstants.userAffirmationsCollection).doc(uid).set({
        'affirmations': affirmations,
        // Empty string for "no choice yet" — Firestore arrays cannot hold
        // nulls, and the alignment with `affirmations` has to be preserved.
        if (backgroundIds != null)
          'backgroundIds': [for (final id in backgroundIds) id ?? ''],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Don't throw to prevent blocking UI
    }
  }

  Future<void> saveAffirmationSession(String uid, String affirmation, int duration) async {
    try {
      await _db.collection(AppConstants.affirmationSessionsCollection).add({
        'uid': uid,
        'affirmation': affirmation,
        'duration': duration,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw to prevent blocking UI
    }
  }

  Future<void> saveAffirmationProgress(String uid, String affirmationId, int progress) async {
    try {
      await _db
          .collection(AppConstants.affirmationProgressCollection)
          .doc('${uid}_$affirmationId')
          .set({
        'uid': uid,
        'affirmationId': affirmationId,
        'progress': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw
    }
  }
}
