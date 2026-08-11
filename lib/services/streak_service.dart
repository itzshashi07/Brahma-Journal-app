import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Streak recovery: one missed day, once a month.
///
/// The rules, and why each one is there:
///
///   • **One day only.** Recovering a two-day gap would make the streak a
///     number you can buy rather than one you kept, and the number is the only
///     thing on the community board that is supposed to mean something. A gap
///     wider than a single day is not recoverable and no allowance changes that.
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
///
/// ─────────────────────────────────────────────────────────────────────────
/// What moved to the server
///
/// Both the gap calculation and the 30-day allowance check now run in the API.
/// The client used to compute which day was recoverable and then write it, with
/// firestore.rules enforcing a 29-day window as a backstop. That let the device
/// choose the day it was forgiving. The server now re-derives the recoverable
/// day itself and ignores whatever the client thinks — otherwise the streak is
/// a number you can type rather than one you kept.
class StreakService {
  final ApiService _api = ApiService();

  /// How long before another recovery is available. Kept for the UI copy; the
  /// server is the authority and enforces the same window.
  static const Duration allowance = Duration(days: 30);

  int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  /// What the member can do right now.
  ///
  /// [entryDates] is no longer sent — the server reads the entries itself, so
  /// the parameter is accepted and ignored to keep existing call sites
  /// compiling. Never throws: a failed check offers nothing, because a recovery
  /// the server will refuse is worse than no button.
  Future<StreakRecovery> check({
    String? uid,
    Iterable<DateTime> entryDates = const [],
  }) async {
    try {
      final body = await _api.get('/api/profile/me/streak-recovery',
          query: {'tz': '$_tzOffsetMinutes'});

      final missedRaw = body?['missedDay'];
      final availableRaw = body?['availableAt'];

      return StreakRecovery(
        missedDay: missedRaw == null ? null : parseDayKey(missedRaw.toString()),
        availableAt:
            availableRaw == null ? null : DateTime.tryParse(availableRaw.toString()),
      );
    } catch (e) {
      debugPrint('⚠️ Streak recovery status unavailable: $e');
      return const StreakRecovery.unavailable();
    }
  }

  /// Spends the allowance.
  ///
  /// [day] is accepted for call-site compatibility and deliberately not sent:
  /// the server decides which day is recoverable. Returns the day that was
  /// actually forgiven, or null if the server refused.
  Future<DateTime?> recover({String? uid, DateTime? day}) async {
    try {
      final body = await _api.post('/api/profile/me/streak-recovery', {
        'tzOffsetMinutes': _tzOffsetMinutes,
      });
      final recovered = body?['recoveredDay'];
      return recovered == null ? null : parseDayKey(recovered.toString());
    } catch (e) {
      debugPrint('⚠️ Streak recovery failed: $e');
      return null;
    }
  }

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

  /// The days this member has already had forgiven.
  ///
  /// Kept because callers still fold them into a locally computed streak for
  /// the dashboard, which must not wait on a round trip to show a number it can
  /// derive. Never throws: no forgiven days means a streak wrong by one rather
  /// than a screen that fails.
  Future<List<DateTime>> recoveredDays([String? uid]) async {
    try {
      final body = await _api.get('/api/profile/me');
      final raw = body?['profile']?['recoveredDays'];
      if (raw is! List) return const [];
      return raw
          .whereType<String>()
          .map(parseDayKey)
          .whereType<DateTime>()
          .toList();
    } catch (e) {
      debugPrint('ℹ️ Recovered days unavailable: $e');
      return const [];
    }
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
