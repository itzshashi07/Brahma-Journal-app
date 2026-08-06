import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/stats_utils.dart';
import 'profile_service.dart';

class JournalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();

  // Save or update a journal entry (mirrors saveEntry() from data.ts)
  Future<String> saveEntry(JournalEntry entry, {String? existingEntryId}) async {
    try {
      String entryId;
      if (existingEntryId != null) {
        await _db.collection(AppConstants.entriesCollection).doc(existingEntryId).update({
          ...entry.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        entryId = existingEntryId;
      } else {
        final docRef = await _db.collection(AppConstants.entriesCollection).add({
          ...entry.toMap(),
          // A serverTimestamp reads back as null until the write is
          // acknowledged, so an entry written offline had no date at all and
          // silently dropped out of the streak. The client stamp is the
          // fallback for exactly that window.
          'clientCreatedAt': Timestamp.fromDate(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
        });
        entryId = docRef.id;
      }

      // Recalculate the profile stats that back the community leaderboard.
      // Awaited (not fire-and-forget) so the streak the leaderboard reads is
      // already correct by the time the user leaves the journal screen.
      await _profileService.syncProfileStats(entry.uid);

      return entryId;
    } catch (e) {
      rethrow;
    }
  }

  // Get all entries for a user (mirrors getEntries() from data.ts)
  Future<List<JournalEntry>> getEntries(String uid) async {
    try {
      final q = _db.collection(AppConstants.entriesCollection).where('uid', isEqualTo: uid);
      final snapshot = await q.get();
      final entries = snapshot.docs.map((doc) => JournalEntry.fromFirestore(doc)).toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (e) {
      print('❌ getEntries query failed: $e');
      return [];
    }
  }

  // Get today's entry (mirrors getTodaysEntry() from data.ts)
  Future<JournalEntry?> getTodaysEntry(String uid) async {
    return todaysEntryFrom(await getEntries(uid));
  }

  /// Today's entry picked out of an already-loaded list.
  JournalEntry? todaysEntryFrom(List<JournalEntry> entries) {
    for (final e in entries) {
      if (isSameDayAsToday(e.createdAt)) return e;
    }
    return null;
  }

  /// Consecutive days with a journal entry.
  ///
  /// Delegates to [streakFromDates] — the same function ProfileService uses to
  /// write the leaderboard value, so the dashboard and the community screen can
  /// never disagree.
  Future<int> calculateStreak(String uid) async {
    try {
      final entries = await getEntries(uid);
      return streakFromDates(entries.map((e) => e.createdAt));
    } catch (e) {
      print('❌ calculateStreak failed: $e');
      return 0;
    }
  }

  /// Streak computed from already-loaded entries — avoids a second round trip
  /// when the caller has the list in hand.
  int streakForEntries(List<JournalEntry> entries) =>
      streakFromDates(entries.map((e) => e.createdAt));

  // Get all entries (admin use)
  Future<List<JournalEntry>> getAllEntries() async {
    try {
      final q = _db
          .collection(AppConstants.entriesCollection)
          .orderBy('createdAt', descending: true);
      final snapshot = await q.get();
      return snapshot.docs.map((doc) => JournalEntry.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }
}
