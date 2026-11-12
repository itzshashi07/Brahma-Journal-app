import '../../models/journal_entry.dart';
import '../../models/quick_reset.dart';
import 'stats_utils.dart';

/// Descriptive observations, without diagnosis or claims of cause and effect.
class WeeklyReflection {
  final int days;
  final String? recurringTopic;
  final int topicDays;
  final String? nextStep;
  const WeeklyReflection(
      {required this.days,
      this.recurringTopic,
      this.topicDays = 0,
      this.nextStep});

  static WeeklyReflection from(List<JournalEntry> entries, DateTime now) {
    final today = dayMarker(now);
    final first = today.subtract(const Duration(days: 6));
    final byDay = <DateTime, JournalEntry>{};
    for (final entry in entries) {
      final day = dayMarker(entry.createdAt);
      if (day.isBefore(first) || day.isAfter(today)) continue;
      final previous = byDay[day];
      if (previous == null || entry.createdAt.isAfter(previous.createdAt)) {
        byDay[day] = entry;
      }
    }
    final ordered = byDay.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final counts = <String, int>{};
    for (final entry in ordered) {
      final topic = entry.checkIn['reset_topic'];
      if (topic != null && QuickReset.topics.contains(topic)) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    final topics = counts.keys.toList()
      ..sort((a, b) {
        final order = counts[b]!.compareTo(counts[a]!);
        return order == 0 ? a.compareTo(b) : order;
      });
    final top =
        topics.isNotEmpty && counts[topics.first]! >= 2 ? topics.first : null;
    String? next;
    for (final entry in ordered) {
      final value = entry.checkIn['reset_next_step']?.trim();
      if (value != null && value.isNotEmpty) {
        next = value;
        break;
      }
    }
    return WeeklyReflection(
        days: byDay.length,
        recurringTopic: top,
        topicDays: top == null ? 0 : counts[top]!,
        nextStep: next);
  }
}
