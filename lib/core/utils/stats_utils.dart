import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared stat helpers so the dashboard, journal screen, analytics and the
/// community leaderboard all agree on the same numbers. Every streak in the
/// app must go through [streakFromDates] — duplicated implementations are how
/// the leaderboard and dashboard drifted apart.

/// Normalizes any DateTime to a UTC midnight marker for **the member's local
/// calendar day**.
///
/// Two separate things are going on in one line, and both matter.
///
/// **`.toLocal()` first.** This was the bug. The API answers with ISO strings
/// ending in `Z`, and `DateTime.parse` on those returns a *UTC* DateTime — so
/// reading `.year/.month/.day` straight off it filed every entry under its UTC
/// calendar day, while [todayMarker] below read the components off
/// `DateTime.now()`, which is local. Every comparison in this file was
/// therefore between a UTC day and a local one.
///
/// East of Greenwich that quietly moves anything written after midnight to the
/// day before. In IST the window is 00:00–05:30 — which is not an edge case for
/// this app, it is the hour the whole product is about. A member who journals
/// at 1am was told their entry was yesterday's: the dashboard showed "Today's
/// Entry: Pending" for an entry they had just written, and the streak counted
/// the two halves of one night as a gap. Measured on a real account it read 4
/// where the server said 9, and the four days it lost were the four written
/// after midnight.
///
/// The server has always used the caller's real timezone offset for this — see
/// `tzOffset` in the backend's routes/profile.js — so the app was also the only
/// one of the two getting it wrong, and the two numbers disagreed on the same
/// screen.
///
/// **Then `DateTime.utc(...)`.** Still UTC, deliberately, for the arithmetic:
/// with local DateTimes `subtract(Duration(days: 1))` across a DST boundary
/// lands on 23:00 of the previous day, so day-to-day equality silently fails
/// and the streak resets to 1. So: local components, UTC container.
DateTime dayMarker(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

/// Today as a day marker, in the device's local calendar.
DateTime todayMarker() => dayMarker(DateTime.now());

/// Whole calendar days between two instants (b - a).
int daysBetween(DateTime a, DateTime b) => dayMarker(b).difference(dayMarker(a)).inDays;

/// True when [date] falls on the current local calendar day.
bool isSameDayAsToday(DateTime date) => dayMarker(date) == todayMarker();

/// Number of consecutive days of activity ending today or yesterday.
///
/// Returns 0 when the most recent activity is older than yesterday (the streak
/// is broken). Activity dated in the future — e.g. from a device with a skewed
/// clock — is ignored rather than counted.
int streakFromDates(Iterable<DateTime> dates) {
  final today = todayMarker();
  final days = dates
      .map(dayMarker)
      .where((d) => !d.isAfter(today))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // most recent first

  if (days.isEmpty) return 0;
  if (today.difference(days.first).inDays > 1) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/// The single missed day a streak recovery would repair, or null when there is
/// nothing recoverable.
///
/// "Recoverable" is deliberately narrow, and the two conditions are the whole
/// feature:
///
///   1. **The gap is exactly one day wide.** The day before the missed day must
///      itself be active — otherwise filling one day joins nothing to anything
///      and the member is buying back a streak they did not have. Two missed
///      days in a row is a broken streak, and this returns null for it.
///   2. **Filling it revives the streak.** A gap further back than the day
///      before yesterday means today *and* yesterday are both empty, so the
///      streak is already gone for a reason the recovery does not address.
///
/// Today is never the answer, even when nothing has been written yet: the day
/// is not over, and it can still be filled by actually journalling — which is
/// the thing this whole app exists to encourage.
DateTime? recoverableGapDay(Iterable<DateTime> dates) {
  final today = todayMarker();
  final active = dates.map(dayMarker).where((d) => !d.isAfter(today)).toSet();
  if (active.isEmpty) return null;

  // Walk back from yesterday to the most recent day with nothing on it.
  var missed = today.subtract(const Duration(days: 1));
  while (active.contains(missed)) {
    missed = missed.subtract(const Duration(days: 1));
  }

  if (!active.contains(missed.subtract(const Duration(days: 1)))) return null;
  if (daysBetween(missed, today) > 2) return null;

  return missed;
}

/// The longest run of consecutive active days anywhere in the history.
///
/// Backs the badges: an achievement shouldn't disappear the day someone misses
/// a session.
int longestStreakFromDates(Iterable<DateTime> dates) {
  final days = dates.map(dayMarker).toSet().toList()..sort();
  if (days.isEmpty) return 0;

  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  return longest;
}

/// Tolerant Firestore date reader.
///
/// Returns null for a pending `serverTimestamp()` (a write that has not been
/// acknowledged yet reads back as null) so callers can skip it instead of
/// silently substituting `DateTime.now()` and inventing a day of activity.
DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Tolerant int reader — durations have been written as int, double and string
/// by different app versions, and `as int` on any of the others threw and took
/// the whole stat sync down with it.
int parseIntField(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Formats a duration in seconds the way the community leaderboard and
/// analytics both show it: minutes below an hour, hours above.
String formatDurationShort(int seconds) {
  if (seconds <= 0) return '0m';
  if (seconds < 3600) return '${(seconds / 60).floor()}m';
  return '${(seconds / 3600).toStringAsFixed(1)}h';
}
