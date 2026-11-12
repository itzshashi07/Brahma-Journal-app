import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/weekly_reflection.dart';
import '../models/journal_entry.dart';

class WeeklyReflectionCard extends StatelessWidget {
  final List<JournalEntry> entries;
  final DateTime? now;
  const WeeklyReflectionCard({super.key, required this.entries, this.now});

  @override
  Widget build(BuildContext context) {
    final reflection = WeeklyReflection.from(entries, now ?? DateTime.now());
    if (reflection.days == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR LAST 7 DAYS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppTheme.primaryLight)),
          const SizedBox(height: 12),
          Text(
              'You made space on ${reflection.days} ${reflection.days == 1 ? 'day' : 'days'}.',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              reflection.recurringTopic == null
                  ? 'There is no perfect streak to keep. These are moments you kept for yourself.'
                  : '${reflection.recurringTopic} came up in your resets on ${reflection.topicDays} days. A topic to reflect on, rather than a conclusion about why you felt that way.',
              style:
                  const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          if (reflection.nextStep != null) ...[
            const SizedBox(height: 16),
            const Text('The last next step you chose',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(reflection.nextStep!, style: const TextStyle(height: 1.5)),
          ],
        ]),
      ),
    );
  }
}
