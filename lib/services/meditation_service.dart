import 'package:flutter/foundation.dart';

import '../core/utils/stats_utils.dart';
import 'api_service.dart';

/// Meditation sessions, served by the Node.js API.
///
/// The `clientCreatedAt` companion field is gone and unmissed. It existed
/// because a Firestore `serverTimestamp()` reads back as null until the write
/// is acknowledged, which made "today's minutes" flicker to zero right after a
/// session. The API stamps `createdAt` before it answers, so every session this
/// reads already has a real date.
///
/// The stats sync also stopped being a second round trip: the API recomputes
/// the member's totals inside the same request that stores the session, so
/// there is no window where the session exists and the dashboard disagrees.
class MeditationService {
  final ApiService _api = ApiService();

  /// Records a completed stretch of meditation.
  ///
  /// Returns true when the session was stored, so the UI can tell the user the
  /// truth instead of always claiming "session saved".
  ///
  /// [uid] is kept for call-site compatibility and deliberately unused — the
  /// server attributes the session to the ID token's owner.
  Future<bool> saveSession(String? uid, int durationSeconds) async {
    if (durationSeconds <= 0) return false;
    try {
      await _api.post('/api/practice/meditation', {
        'durationSeconds': durationSeconds,
        'completed': true,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Failed to save meditation session: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSessions([String? uid]) async {
    try {
      final body = await _api.get('/api/practice/meditation', query: {'limit': '500'});
      final list = (body?['sessions'] as List? ?? const []);
      return list.map((raw) {
        final s = Map<String, dynamic>.from(raw as Map);
        return {
          'id': s['_id']?.toString() ?? '',
          'duration': parseIntField(s['durationSeconds']),
          'createdAt':
              DateTime.tryParse(s['createdAt']?.toString() ?? '') ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getSessions failed: $e');
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

/// Attention-game sessions.
///
/// Deliberately a separate service and collection from meditation. A Schulte
/// grid is training, not practice, and folding it into meditation minutes would
/// make the one honest number in the app dishonest.
class FocusService {
  final ApiService _api = ApiService();

  Future<bool> saveSession(String? uid, int durationSeconds, String game) async {
    if (durationSeconds <= 0) return false;
    try {
      await _api.post('/api/practice/focus', {
        'durationSeconds': durationSeconds,
        'game': game,
        'completed': true,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Failed to save focus session: $e');
      return false;
    }
  }

  /// Total focus-training seconds, all time.
  Future<int> totalSeconds([String? uid]) async {
    final list = await sessions();
    return list.fold<int>(0, (acc, s) => acc + s.seconds);
  }

  /// Every banked session, so Analytics can break the time down per game.
  Future<List<FocusSession>> sessions([String? uid]) async {
    try {
      final body = await _api.get('/api/practice/focus', query: {'limit': '500'});
      final list = (body?['sessions'] as List? ?? const []);
      return list.map((raw) {
        final s = Map<String, dynamic>.from(raw as Map);
        return FocusSession(
          game: (s['game'] ?? 'unknown').toString(),
          seconds: parseIntField(s['durationSeconds']),
          at: DateTime.tryParse(s['createdAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ focus sessions failed: $e');
      return [];
    }
  }
}

class FocusSession {
  final String game;
  final int seconds;
  final DateTime at;

  const FocusSession({
    required this.game,
    required this.seconds,
    required this.at,
  });
}
