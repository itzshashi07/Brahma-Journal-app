import 'package:flutter/material.dart';

/// Streak recognition.
///
/// Four tiers plus two milestones, keyed on the member's *best* streak so an
/// earned badge never disappears the day someone misses.
///
///   Silver    1–20 days
///   Gold      21–74 days
///   Platinum  75–364 days
///   Diamond   365 days   → complimentary goodies delivered
///   Eternal   3 years    → a surprise
///
/// The ranges are contiguous and half-open so a boundary day belongs to exactly
/// one tier — day 21 is Gold, not both Silver and Gold.
class StreakTier {
  final String id;
  final String label;
  final String emoji;
  final int minDays;
  final int? maxDays;
  final List<Color> gradient;
  final String reward;

  const StreakTier({
    required this.id,
    required this.label,
    required this.emoji,
    required this.minDays,
    required this.gradient,
    required this.reward,
    this.maxDays,
  });

  bool contains(int days) =>
      days >= minDays && (maxDays == null || days <= maxDays!);
}

class StreakTiers {
  static const silver = StreakTier(
    id: 'silver',
    label: 'Silver Seeker',
    emoji: '🥈',
    minDays: 1,
    maxDays: 20,
    gradient: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
    reward: 'You have begun. The hardest part is behind you.',
  );

  static const gold = StreakTier(
    id: 'gold',
    label: 'Golden Soul',
    emoji: '🥇',
    minDays: 21,
    maxDays: 74,
    gradient: [Color(0xFFFBBF24), Color(0xFFD97706)],
    reward: 'Twenty-one days is where a practice becomes a habit.',
  );

  static const platinum = StreakTier(
    id: 'platinum',
    label: 'Platinum Sage',
    emoji: '💎',
    minDays: 75,
    maxDays: 364,
    gradient: [Color(0xFFA5B4FC), Color(0xFF6366F1)],
    reward: 'Seventy-five days. This is who you are now, not what you are trying.',
  );

  static const diamond = StreakTier(
    id: 'diamond',
    label: 'Diamond Year',
    emoji: '👑',
    minDays: 365,
    maxDays: 1094,
    gradient: [Color(0xFF67E8F9), Color(0xFF0891B2)],
    reward: 'A full year. Complimentary goodies delivered to your home 🎁',
  );

  static const eternal = StreakTier(
    id: 'eternal',
    label: 'Eternal Flame',
    emoji: '🔱',
    minDays: 1095,
    gradient: [Color(0xFFF0ABFC), Color(0xFF9333EA)],
    reward: 'Three years of practice. Something unexpected is coming your way ✨',
  );

  static const all = [silver, gold, platinum, diamond, eternal];

  /// The tier a streak currently sits in, or null below one day.
  static StreakTier? forDays(int days) {
    for (final t in all.reversed) {
      if (days >= t.minDays) return t;
    }
    return null;
  }

  /// The next tier to aim for, or null once Eternal is reached.
  static StreakTier? nextAfter(int days) {
    for (final t in all) {
      if (days < t.minDays) return t;
    }
    return null;
  }

  /// Days remaining until the next tier, or null at the top.
  static int? daysToNext(int days) {
    final next = nextAfter(days);
    return next == null ? null : next.minDays - days;
  }

  /// Progress through the current tier, 0–1. Used for the ring on the profile.
  static double progress(int days) {
    final current = forDays(days);
    final next = nextAfter(days);
    if (current == null) return next == null ? 0 : (days / next.minDays).clamp(0.0, 1.0);
    if (next == null) return 1;
    final span = next.minDays - current.minDays;
    return span <= 0 ? 1 : ((days - current.minDays) / span).clamp(0.0, 1.0);
  }
}
