import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Following, on the Community screen and nowhere else.
///
/// The shape of this is driven entirely by one requirement: **how many
/// followers somebody has is public, and who follows whom is nobody's
/// business.** A follower list is a social graph, and a social graph on a
/// mental-health app tells you who someone is drawn to at the moment they are
/// struggling — which is not a thing to publish next to a leaderboard.
///
/// Firestore enforced that structurally: `/following/{me}/targets/{them}` was
/// keyed off the follower's uid, so there was no query another client could
/// run that returned it, and `/follower_counts/{them}` held only an integer.
///
/// MongoDB has no such structure — the edges are one collection — so the
/// guarantee now lives in the API, which will answer "who do I follow" and
/// "how many followers does X have" and deliberately offers no endpoint for
/// "who follows me". Not even to the person being followed.
///
/// The two-write batch is gone with it. Firestore needed a [WriteBatch] so its
/// rules could see the edge and the counter in one commit; the server owns
/// both and adjusts the counter only when the edge actually changed, so a
/// double-tap cannot inflate a number by two.
class FollowService {
  final ApiService _api = ApiService();

  // ─────────────────────────── reading ───────────────────────────

  /// Everyone the signed-in member follows.
  ///
  /// One read for the whole set, so the Community screen can render every
  /// row's button state without a lookup per member.
  Future<Set<String>> myFollowing() async {
    try {
      final body = await _api.get('/api/social/following');
      final list = (body?['following'] as List? ?? const []);
      return list.map((e) => e.toString()).toSet();
    } catch (e) {
      debugPrint('⚠️ Following list unavailable: $e');
      return <String>{};
    }
  }

  /// Public follower counts, keyed by uid.
  Future<Map<String, int>> followerCounts() async {
    try {
      final body = await _api.get('/api/social/follower-counts');
      final counts = (body?['counts'] as Map? ?? const {});
      return {
        for (final e in counts.entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('⚠️ Follower counts unavailable: $e');
      return <String, int>{};
    }
  }

  // ─────────────────────────── writing ───────────────────────────

  Future<void> follow(String targetUid) async {
    await _api.post('/api/social/follow/$targetUid');
  }

  Future<void> unfollow(String targetUid) async {
    await _api.delete('/api/social/follow/$targetUid');
  }

  /// Flips the relationship and reports the new state, so the caller can update
  /// a button without re-reading anything.
  Future<bool> toggle(String targetUid, {required bool currentlyFollowing}) async {
    if (currentlyFollowing) {
      await unfollow(targetUid);
      return false;
    }
    await follow(targetUid);
    return true;
  }
}
