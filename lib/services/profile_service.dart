import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'api_service.dart';

/// The stats that back the dashboard cards and the community leaderboard.
class UserStats {
  final int streak;
  final int longestStreak;
  final int totalJournalEntries;
  final int totalMeditationSeconds;
  final DateTime? lastActiveAt;

  const UserStats({
    this.streak = 0,
    this.longestStreak = 0,
    this.totalJournalEntries = 0,
    this.totalMeditationSeconds = 0,
    this.lastActiveAt,
  });

  factory UserStats.fromJson(Map<String, dynamic> data) => UserStats(
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
        totalJournalEntries: (data['totalJournalEntries'] as num?)?.toInt() ?? 0,
        totalMeditationSeconds:
            (data['totalMeditationSeconds'] as num?)?.toInt() ?? 0,
        lastActiveAt: data['lastActiveAt'] == null
            ? null
            : DateTime.tryParse(data['lastActiveAt'].toString()),
      );
}

/// Profiles and the public leaderboard, served by the Node.js API.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What the server took over
///
/// `syncProfileStats` used to run here: it read every entry and every
/// meditation session, computed the streak, and wrote both the profile and the
/// member's leaderboard row from the device. That is now one request. The
/// numbers on the public board are derived from the records the member
/// actually has, in the process that stores them, so a self-reported score is
/// no longer possible.
///
/// `rebuildLeaderboard` is gone entirely and needs no replacement. It existed
/// because leaderboard rows were written by their owner's device, so a member
/// who had not opened the app since the board was introduced simply was not on
/// it — and a Cloud Function that would have fixed that needs the Blaze plan.
/// Rows are now written server-side on every sync, so the board cannot fall
/// behind in that way.
///
/// The PII split survives the move and is worth restating: /leaderboard was a
/// deliberately PII-free projection because reading /profiles wholesale would
/// have exposed the name, email, phone and age of the entire user base. The API
/// keeps that separation — the leaderboard endpoint returns display names and
/// counters, and a profile fetched for anyone but the caller is an allowlist of
/// the same handful of fields.
class ProfileService {
  final ApiService _api = ApiService();

  /// Minutes east of UTC. A streak is a fact about the member's calendar, and
  /// the server runs in UTC — without this, someone in IST journalling after
  /// midnight has it filed as yesterday.
  int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  Future<void> saveProfile(UserProfile profile) async {
    await _api.patch('/api/profile/me', profile.toJson());
  }

  /// A profile by uid. Omit [uid] — or pass the caller's own — for the full
  /// record; anyone else's returns the public card.
  Future<UserProfile?> getProfile([String? uid]) async {
    try {
      final body = await _api.get(uid == null ? '/api/profile/me' : '/api/profile/$uid');
      final data = body?['profile'];
      if (data == null) return null;
      return UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('❌ getProfile failed: $e');
      return null;
    }
  }

  /// Public ranking rows for the Community screen.
  Future<List<UserProfile>> getLeaderboard({String sortBy = 'meditation'}) async {
    final body = await _api.get('/api/practice/leaderboard', query: {
      'sortBy': sortBy == 'streak' ? 'streak' : 'totalMeditationSeconds',
      'limit': '100',
    });
    final rows = (body?['leaderboard'] as List? ?? const []);
    return rows
        .map((r) => UserProfile.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Admin only: rebuild every member's public row from their own records.
  ///
  /// Rows are written on each member's own sync, so the board keeps itself
  /// current and this is not part of the routine — it earns its place right
  /// after the Firestore migration, and any time the totals should be
  /// re-derived from source rather than trusted.
  ///
  /// Returns how many rows were written.
  Future<int> rebuildLeaderboard() async {
    final body = await _api.post('/api/practice/leaderboard/rebuild');
    return (body?['written'] as num?)?.toInt() ?? 0;
  }

  /// Recomputes this member's stats server-side and returns them.
  ///
  /// The [uid] parameter is kept so existing call sites compile unchanged and
  /// is deliberately unused — the server syncs whoever the ID token belongs to.
  /// Nobody can trigger a recompute of somebody else's numbers.
  ///
  /// Returns null when the server had nothing to compute. Never throws: a
  /// failed sync leaves the stored numbers as they were, which is the same
  /// tolerance the Firestore version had.
  Future<UserStats?> syncProfileStats([String? uid]) async {
    try {
      final body = await _api.post('/api/profile/me/sync-stats', {
        'tzOffsetMinutes': _tzOffsetMinutes,
      });
      final stats = body?['stats'];
      if (stats == null) return null;
      return UserStats.fromJson(Map<String, dynamic>.from(stats as Map));
    } catch (e) {
      debugPrint('❌ syncProfileStats failed: $e');
      return null;
    }
  }
}
