import 'package:flutter/material.dart';
import '../core/constants/streak_tiers.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

/// "You are 14 days from Gold."
///
/// A rank on its own only motivates whoever is winning. What moves everyone
/// else is a visible next step that is close enough to reach — so this shows
/// the current tier, the next one, and the exact number of days between them.
class StreakProgressCard extends StatelessWidget {
  final int streak;
  final String displayName;

  const StreakProgressCard({
    super.key,
    required this.streak,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final current = StreakTiers.forDays(streak);
    final next = StreakTiers.nextAfter(streak);
    final daysToNext = StreakTiers.daysToNext(streak);
    final progress = StreakTiers.progress(streak);

    return GlassCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: current?.gradient ??
                        [AppTheme.border, AppTheme.bgCardLight],
                  ),
                ),
                child: Center(
                  child: Text(
                    current?.emoji ?? '🌱',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current?.label ?? 'Not started yet',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      streak == 1 ? '1 day streak' : '$streak day streak',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (next != null && daysToNext != null) ...[
            const SizedBox(height: AppTheme.space4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(next.gradient.first),
              ),
            ),
            const SizedBox(height: AppTheme.space2 + 2),
            Row(
              children: [
                Text(next.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: AppTheme.textSecondary),
                      children: [
                        TextSpan(
                          text: daysToNext == 1
                              ? '1 more day'
                              : '$daysToNext more days',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: next.gradient.first,
                          ),
                        ),
                        TextSpan(text: ' to ${next.label}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              next.reward,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
              ),
            ),
          ] else if (current != null) ...[
            const SizedBox(height: AppTheme.space3),
            Text(
              current.reward,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                height: 1.45,
                color: AppTheme.accentLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the badges are actually for.
///
/// Sits under the leaderboard because a ranking without meaning becomes a
/// vanity game — and this app is not one. Says plainly what the streak is and
/// is not.
class StreakMeaningCard extends StatelessWidget {
  const StreakMeaningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          tint: AppTheme.accent.withValues(alpha: 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 18, color: AppTheme.accentLight),
                  const SizedBox(width: AppTheme.space2),
                  const Text(
                    'This is not a Snapchat streak',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space2 + 2),
              const Text(
                'Nobody loses anything if you miss a day. There is no penalty and '
                'no one to disappoint.\n\n'
                'What the number actually measures is how many days you chose to '
                'sit with yourself. That is the only thing here worth counting — '
                'and it is the thing that quietly changes a life.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.space4),
        const SectionHeading(
            title: 'What the badges mean', icon: Icons.workspace_premium_outlined),
        const SizedBox(height: AppTheme.space3),

        ...StreakTiers.all.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space2 + 2),
            child: GlassCard(
              padding: const EdgeInsets.all(AppTheme.space3),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: t.gradient),
                    ),
                    child: Center(
                        child: Text(t.emoji,
                            style: const TextStyle(fontSize: 17))),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t.label,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space2),
                            Text(
                              t.maxDays == null
                                  ? '${t.minDays}+ days'
                                  : '${t.minDays}–${t.maxDays} days',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: t.gradient.first,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.reward,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            height: 1.4,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
