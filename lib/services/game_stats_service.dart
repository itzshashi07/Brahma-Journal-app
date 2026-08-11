import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/stats_utils.dart';

/// Public scores for the Game Zone.
///
/// Kept out of /leaderboard, which is the practice board — journal streaks and
/// meditation minutes. A game score is a different kind of claim and ranking
/// the two together would put "solved a puzzle fast" beside "sat still for a
/// year". One row per member per game, holding a display name and a number:
/// no email, phone, age or gender, because this collection is readable by
/// every signed-in member.
class GameStatsService {
  static const String collection = 'game_scores';

  /// The synthetic row that ranks total time trained rather than any one game.
  static const String overallId = '_total';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The document id binds the row to its owner, which is what stops one member
  /// writing a score into another member's row — the rules check that the id is
  /// exactly `<uid>__<gameId>`.
  static String rowId(String uid, String gameId) => '${uid}__$gameId';

  /// Publishes a score if it beats what is already stored.
  ///
  /// Only the personal best is kept. Storing every attempt would make the board
  /// a measure of how many times someone played, which is not the thing being
  /// ranked, and would grow without bound.
  Future<void> publishScore({
    required String uid,
    required String gameId,
    required int score,
    required bool lowerIsBetter,
    String displayName = 'Friend',
    String? avatarId,
  }) async {
    if (score < 0) return;
    try {
      final ref = _db.collection(collection).doc(rowId(uid, gameId));
      final existing = await ref.get();
      final previous =
          existing.exists ? parseIntField(existing.data()?['score']) : null;
      final improved = !existing.exists ||
          previous == null ||
          (lowerIsBetter ? score < previous : score > previous);

      // A weaker run still counts as a play — only the number on the board is
      // held back, so the board shows a best without pretending it was the only
      // attempt. The merge leaves the stored score untouched, and the rules see
      // the merged document, so the omitted fields are still validated.
      if (!improved) {
        await ref.set({
          'plays': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      await ref.set({
        'uid': uid,
        'gameId': gameId,
        'displayName': _boundedName(displayName),
        if (avatarId != null) 'avatarId': avatarId,
        'score': score,
        'plays': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // A leaderboard write must never take a game down with it.
    }
  }

  /// Adds banked training seconds to the member's overall row.
  Future<void> addTrainingTime({
    required String uid,
    required int seconds,
    String displayName = 'Friend',
    String? avatarId,
  }) async {
    if (seconds <= 0) return;
    try {
      await _db.collection(collection).doc(rowId(uid, overallId)).set({
        'uid': uid,
        'gameId': overallId,
        'displayName': _boundedName(displayName),
        if (avatarId != null) 'avatarId': avatarId,
        'score': FieldValue.increment(seconds),
        'plays': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// The top rows for one game.
  Future<List<GameScoreRow>> top(
    String gameId, {
    required bool lowerIsBetter,
    int limit = 50,
  }) async {
    try {
      final snap = await _db
          .collection(collection)
          .where('gameId', isEqualTo: gameId)
          .orderBy('score', descending: !lowerIsBetter)
          .limit(limit)
          .get();
      return snap.docs.map((d) => GameScoreRow.fromDoc(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Every row belonging to one member, keyed by game id.
  Future<Map<String, GameScoreRow>> myRows(String uid) async {
    try {
      final snap =
          await _db.collection(collection).where('uid', isEqualTo: uid).get();
      return {
        for (final d in snap.docs)
          GameScoreRow.fromDoc(d.id, d.data()).gameId:
              GameScoreRow.fromDoc(d.id, d.data())
      };
    } catch (_) {
      return {};
    }
  }

  /// Names are shown to other members, so they are length-bounded here as well
  /// as in the rules — the rules reject a long one, and being rejected would
  /// silently cost the member their score.
  static String _boundedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Friend';
    return trimmed.length <= 80 ? trimmed : trimmed.substring(0, 80);
  }
}

class GameScoreRow {
  final String uid;
  final String gameId;
  final String displayName;
  final String? avatarId;
  final int score;
  final int plays;
  final DateTime? updatedAt;

  const GameScoreRow({
    required this.uid,
    required this.gameId,
    required this.displayName,
    required this.score,
    required this.plays,
    this.avatarId,
    this.updatedAt,
  });

  factory GameScoreRow.fromDoc(String id, Map<String, dynamic> data) {
    return GameScoreRow(
      uid: (data['uid'] ?? '').toString(),
      gameId: (data['gameId'] ?? '').toString(),
      displayName: (data['displayName'] ?? 'Friend').toString(),
      avatarId: data['avatarId']?.toString(),
      score: parseIntField(data['score']),
      plays: parseIntField(data['plays']),
      updatedAt: parseFirestoreDate(data['updatedAt']),
    );
  }
}
