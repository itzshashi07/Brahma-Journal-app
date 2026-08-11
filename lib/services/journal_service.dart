import 'package:flutter/foundation.dart';

import '../models/journal_entry.dart';
import '../core/utils/stats_utils.dart';
import 'api_service.dart';

/// The journal, served by the Node.js API over MongoDB.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What changed, and what did not
///
/// Reads and writes now go through [ApiService] instead of Firestore. The
/// calculations did not move: [streakFromDates] and [isSameDayAsToday] are the
/// same functions as before, so the dashboard and the leaderboard still cannot
/// disagree about what a streak is.
///
/// Two things the API took over that this class used to arrange:
///
///   * **Ownership.** Every query used to carry `where('uid', isEqualTo: uid)`
///     and rely on firestore.rules to enforce it. The server now takes the
///     owner from the verified ID token, so `getEntries` needs no uid at all —
///     it cannot be asked for somebody else's journal.
///   * **Stats.** `saveEntry` used to call `syncProfileStats` afterwards to
///     keep the leaderboard honest. The API does that inside the same request
///     that stores the entry, so there is no window where the entry exists and
///     the count disagrees, and no second round trip on the save path.
class JournalService {
  final ApiService _api = ApiService();

  /// Saves a new entry, or updates one that already exists.
  ///
  /// Returns the entry id. Throws [ApiException] on failure rather than
  /// swallowing it — losing a journal entry silently is the one outcome this
  /// screen must never have, and the caller needs something to show.
  Future<String> saveEntry(JournalEntry entry, {String? existingEntryId}) async {
    if (existingEntryId != null) {
      final body = await _api.patch('/api/entries/$existingEntryId', entry.toJson());
      return body?['entry']?['_id']?.toString() ?? existingEntryId;
    }

    final body = await _api.post('/api/entries', entry.toJson());
    final id = body?['entry']?['_id']?.toString();
    if (id == null) {
      throw ApiException(0, 'The entry was saved but the server returned no id.');
    }
    return id;
  }

  /// This member's entries, newest first.
  ///
  /// The [uid] parameter is kept so existing callers compile unchanged, and is
  /// deliberately unused: the server answers for whoever the ID token belongs
  /// to. Passing somebody else's uid does not and cannot return their journal.
  Future<List<JournalEntry>> getEntries([String? uid]) async {
    try {
      final body = await _api.get('/api/entries', query: {'limit': '500'});
      final list = (body?['entries'] as List? ?? const []);
      return list
          .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // The journal screen renders an empty state rather than an error, which
      // is the existing behaviour and the right one — a member opening their
      // diary to a stack trace is worse than one opening it to "nothing yet".
      debugPrint('❌ getEntries failed: $e');
      return [];
    }
  }

  Future<JournalEntry?> getTodaysEntry([String? uid]) async {
    return todaysEntryFrom(await getEntries());
  }

  /// Today's entry picked out of an already-loaded list.
  JournalEntry? todaysEntryFrom(List<JournalEntry> entries) {
    for (final e in entries) {
      if (isSameDayAsToday(e.createdAt)) return e;
    }
    return null;
  }

  Future<void> deleteEntry(String entryId) async {
    await _api.delete('/api/entries/$entryId');
  }

  /// Consecutive days with a journal entry.
  Future<int> calculateStreak([String? uid]) async {
    try {
      final entries = await getEntries();
      return streakFromDates(entries.map((e) => e.createdAt));
    } catch (e) {
      debugPrint('❌ calculateStreak failed: $e');
      return 0;
    }
  }

  /// Streak computed from already-loaded entries — avoids a second round trip
  /// when the caller has the list in hand.
  ///
  /// [recoveredDays] are days forgiven by a streak recovery. They are passed in
  /// rather than fetched so this stays a pure calculation, and so the dashboard
  /// and the leaderboard cannot disagree about what a streak is.
  int streakForEntries(
    List<JournalEntry> entries, {
    Iterable<DateTime> recoveredDays = const [],
  }) =>
      streakFromDates([...entries.map((e) => e.createdAt), ...recoveredDays]);
}
