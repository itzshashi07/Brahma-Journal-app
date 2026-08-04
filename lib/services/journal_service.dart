import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../core/constants/app_constants.dart';

class JournalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save or update a journal entry (mirrors saveEntry() from data.ts)
  Future<String> saveEntry(JournalEntry entry, {String? existingEntryId}) async {
    try {
      if (existingEntryId != null) {
        await _db.collection(AppConstants.entriesCollection).doc(existingEntryId).update({
          ...entry.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return existingEntryId;
      } else {
        final docRef = await _db.collection(AppConstants.entriesCollection).add({
          ...entry.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      }
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
    final entries = await getEntries(uid);
    final today = DateTime.now();
    try {
      return entries.firstWhere((e) {
        return e.createdAt.year == today.year &&
            e.createdAt.month == today.month &&
            e.createdAt.day == today.day;
      });
    } catch (_) {
      return null;
    }
  }

  // Calculate streak (mirrors calculateStreak() from data.ts)
  Future<int> calculateStreak(String uid) async {
    try {
      final entries = await getEntries(uid);
      if (entries.isEmpty) return 0;

      // Get unique dates
      final uniqueDates = <String>{};
      for (final e in entries) {
        final dateStr = '${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}';
        uniqueDates.add(dateStr);
      }

      final sortedDates = uniqueDates.map((s) {
        final parts = s.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }).toList()
        ..sort((a, b) => b.compareTo(a)); // Most recent first

      if (sortedDates.isEmpty) return 0;

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final mostRecent = sortedDates[0];
      final daysSince = today.difference(mostRecent).inDays;

      if (daysSince > 1) return 0;

      int streak = 0;
      DateTime expected = mostRecent;
      for (final date in sortedDates) {
        if (date == expected) {
          streak++;
          expected = expected.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      return streak;
    } catch (e) {
      return 0;
    }
  }

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
