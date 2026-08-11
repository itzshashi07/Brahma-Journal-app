import 'package:brahma_app/core/utils/craft_stats.dart';
import 'package:brahma_app/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consistency numbers are the whole point of the craft feature, and they
/// are exactly the kind of arithmetic that is wrong by one and nobody notices
/// for a month. These pin the edges.

JournalEntry entry(
  DateTime when, {
  List<String> craft = const [],
  int minutes = 0,
  int mood = 3,
}) =>
    JournalEntry(
      uid: 'u',
      mood: mood,
      craftDone: craft,
      craftMinutes: minutes,
      createdAt: when,
    );

void main() {
  final today = DateTime(2026, 8, 9);
  DateTime ago(int days) => today.subtract(Duration(days: days));

  group('streaks', () {
    test('a day that has not happened yet does not break the streak', () {
      // Practised yesterday and the day before, nothing today — at 9am this
      // must still read as a 2-day streak, not as zero.
      final stats = CraftStats.from(
        [entry(ago(1), craft: ['riyaaz']), entry(ago(2), craft: ['riyaaz'])],
        now: today,
      );
      expect(stats.currentStreak, 2);
    });

    test('a missed day does break it', () {
      final stats = CraftStats.from(
        [entry(ago(2), craft: ['riyaaz']), entry(ago(3), craft: ['riyaaz'])],
        now: today,
      );
      expect(stats.currentStreak, 0);
    });

    test('today counts as soon as something is recorded', () {
      final stats = CraftStats.from(
        [entry(today, craft: ['riyaaz']), entry(ago(1), craft: ['riyaaz'])],
        now: today,
      );
      expect(stats.currentStreak, 2);
    });

    test('the longest streak survives a later gap', () {
      final stats = CraftStats.from(
        [
          for (var i = 10; i <= 14; i++) entry(ago(i), craft: ['wrote']),
          entry(ago(1), craft: ['wrote']),
        ],
        now: today,
      );
      expect(stats.longestStreak, 5);
      expect(stats.currentStreak, 1);
    });
  });

  group('counting days', () {
    test('two entries on one day count once', () {
      final stats = CraftStats.from(
        [
          entry(DateTime(2026, 8, 8, 9), craft: ['study']),
          entry(DateTime(2026, 8, 8, 23), craft: ['revision']),
        ],
        now: today,
      );
      expect(stats.daysPractised, 1);
      expect(stats.currentStreak, 1);
    });

    test('recorded minutes count even with no habit tapped', () {
      final stats = CraftStats.from([entry(ago(1), minutes: 45)], now: today);
      expect(stats.daysPractised, 1);
      expect(stats.totalMinutes, 45);
    });

    test('a journalled day with no craft is not a practice day', () {
      final stats = CraftStats.from([entry(ago(1))], now: today);
      expect(stats.daysPractised, 0);
      expect(stats.currentStreak, 0);
    });

    test('work older than the window is not counted in it', () {
      final stats = CraftStats.from(
        [entry(ago(45), craft: ['wrote'])],
        now: today,
      );
      expect(stats.daysPractised, 0);
      // …but it still contributes to the all-time longest streak.
      expect(stats.longestStreak, 1);
    });
  });

  group('weekly target', () {
    test('the week is the last seven days including today', () {
      final stats = CraftStats.from(
        [for (var i = 0; i < 4; i++) entry(ago(i), craft: ['trained'])],
        weeklyTarget: 5,
        now: today,
      );
      expect(stats.thisWeekDays, 4);
      expect(stats.daysToTarget, 1);
      expect(stats.onTrackThisWeek, isFalse);
    });

    test('meeting the target leaves nothing to do', () {
      final stats = CraftStats.from(
        [for (var i = 0; i < 6; i++) entry(ago(i), craft: ['trained'])],
        weeklyTarget: 5,
        now: today,
      );
      expect(stats.onTrackThisWeek, isTrue);
      expect(stats.daysToTarget, 0);
    });

    test('a day eight days ago is last week, not this one', () {
      final stats = CraftStats.from(
        [entry(ago(8), craft: ['trained'])],
        now: today,
      );
      expect(stats.thisWeekDays, 0);
    });
  });

  group('mood comparison', () {
    test('stays silent below three days of either kind', () {
      final stats = CraftStats.from(
        [
          entry(ago(1), craft: ['wrote'], mood: 5),
          entry(ago(2), mood: 1),
        ],
        now: today,
      );
      expect(stats.moodLift, isNull,
          reason: 'one good day is not a finding');
    });

    test('reports the lift when the sample is real', () {
      final stats = CraftStats.from(
        [
          for (var i = 1; i <= 3; i++) entry(ago(i), craft: ['wrote'], mood: 5),
          for (var i = 4; i <= 6; i++) entry(ago(i), mood: 3),
        ],
        now: today,
      );
      expect(stats.moodLift, closeTo(2.0, 0.001));
    });
  });

  group('weekday pattern', () {
    test('says nothing with less than a fortnight of data', () {
      final stats = CraftStats.from(
        [for (var i = 1; i <= 6; i++) entry(ago(i), craft: ['study'])],
        now: today,
      );
      expect(stats.strongestWeekday, isNull);
      expect(stats.weakestWeekday, isNull);
    });

    test('says nothing when every day is identical', () {
      final stats = CraftStats.from(
        [for (var i = 0; i < 21; i++) entry(ago(i), craft: ['study'])],
        now: today,
      );
      expect(stats.strongestWeekday, isNull,
          reason: 'a flat pattern is not a pattern');
    });
  });

  group('verdict', () {
    test('invites a first entry rather than reporting zero', () {
      final stats = CraftStats.from([], now: today);
      expect(stats.verdict('riyaaz'), contains('No riyaaz recorded yet'));
    });

    test('a long streak is named as such', () {
      final stats = CraftStats.from(
        [for (var i = 1; i <= 9; i++) entry(ago(i), craft: ['riyaaz'])],
        now: today,
      );
      expect(stats.verdict('riyaaz'), contains('9 days in a row'));
    });

    test('an empty week reads as recoverable, never as a failure', () {
      final stats = CraftStats.from(
        [for (var i = 10; i <= 14; i++) entry(ago(i), craft: ['riyaaz'])],
        weeklyTarget: 5,
        now: today,
      );
      final v = stats.verdict('riyaaz');
      expect(v, contains('One day is all it takes'));
      expect(v.toLowerCase(), isNot(contains('fail')));
    });
  });
}
