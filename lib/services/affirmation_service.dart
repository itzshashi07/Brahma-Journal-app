import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import 'api_service.dart';

/// Affirmations: the member's own set, the backgrounds chosen for them, and
/// the record of sitting with each one.
class AffirmationService {
  final ApiService _api = ApiService();

  Future<List<String>> getUserAffirmations([String? uid]) async =>
      (await getUserAffirmationSet()).affirmations;

  /// Affirmations together with the background chosen for each.
  ///
  /// Backgrounds are a list aligned by index rather than a map keyed by the
  /// affirmation text. That shape came from Firestore, whose map keys cannot
  /// contain '.' or '/' while affirmations are sentences — but it is kept
  /// because the alignment is what lets one read serve both, and the list is
  /// always returned at the same length as the affirmations so the caller never
  /// has to bounds-check.
  ///
  /// Falls back to the defaults on any failure, so a member who is offline sees
  /// affirmations rather than an empty screen.
  Future<({List<String> affirmations, List<String?> backgroundIds})>
      getUserAffirmationSet([String? uid]) async {
    try {
      final body = await _api.get('/api/practice/affirmations/mine');

      final affirmations = body?['affirmations'] is List
          ? List<String>.from(body!['affirmations'])
          : AppConstants.defaultAffirmations;

      // A member who has never saved a set gets the defaults, not an empty list
      // — the API answers with [] for "nothing stored", which is a real answer
      // for backgrounds but the wrong one for affirmations themselves.
      final resolved =
          affirmations.isEmpty ? AppConstants.defaultAffirmations : affirmations;

      final stored = body?['backgroundIds'] is List
          ? List<dynamic>.from(body!['backgroundIds'])
          : const <dynamic>[];

      return (
        affirmations: resolved,
        backgroundIds: _alignBackgrounds(stored, resolved.length),
      );
    } catch (e) {
      debugPrint('ℹ️ Affirmations unavailable, using defaults: $e');
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
    String? uid,
    List<String> affirmations, {
    List<String?>? backgroundIds,
  }) async {
    try {
      await _api.put('/api/practice/affirmations/mine', {
        'affirmations': affirmations,
        // Empty string for "no choice yet", preserving the index alignment
        // with `affirmations`. The sentinel is inherited from Firestore, whose
        // arrays cannot hold nulls; changing it now would silently reassign
        // every stored background by one position.
        if (backgroundIds != null)
          'backgroundIds': [for (final id in backgroundIds) id ?? ''],
      });
    } catch (e) {
      // Deliberately swallowed: this saves in the background as the member
      // edits, and an error toast mid-typing helps nobody.
      debugPrint('⚠️ Could not save affirmations: $e');
    }
  }

  Future<void> saveAffirmationSession(
    String? uid,
    String affirmation,
    int duration,
  ) async {
    try {
      await _api.post('/api/practice/affirmations/sessions', {
        'affirmation': affirmation,
        'durationSeconds': duration,
      });
    } catch (e) {
      debugPrint('⚠️ Could not save affirmation session: $e');
    }
  }

  Future<void> saveAffirmationProgress(
    String? uid,
    String affirmationId,
    int progress,
  ) async {
    try {
      await _api.put('/api/practice/affirmations/progress', {
        'affirmationId': affirmationId,
        'progress': progress,
      });
    } catch (e) {
      debugPrint('⚠️ Could not save affirmation progress: $e');
    }
  }
}
