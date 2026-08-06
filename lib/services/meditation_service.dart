import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/stats_utils.dart';
import 'profile_service.dart';

class MeditationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();

  /// Records a completed stretch of meditation.
  ///
  /// Returns true when the session was stored, so the UI can tell the user the
  /// truth instead of always claiming "session saved".
  Future<bool> saveSession(String uid, int durationSeconds) async {
    if (durationSeconds <= 0) return false;
    try {
      await _db.collection(AppConstants.meditationSessionsCollection).add({
        'uid': uid,
        'duration': durationSeconds,
        // Client time as well as the server stamp: the server value reads back
        // null until the write is acknowledged, which made "today's minutes"
        // flicker to zero right after a session.
        'clientCreatedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _profileService.syncProfileStats(uid);
      return true;
    } catch (e) {
      print('❌ Failed to save meditation session: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSessions(String uid) async {
    try {
      final q = _db
          .collection(AppConstants.meditationSessionsCollection)
          .where('uid', isEqualTo: uid);
      final snapshot = await q.get();
      final sessions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'duration': parseIntField(data['duration']),
          'createdAt': parseFirestoreDate(data['createdAt']) ??
              parseFirestoreDate(data['clientCreatedAt']) ??
              DateTime.now(),
        };
      }).toList();
      sessions.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
      return sessions;
    } catch (e) {
      print('❌ getSessions failed: $e');
      return [];
    }
  }

  /// Seconds meditated on the current calendar day.
  int todaySeconds(List<Map<String, dynamic>> sessions) {
    return sessions
        .where((s) => isSameDayAsToday(s['createdAt'] as DateTime))
        .fold(0, (acc, s) => acc + (s['duration'] as int));
  }

  int totalSeconds(List<Map<String, dynamic>> sessions) {
    return sessions.fold(0, (acc, s) => acc + (s['duration'] as int));
  }
}
