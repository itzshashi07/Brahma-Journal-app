import 'package:flutter_test/flutter_test.dart';
import 'package:brahma_app/core/utils/stats_utils.dart';

DateTime daysAgo(int n, {int hour = 12}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).subtract(Duration(days: n));
}

void main() {
  group('streakFromDates', () {
    test('is zero with no activity', () {
      expect(streakFromDates([]), 0);
    });

    test('counts a single entry today', () {
      expect(streakFromDates([daysAgo(0)]), 1);
    });

    test('counts consecutive days ending today', () {
      expect(streakFromDates([daysAgo(0), daysAgo(1), daysAgo(2)]), 3);
    });

    test('keeps the streak alive when today has no entry yet', () {
      expect(streakFromDates([daysAgo(1), daysAgo(2)]), 2);
    });

    test('breaks once the last activity is older than yesterday', () {
      expect(streakFromDates([daysAgo(2), daysAgo(3)]), 0);
    });

    test('stops at the first gap', () {
      expect(streakFromDates([daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(4)]), 2);
    });

    test('counts several entries on one day once', () {
      expect(
        streakFromDates([daysAgo(0, hour: 8), daysAgo(0, hour: 21), daysAgo(1)]),
        2,
      );
    });

    test('ignores entries dated in the future (skewed device clock)', () {
      expect(streakFromDates([daysAgo(-3), daysAgo(0), daysAgo(1)]), 2);
    });

    test('is order independent', () {
      expect(streakFromDates([daysAgo(2), daysAgo(0), daysAgo(1)]), 3);
    });

    test('survives a DST boundary', () {
      // 2024-11-03 is the US fall-back day; subtracting a Duration of 24h from
      // local midnight lands on 23:00 the day before, which used to break the
      // day-to-day equality check and reset the streak.
      final days = [
        DateTime(2024, 11, 4, 9),
        DateTime(2024, 11, 3, 9),
        DateTime(2024, 11, 2, 9),
      ];
      expect(longestStreakFromDates(days), 3);
    });
  });

  group('longestStreakFromDates', () {
    test('is zero with no activity', () {
      expect(longestStreakFromDates([]), 0);
    });

    test('finds the best run even after the current streak breaks', () {
      final days = [
        daysAgo(20), daysAgo(19), daysAgo(18), daysAgo(17), // run of 4
        daysAgo(9), daysAgo(8), // run of 2
      ];
      expect(longestStreakFromDates(days), 4);
      expect(streakFromDates(days), 0);
    });
  });

  group('day helpers', () {
    test('daysBetween ignores the time of day', () {
      expect(daysBetween(daysAgo(1, hour: 23), daysAgo(0, hour: 1)), 1);
    });

    test('isSameDayAsToday', () {
      expect(isSameDayAsToday(daysAgo(0, hour: 23)), isTrue);
      expect(isSameDayAsToday(daysAgo(1)), isFalse);
    });
  });

  group('field parsing', () {
    test('parseIntField tolerates the types older builds wrote', () {
      expect(parseIntField(300), 300);
      expect(parseIntField(300.7), 300);
      expect(parseIntField('300'), 300);
      expect(parseIntField(null), 0);
      expect(parseIntField('abc'), 0);
    });

    test('parseFirestoreDate returns null for a pending server timestamp', () {
      expect(parseFirestoreDate(null), isNull);
      expect(parseFirestoreDate('2024-03-05T10:00:00Z')?.toUtc().day, 5);
      expect(parseFirestoreDate(1709632800000), isNotNull);
    });
  });

  group('formatDurationShort', () {
    test('keeps short sessions visible instead of rounding them to 0.0h', () {
      expect(formatDurationShort(0), '0m');
      expect(formatDurationShort(90), '1m');
      expect(formatDurationShort(300), '5m');
      expect(formatDurationShort(3600), '1.0h');
      expect(formatDurationShort(5400), '1.5h');
    });
  });
}
