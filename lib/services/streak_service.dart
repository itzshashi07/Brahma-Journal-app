import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/stats_utils.dart';

/// Streak recovery: one missed day, once a month.
///
/// The rules, and why each one is there:
///
///   • **One day only.** Recovering a two-day gap would make the streak a
///     number you can buy rather than one you kept, and the number is the only
///     thing on the community board that is supposed to mean something. See
///     [recoverableGapDay] — a gap wider than a single day returns null and no
///     amount of allowance changes that.
///   • **Once every 30 days.** Enough that a genuine slip — a flight, a bad
///     day, a dead battery — does not erase four months of practice. Not enough
///     to become part of the routine.
///   • **Any missed day, whenever they notice.** The allowance is not tied to
///     the calendar month, because "you used yours on the 2nd, wait 29 days"
///     is a rule people can hold in their head, and "your allowance resets at
///     midnight on the 1st" is one they cannot.
///
/// The recovered day is stored as a date string on the profile rather than as a
/// fabricated journal entry. That distinction matters: the entry count, the
/// analytics and the member's own history stay honest — nothing is invented,
/// the streak calculation is simply told that one day is forgiven.
class StreakService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// How long before another recovery is available.
  ///
  /// firestore.rules enforces 29 days rather than 30. The difference is
  /// deliberate slack for clock skew: the client is the stricter of the two, so
  /// a member never sees "available" for a write the server then refuses.
  static const Duration allowance = Duration(days: 30);

  /// 'yyyy-MM-dd'. A date, not an instant — the whole point is a calendar day,
  /// and a timestamp would carry a timezone the member never chose.
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime? parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// The days this member has already recovered, read out of a profile
  /// document. Static so ProfileService can fold them into its streak
  /// calculation without another read.
  static List<DateTime> recoveredDaysFrom(Map<String, dynamic>? data) {
    final raw = data?['recoveredDays'];
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map(parseDayKey)
        .whereType<DateTime>()
        .toList();
  }

  /// The days this member has already recovered.
  ///
  /// Never throws: a refused read, an offline device or a profile that does not
  /// exist yet all mean "nothing forgiven", and a streak computed without a
  /// forgiven day is wrong by one rather than absent entirely.
  Future<List<DateTime>> recoveredDays(String uid) async {
    try {
      final doc = await _db
          .collection(AppConstants.profilesCollection)
          .doc(uid)
          .get();
      return recoveredDaysFrom(doc.data());
    } catch (e) {
      debugPrint('ℹ️ Recovered days unavailable: $e');
      return const [];
    }
  }

  /// What the member can do right now.
  ///
  /// [entryDates] is the days they actually practised; the recovered days are
  /// added here, so a second recovery is measured against a history that
  /// already includes the first.
  Future<StreakRecovery> check({
    required String uid,
    required Iterable<DateTime> entryDates,
  }) async {
    Map<String, dynamic>? data;
    try {
      final doc = await _db
          .collection(AppConstants.profilesCollection)
          .doc(uid)
          .get();
      data = doc.data();
    } catch (e) {
      debugPrint('⚠️ Streak recovery status unavailable: $e');
      return const StreakRecovery.unavailable();
    }

    final recovered = recoveredDaysFrom(data);
    final lastUsed = parseFirestoreDate(data?['lastStreakRecoveryAt']);
    final missed = recoverableGapDay([...entryDates, ...recovered]);

    return StreakRecovery(
      missedDay: missed,
      availableAt: lastUsed == null ? null : lastUsed.add(allowance),
    );
  }

  /// Forgives [day].
  ///
  /// `arrayUnion` rather than a read-modify-write: recovering the same day
  /// twice is then a no-op on the array, and two devices cannot overwrite each
  /// other's history. `lastStreakRecoveryAt` is a server timestamp because it
  /// is what the monthly limit is measured from, and a value the device picks
  /// is a value the device can pick again tomorrow.
  Future<void> recover({required String uid, required DateTime day}) async {
    await _db.collection(AppConstants.profilesCollection).doc(uid).set({
      'recoveredDays': FieldValue.arrayUnion([dayKey(day)]),
      'lastStreakRecoveryAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Whether a streak can be recovered, and if not, why not.
class StreakRecovery {
  /// The day that would be forgiven. Null when there is no single-day gap —
  /// either nothing is missing, or too much is.
  final DateTime? missedDay;

  /// When the monthly allowance returns. Null when it is available now.
  final DateTime? availableAt;

  const StreakRecovery({this.missedDay, this.availableAt});

  /// Used when the profile could not be read at all. Deliberately offers
  /// nothing: a recovery the server will refuse is worse than no button.
  const StreakRecovery.unavailable()
      : missedDay = null,
        availableAt = null;

  bool get hasAllowance {
    final at = availableAt;
    return at == null || DateTime.now().isAfter(at);
  }

  /// The one thing the UI actually asks.
  bool get canRecover => missedDay != null && hasAllowance;

  /// Whole days until the allowance returns; 0 when it is available.
  int get daysUntilAllowance {
    final at = availableAt;
    if (at == null || hasAllowance) return 0;
    final left = at.difference(DateTime.now());
    return left.inHours <= 0 ? 0 : (left.inHours / 24).ceil();
  }
}
