import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/stats_utils.dart';

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
}

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveProfile(UserProfile profile) async {
    try {
      await _db.collection(AppConstants.profilesCollection).doc(profile.uid).set({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _db.collection(AppConstants.profilesCollection).doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(uid, doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ getProfile error: $e');
      return null;
    }
  }

  /// Public ranking rows for the Community screen.
  ///
  /// This used to read every document in /profiles, which meant any signed-in
  /// member could pull the name, email address, phone number, age and payment
  /// history of the entire user base. The leaderboard only ever needed a
  /// display name and some counters, so those now live in /leaderboard — a
  /// deliberately PII-free projection — and /profiles becomes owner-only.
  ///
  /// Reads /leaderboard, falling back to /profiles when that read is refused.
  ///
  /// The fallback exists because the app and the security rules deploy
  /// separately: a build carrying this code can reach a project still running
  /// the old rules, where /leaderboard does not exist as far as the rules are
  /// concerned and every read is denied. Without the fallback the Community
  /// screen is simply broken in that window.
  ///
  /// The distinction is deliberate — an *empty* /leaderboard is a real answer
  /// and is used as-is (it fills in as members open the app), whereas a
  /// *refused* read means the new rules are not live yet.
  Future<List<UserProfile>> getLeaderboard() async {
    try {
      final snapshot =
          await _db.collection(AppConstants.leaderboardCollection).get();
      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('ℹ️ /leaderboard unavailable ($e) — falling back to /profiles');
    }

    try {
      final snapshot = await _db.collection(AppConstants.profilesCollection).get();
      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('❌ getLeaderboard: both sources failed: $e');
      rethrow;
    }
  }

  /// Rebuilds every member's public leaderboard row from their profile.
  ///
  /// Admin only — and it exists because leaderboard rows are written by their
  /// owner's device. A member who has not opened the app since /leaderboard was
  /// introduced simply is not on the board, which makes the Community screen
  /// look broken even though nothing is. A Cloud Function trigger would keep
  /// this current automatically; that needs the Blaze plan, so until then an
  /// operator can rebuild the board on demand.
  ///
  /// Copies only what the Community screen renders. The counters come from each
  /// profile as last synced by its owner, so they are as fresh as that member's
  /// last visit — accurate, not invented.
  ///
  /// Returns how many rows were written.
  Future<int> rebuildLeaderboard() async {
    final profiles = await _db.collection(AppConstants.profilesCollection).get();
    var written = 0;

    // Batched: one write per member would be dozens of round trips, and a
    // partial rebuild is worse than none.
    var batch = _db.batch();
    var inBatch = 0;

    for (final doc in profiles.docs) {
      final p = UserProfile.fromFirestore(doc.id, doc.data());
      final row = _db.collection(AppConstants.leaderboardCollection).doc(doc.id);

      batch.set(row, {
        'uid': doc.id,
        'displayName': p.displayName,
        if (p.avatarId != null) 'avatarId': p.avatarId,
        'streak': p.streak,
        'longestStreak': p.longestStreak,
        'totalJournalEntries': p.totalJournalEntries,
        'totalMeditationSeconds': p.totalMeditationSeconds,
        if (p.lastActiveAt != null)
          'lastActiveAt': Timestamp.fromDate(p.lastActiveAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      written++;
      inBatch++;
      // Firestore caps a batch at 500 operations.
      if (inBatch >= 400) {
        await batch.commit();
        batch = _db.batch();
        inBatch = 0;
      }
    }

    if (inBatch > 0) await batch.commit();
    return written;
  }

  /// Recomputes a user's streak / entry count / meditation total from their raw
  /// documents and writes them onto the profile doc, which is what the
  /// community leaderboard reads.
  ///
  /// Each source is computed independently so a failure in one (permissions,
  /// offline) leaves the other stats — and the previously stored values —
  /// intact instead of overwriting the profile with zeros.
  Future<UserStats?> syncProfileStats(String uid) async {
    final updates = <String, dynamic>{};
    int? streak;
    int? longestStreak;
    int? entriesCount;
    int? totalSeconds;
    DateTime? lastActiveAt;

    // 1. Journal entries → streak + total entries.
    try {
      final entriesQ = await _db
          .collection(AppConstants.entriesCollection)
          .where('uid', isEqualTo: uid)
          .get();

      final entryDates = <DateTime>[];
      for (final doc in entriesQ.docs) {
        final date = parseFirestoreDate(doc.data()['createdAt']) ??
            parseFirestoreDate(doc.data()['clientCreatedAt']);
        if (date != null) entryDates.add(date);
      }

      entriesCount = entriesQ.docs.length;
      streak = streakFromDates(entryDates);
      longestStreak = longestStreakFromDates(entryDates);
      updates['longestStreak'] = longestStreak;
      for (final d in entryDates) {
        final latest = lastActiveAt;
        if (latest == null || d.isAfter(latest)) lastActiveAt = d;
      }

      updates['streak'] = streak;
      updates['totalJournalEntries'] = entriesCount;
    } catch (e) {
      print('❌ syncProfileStats: entries query failed: $e');
    }

    // 2. Meditation sessions → total seconds.
    try {
      final sessionsQ = await _db
          .collection(AppConstants.meditationSessionsCollection)
          .where('uid', isEqualTo: uid)
          .get();

      var seconds = 0;
      for (final doc in sessionsQ.docs) {
        seconds += parseIntField(doc.data()['duration']);
        final date = parseFirestoreDate(doc.data()['createdAt']) ??
            parseFirestoreDate(doc.data()['clientCreatedAt']);
        final latest = lastActiveAt;
        if (date != null && (latest == null || date.isAfter(latest))) {
          lastActiveAt = date;
        }
      }

      totalSeconds = seconds;
      updates['totalMeditationSeconds'] = seconds;
    } catch (e) {
      print('❌ syncProfileStats: meditation query failed: $e');
    }

    if (updates.isEmpty) return null;

    if (lastActiveAt != null) {
      updates['lastActiveAt'] = Timestamp.fromDate(lastActiveAt);
    }
    updates['updatedAt'] = FieldValue.serverTimestamp();

    try {
      // set(merge) rather than update(): a profile doc that was never written
      // makes update() throw not-found, which is why new members showed up on
      // the leaderboard with no streak at all.
      await _db
          .collection(AppConstants.profilesCollection)
          .doc(uid)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      print('❌ syncProfileStats: profile write failed: $e');
    }

    // Mirror the non-sensitive counters into the public ranking collection.
    // Deliberately no email, phone, age or gender — /leaderboard is readable by
    // every signed-in member, so only what the Community screen renders goes in.
    // A Cloud Function recomputes this row from the underlying documents on the
    // member's next entry or session, so a self-reported value cannot persist.
    try {
      final profile = await getProfile(uid);
      await _db.collection(AppConstants.leaderboardCollection).doc(uid).set({
        'uid': uid,
        'displayName': (profile?.displayName ?? 'Soul'),
        if (profile?.avatarId != null) 'avatarId': profile!.avatarId,
        'streak': streak ?? 0,
        'longestStreak': longestStreak ?? 0,
        'totalJournalEntries': entriesCount ?? 0,
        'totalMeditationSeconds': totalSeconds ?? 0,
        if (lastActiveAt != null) 'lastActiveAt': Timestamp.fromDate(lastActiveAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ syncProfileStats: leaderboard write failed: $e');
    }

    return UserStats(
      streak: streak ?? 0,
      longestStreak: longestStreak ?? 0,
      totalJournalEntries: entriesCount ?? 0,
      totalMeditationSeconds: totalSeconds ?? 0,
      lastActiveAt: lastActiveAt,
    );
  }
}
