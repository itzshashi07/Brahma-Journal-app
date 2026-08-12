import '../../models/journal_entry.dart';
import '../constants/professions.dart';

/// Whether a member is actually doing the work they said they cared about.
///
/// Kept out of the analytics widget on purpose: these are the numbers the whole
/// feature is judged on, they are easy to get subtly wrong (off-by-one on
/// streaks, double-counting two entries on one day), and a pure function is the
/// only version of them that can be reasoned about.
///
/// Everything here works off calendar days, not 24-hour windows. Someone who
/// practises at 11pm and again at 1am has practised on two days, and telling
/// them otherwise would be arguing with their own memory.
class CraftStats {
  final int daysPractised;
  final int windowDays;

  /// Consecutive days up to today (or yesterday — today is still in progress,
  /// so a streak does not break until a day has actually been missed).
  final int currentStreak;
  final int longestStreak;

  /// Days practised in the last seven, against the member's weekly target.
  final int thisWeekDays;
  final int weeklyTarget;

  final int totalMinutes;

  /// Habit id → times recorded, most-used first.
  final List<MapEntry<String, int>> habitCounts;

  /// Average mood on days with craft work, and on days without. Null when
  /// there is not enough of either to compare honestly.
  final double? moodWithCraft;
  final double? moodWithoutCraft;

  /// Weekday index (1 = Monday) the member practises most, or null when the
  /// sample is too thin to mean anything.
  final int? strongestWeekday;
  final int? weakestWeekday;

  const CraftStats({
    required this.daysPractised,
    required this.windowDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.thisWeekDays,
    required this.weeklyTarget,
    required this.totalMinutes,
    required this.habitCounts,
    this.moodWithCraft,
    this.moodWithoutCraft,
    this.strongestWeekday,
    this.weakestWeekday,
  });

  double get consistency =>
      windowDays == 0 ? 0 : daysPractised / windowDays;

  bool get onTrackThisWeek => thisWeekDays >= weeklyTarget;

  /// How many more days this week would hit the target. Zero when already met.
  int get daysToTarget =>
      thisWeekDays >= weeklyTarget ? 0 : weeklyTarget - thisWeekDays;

  /// The mood difference, when there is a real comparison to make. Positive
  /// means they feel better on days they do the work — which is the single
  /// most motivating sentence this app can show anybody, and the reason the
  /// comparison is computed at all.
  double? get moodLift {
    final a = moodWithCraft, b = moodWithoutCraft;
    if (a == null || b == null) return null;
    return a - b;
  }

