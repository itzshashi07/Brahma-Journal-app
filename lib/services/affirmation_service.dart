import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class AffirmationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> getUserAffirmations(String uid) async {
    try {
      final doc = await _db.collection(AppConstants.userAffirmationsCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return List<String>.from(data['affirmations'] ?? AppConstants.defaultAffirmations);
      }
      return AppConstants.defaultAffirmations;
    } catch (e) {
      return AppConstants.defaultAffirmations;
    }
  }

  Future<void> saveUserAffirmations(String uid, List<String> affirmations) async {
    try {
      await _db.collection(AppConstants.userAffirmationsCollection).doc(uid).set({
        'affirmations': affirmations,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
