import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class MeditationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveSession(String uid, int durationMinutes) async {
    try {
      await _db.collection(AppConstants.meditationSessionsCollection).add({
        'uid': uid,
        'duration': durationMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw to prevent blocking UI
    }
  }

  Future<List<Map<String, dynamic>>> getSessions(String uid) async {
    try {
      final q = _db
          .collection(AppConstants.meditationSessionsCollection)
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true);
      final snapshot = await q.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'duration': data['duration'] ?? 0,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