  /// The member's local calendar day for an instant.
  ///
  /// `.toLocal()` first, for the reason spelled out on `dayMarker` in
  /// core/utils/stats_utils.dart: an entry parsed from the API is a UTC
  /// DateTime, and reading `.day` off it files anything written after local
  /// midnight under the previous day. Here that split one late night's practice
  /// across two cells of the consistency grid.
  static DateTime _day(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Builds the picture from a member's entries.
  ///
  /// [window] is how far back to look. Thirty days is the default because it is
  /// long enough to show a pattern and short enough that a bad fortnight in
  /// March does not haunt someone in June.
  static CraftStats from(
    List<JournalEntry> entries, {
    int window = 30,
    int weeklyTarget = Professions.defaultWeeklyTarget,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final since = today.subtract(Duration(days: window - 1));

    // One entry per calendar day. Two entries on the same day is a real state —
    // the check-in and the journal can both write — and counting it twice would
    // inflate every number below.
    final byDay = <DateTime, JournalEntry>{};
    for (final e in entries) {
      final d = _day(e.createdAt);
      final existing = byDay[d];
      // Keep the richer record when a day has more than one.
      if (existing == null ||
          (e.craftDone.length + (e.craftMinutes > 0 ? 1 : 0)) >
              (existing.craftDone.length +
                  (existing.craftMinutes > 0 ? 1 : 0))) {
        byDay[d] = e;
      }
    }

    final inWindow = byDay.entries
        .where((e) => !e.key.isBefore(since) && !e.key.isAfter(today))
        .toList();

    final practisedDays = <DateTime>{
      for (final e in inWindow)
        if (e.value.didCraft) e.key,
    };

    // ─── streaks ───
    //
    // Counted from yesterday when today has no entry yet: at 9am nobody has
    // practised, and zeroing a 40-day streak because the day is young is the
    // fastest way to make someone stop opening the app.
    final allPractised = <DateTime>{
      for (final e in byDay.entries)
        if (e.value.didCraft) e.key,
    };

    var current = 0;
    var cursor = allPractised.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (allPractised.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var longest = 0;
    final sorted = allPractised.toList()..sort();
    var run = 0;
    DateTime? previous;
    for (final d in sorted) {
      if (previous != null && d.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      previous = d;
    }

    // ─── this week ───
    final weekStart = today.subtract(const Duration(days: 6));
    final thisWeek = allPractised
        .where((d) => !d.isBefore(weekStart) && !d.isAfter(today))
        .length;

    // ─── habits ───
    final counts = <String, int>{};
    var minutes = 0;
    for (final e in inWindow) {
      for (final h in e.value.craftDone) {
        counts[h] = (counts[h] ?? 0) + 1;
      }
      minutes += e.value.craftMinutes;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ─── mood comparison ───
    //
    // Needs at least three of each kind. Below that the "average" is one good
    // day, and presenting it as a finding would be a lie told with a number.
    final withCraft = inWindow.where((e) => e.value.didCraft).toList();
    final withoutCraft = inWindow.where((e) => !e.value.didCraft).toList();
    double? avg(List<MapEntry<DateTime, JournalEntry>> xs) => xs.length < 3
        ? null
        : xs.map((e) => e.value.mood).reduce((a, b) => a + b) / xs.length;

    // ─── weekday pattern ───
    //
    // Needs two weeks of data before it says anything: with one week every
    // weekday has a sample of exactly one, and "you are worst on Tuesdays" is
    // then a statement about a single Tuesday.
    int? strongest, weakest;
    if (inWindow.length >= 14) {
      final done = <int, int>{}, seen = <int, int>{};
      for (final e in inWindow) {
        final wd = e.key.weekday;
        seen[wd] = (seen[wd] ?? 0) + 1;
        if (e.value.didCraft) done[wd] = (done[wd] ?? 0) + 1;
      }
      final rates = <int, double>{
        for (final wd in seen.keys)
          if (seen[wd]! >= 2) wd: (done[wd] ?? 0) / seen[wd]!,
      };
      if (rates.length >= 4) {
        final ordered = rates.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        strongest = ordered.first.key;
        weakest = ordered.last.key;
        // Identical rates top and bottom means there is no pattern to report.
        if (ordered.first.value == ordered.last.value) {
          strongest = null;
          weakest = null;
        }
      }
    }

    return CraftStats(
      daysPractised: practisedDays.length,
      windowDays: window,
      currentStreak: current,
      longestStreak: longest,
      thisWeekDays: thisWeek,
      weeklyTarget: weeklyTarget,
      totalMinutes: minutes,
      habitCounts: ranked,
      moodWithCraft: avg(withCraft),
      moodWithoutCraft: avg(withoutCraft),
      strongestWeekday: strongest,
      weakestWeekday: weakest,
    );
  }

  static const weekdayNames = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  /// One honest sentence about how it is going.
  ///
  /// Ordered so the most useful thing is said first, and phrased so that a bad
  /// month reads as recoverable rather than as a verdict. Nobody has ever been
  /// helped back to a habit by being told they are at 12%.
  String verdict(String workWord) {
    if (daysPractised == 0) {
      return 'No $workWord recorded yet. Tap one thing in today\'s journal and '
          'this page starts working.';
    }
    if (currentStreak >= 7) {
      return '$currentStreak days in a row. This is what it looks like when it '
          'has stopped being a decision.';
    }
    if (onTrackThisWeek) {
      return 'Target met this week — $thisWeekDays of $weeklyTarget days. '
          'Whatever you are doing, keep doing it.';
    }
    if (thisWeekDays == 0) {
      return 'Nothing this week yet. One day is all it takes to start the count '
          'again — it does not have to be a good one.';
    }
    if (daysToTarget == 1) {
      return 'One more day hits your target this week. That is the whole gap.';
    }
    return '$thisWeekDays of $weeklyTarget days this week. $daysToTarget more '
        'and the week counts.';
  }
}
