import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/professions.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/craft_stats.dart';
import '../models/journal_entry.dart';
import '../providers/auth_provider.dart';
import 'craft_setup_sheet.dart';
import 'sacred.dart';

/// Whether you are doing the thing you said you cared about.
///
/// The rest of the analytics screen answers "how have you felt" and "how long
/// did you sit". Neither is what a singer, a student or someone building a
/// business actually wants to know, which is simply: *am I keeping this up?*
///
/// Three deliberate choices in how it presents that:
///   • the aim is quoted back in the member's own words, at the top;
///   • the last 30 days are drawn as a grid of squares, because a shape is
///     read in a second and a percentage has to be interpreted;
///   • the mood comparison is only shown when there is a real sample behind
///     it — "you feel better on days you practise" is the most persuasive
///     sentence here, and it must never be a lie told with a number.
class CraftConsistencyCard extends StatelessWidget {
  final List<JournalEntry> entries;

  const CraftConsistencyCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    if (profile == null || !profile.hasCraft) {
      return _Invitation(onSetup: () => CraftSetupSheet.show(context));
    }

    final craft = Professions.byId(profile.profession);
    final accent = Professions.accentFor(craft.id);
    final stats = CraftStats.from(
      entries,
      weeklyTarget: profile.craftWeeklyTarget,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(craft.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      craft.label,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary),
                    ),
                    if ((profile.aim ?? '').isNotEmpty)
                      Text(
                        profile.aim!,
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            height: 1.4,
                            color: accent),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => CraftSetupSheet.show(context),
                child: const Icon(Icons.tune_rounded,
                    size: 18, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),

          // The three numbers, in the order they matter.
          Row(
            children: [
              _Figure(
                value: '${stats.currentStreak}',
                label: 'day streak',
                accent: accent,
              ),
              _Divider(),
              _Figure(
                value: '${stats.thisWeekDays}/${stats.weeklyTarget}',
                label: 'this week',
                accent: stats.onTrackThisWeek ? AppTheme.success : accent,
              ),
              _Divider(),
              _Figure(
                value: '${stats.daysPractised}',
                label: 'of last 30 days',
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),

          _MonthGrid(entries: entries, accent: accent),
          const SizedBox(height: AppTheme.space4),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              stats.verdict(craft.workWord),
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  height: 1.55,
                  color: AppTheme.textSecondary),
            ),
          ),

          // The finding that actually changes behaviour, when it is real.
          if (stats.moodLift != null && stats.moodLift!.abs() >= 0.3) ...[
            const SizedBox(height: AppTheme.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  stats.moodLift! > 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 15,
                  color: stats.moodLift! > 0
                      ? AppTheme.success
                      : AppTheme.accentLight,
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    stats.moodLift! > 0
                        ? 'Your mood is ${stats.moodLift!.toStringAsFixed(1)} points higher on days you do your ${craft.workWord}.'
                        : 'Your mood runs ${stats.moodLift!.abs().toStringAsFixed(1)} points lower on ${craft.workWord} days. Worth asking whether the load is too heavy.',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        height: 1.5,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],

          if (stats.strongestWeekday != null && stats.weakestWeekday != null) ...[
            const SizedBox(height: AppTheme.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    '${CraftStats.weekdayNames[stats.strongestWeekday]}s are your strongest. '
                    '${CraftStats.weekdayNames[stats.weakestWeekday]}s are where it slips.',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        height: 1.5,
                        color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ],

          if (stats.habitCounts.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            const Text(
              'WHAT YOU ACTUALLY DID',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.space3),
            for (final e in stats.habitCounts.take(4))
              _HabitBar(
                // resolveLabel, not habitLabel: the member's own checklist
                // items are in these counts too, and looking them up in the
                // profession presets alone would render them as raw ids.
                label: Professions.resolveLabel(
                    craft.id, e.key, profile.customHabits),
                count: e.value,
                max: stats.habitCounts.first.value,
                accent: accent,
              ),
          ],

          if (stats.totalMinutes > 0) ...[
            const SizedBox(height: AppTheme.space3),
            Text(
              '${(stats.totalMinutes / 60).toStringAsFixed(1)} hours logged this month.',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thirty squares, oldest on the left. A shape you read in a second.
class _MonthGrid extends StatelessWidget {
  final List<JournalEntry> entries;
  final Color accent;

  const _MonthGrid({required this.entries, required this.accent});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));

    final practised = <DateTime>{};
    final journalled = <DateTime>{};
    for (final e in entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      journalled.add(d);
      if (e.didCraft) practised.add(d);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sized from the available width so the row never overflows on a small
        // phone — a fixed 12px square wrapped awkwardly at 320dp.
        const gap = 4.0;
        final size = ((constraints.maxWidth - gap * 29) / 30).clamp(6.0, 14.0);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(30, (i) {
            final day = start.add(Duration(days: i));
            final did = practised.contains(day);
            final wrote = journalled.contains(day);

            return Tooltip(
              message: '${day.day}/${day.month} · '
                  '${did ? 'practised' : (wrote ? 'journalled, no practice' : 'nothing recorded')}',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  // Three states, not two: a day you journalled but did not
                  // practise is a different fact from a day you never opened
                  // the app, and flattening them would misreport the habit.
                  color: did
                      ? accent
                      : wrote
                          ? accent.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _Figure({required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 10.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.08),
      );
}

class _HabitBar extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final Color accent;

  const _HabitBar({
    required this.label,
    required this.count,
    required this.max,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : count / max,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space2),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown until a member names their craft. An empty consistency grid for a
/// profession nobody chose would be a chart of nothing.
class _Invitation extends StatelessWidget {
  final VoidCallback onSetup;

  const _Invitation({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 18)),
              SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  'Track what you are working towards',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2),
          const Text(
            'A singer, a writer, a student, an engineer — everyone has a thing '
            'they are trying to get better at, and everyone loses track of '
            'whether they are really doing it.\n\n'
            'Name yours and this page will show you: how many days you actually '
            'practised, your streak, the days of the week you slip, and whether '
            'you feel better on the days you do the work.',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                height: 1.6,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.space4),
          SacredButton(
            label: 'Name what I am working on',
            icon: Icons.arrow_forward_rounded,
            onTap: onSetup,
          ),
        ],
      ),
    );
  }
}
