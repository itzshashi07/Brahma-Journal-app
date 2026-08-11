import 'package:flutter/foundation.dart';

import '../core/utils/stats_utils.dart';
import 'api_service.dart';

/// Public scores for the Game Zone.
///
/// Kept out of the practice leaderboard, which ranks journal streaks and
/// meditation minutes. A game score is a different kind of claim, and ranking
/// the two together would put "solved a puzzle fast" beside "sat still for a
/// year". One row per member per game, holding a display name and a number —
/// no email, phone, age or gender, because every signed-in member can read it.
///
/// The personal-best comparison moved to the server, and had to. It used to be
/// read-then-write on the device: two devices finishing a game at the same
/// moment would race, and the better score could be overwritten by the worse
/// one. It is now a single conditional update whose filter carries the
/// comparison, so a losing write matches nothing.
///
/// The display name is no longer sent either. The server reads it from the
/// caller's own profile, which means a member cannot put an arbitrary name on
/// a public board.
class GameStatsService {
  /// The synthetic row that ranks total time trained rather than any one game.
  static const String overallId = '_total';

  final ApiService _api = ApiService();

  /// Publishes a score. Only a personal best moves the board; a weaker run
  /// still counts as a play.
  Future<void> publishScore({
    String? uid,
    required String gameId,
    required int score,
    required bool lowerIsBetter,
    String displayName = 'Friend',
    String? avatarId,
  }) async {
    if (score < 0) return;
    try {
      await _api.post('/api/practice/games/scores', {
        'gameId': gameId,
        'score': score,
        'lowerIsBetter': lowerIsBetter,
      });
    } catch (e) {
      // A leaderboard write must never take a game down with it.
      debugPrint('⚠️ Could not publish score: $e');
    }
  }

  /// Adds banked training seconds to the member's overall row.
  Future<void> addTrainingTime({
    String? uid,
    required int seconds,
    String displayName = 'Friend',
    String? avatarId,
  }) async {
    if (seconds <= 0) return;
    try {
      await _api.post('/api/practice/games/training', {'seconds': seconds});
    } catch (e) {
      debugPrint('⚠️ Could not bank training time: $e');
    }
  }

  /// The top rows for one game.
  Future<List<GameScoreRow>> top(
    String gameId, {
    required bool lowerIsBetter,
    int limit = 50,
  }) async {
    try {
      final body = await _api.get('/api/practice/games/$gameId/board', query: {
        'lowerIsBetter': lowerIsBetter.toString(),
        'limit': limit.toString(),
      });
      final list = (body?['top'] as List? ?? const []);
      return list
          .map((r) => GameScoreRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Game board unavailable: $e');
      return [];
    }
  }

  /// Every row belonging to the caller, keyed by game id.
  Future<Map<String, GameScoreRow>> myRows([String? uid]) async {
    try {
      final body = await _api.get('/api/practice/games/mine');
      final rows = (body?['rows'] as Map? ?? const {});
      return {
        for (final e in rows.entries)
          e.key.toString():
              GameScoreRow.fromJson(Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (e) {
      debugPrint('⚠️ Game rows unavailable: $e');
      return {};
    }
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

  factory GameScoreRow.fromJson(Map<String, dynamic> data) {
    return GameScoreRow(
      uid: (data['firebaseUid'] ?? '').toString(),
      gameId: (data['gameId'] ?? '').toString(),
      displayName: (data['displayName'] ?? 'Friend').toString(),
      avatarId: data['avatarId']?.toString(),
      score: parseIntField(data['score']),
      plays: parseIntField(data['plays']),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}
