import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared stat helpers so the dashboard, journal screen, analytics and the
/// community leaderboard all agree on the same numbers. Every streak in the
/// app must go through [streakFromDates] — duplicated implementations are how
/// the leaderboard and dashboard drifted apart.

/// Normalizes any DateTime to a UTC midnight marker for that calendar day.
///
/// UTC is deliberate: with local DateTimes, `subtract(Duration(days: 1))`
/// across a DST boundary lands on 23:00 of the previous day, so day-to-day
/// equality checks silently fail and the streak resets to 1.
DateTime dayMarker(DateTime date) => DateTime.utc(date.year, date.month, date.day);

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
