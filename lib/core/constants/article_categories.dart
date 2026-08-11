import 'package:flutter/material.dart';

/// Categories for Sanctuary articles.
///
/// The card used to print a hard-coded "WISDOM" chip on every post, so a
/// library of seventy articles would have looked like one undifferentiated
/// pile. A stored category id lets the list filter and gives the reader a way
/// in — most people arrive wanting one subject, not "spirituality" in general.
class ArticleCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// One line on what belongs here — shown when the category is selected, so
  /// the filter explains itself instead of being a bare word.
  final String blurb;

  const ArticleCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.blurb,
  });
}

class ArticleCategories {
  static const all = <ArticleCategory>[
    ArticleCategory(
      id: 'dark-psychology',
      label: 'Dark Psychology',
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFF9333EA),
      blurb: 'How manipulation actually works — so you can spot it early.',
    ),
    ArticleCategory(
      id: 'manipulation',
      label: 'Influence & Manipulation',
      icon: Icons.pan_tool_outlined,
      color: Color(0xFF7C3AED),
      blurb: 'The line between persuading someone and using them.',
    ),
    ArticleCategory(
      id: 'toxic-relationships',
      label: 'Toxic Relationships',
      icon: Icons.heart_broken_outlined,
      color: Color(0xFFDC2626),
      blurb: 'Patterns that drain you, and the names for them.',
    ),
    ArticleCategory(
      id: 'love-attachment',
      label: 'Love & Attachment',
      icon: Icons.favorite_outline,
      color: Color(0xFFEC4899),
      blurb: 'Why you love the way you do, and what to do about it.',
    ),
    ArticleCategory(
      id: 'breakups-healing',
      label: 'Breakups & Healing',
      icon: Icons.healing_outlined,
      color: Color(0xFFF472B6),
      blurb: 'Getting through the months nobody prepares you for.',
    ),
    ArticleCategory(
      id: 'family',
      label: 'Family & Parents',
      icon: Icons.home_outlined,
      color: Color(0xFFF59E0B),
      blurb: 'Love, duty, guilt — and where your own life fits in.',
    ),
    ArticleCategory(
      id: 'friendship',
      label: 'Friendship',
      icon: Icons.people_outline,
      color: Color(0xFF0EA5E9),
      blurb: 'Who stays, who fades, and why that is allowed.',
    ),
    ArticleCategory(
      id: 'self-worth',
      label: 'Self-Worth',
      icon: Icons.emoji_events_outlined,
      color: Color(0xFFFBBF24),
      blurb: 'Living without needing everyone to approve first.',
    ),
    ArticleCategory(
      id: 'boundaries',
      label: 'Boundaries',
      icon: Icons.fence_outlined,
      color: Color(0xFF14B8A6),
      blurb: 'Saying no without turning it into a war.',
    ),
    ArticleCategory(
      id: 'emotions',
      label: 'Emotional Intelligence',
      icon: Icons.waves_outlined,
      color: Color(0xFF06B6D4),
      blurb: 'Feeling something without being run by it.',
    ),
    ArticleCategory(
      id: 'anxiety',
      label: 'Anxiety & Overthinking',
      icon: Icons.cyclone_outlined,
      color: Color(0xFF6366F1),
      blurb: 'The loop, why it runs, and how to interrupt it.',
    ),
    ArticleCategory(
      id: 'anger-ego',
      label: 'Anger & Ego',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFEA580C),
      blurb: 'The two things that cost the most and feel the most justified.',
    ),
    ArticleCategory(
      id: 'habits',
      label: 'Habits & Discipline',
      icon: Icons.repeat_rounded,
      color: Color(0xFF10B981),
      blurb: 'Doing it on the days you do not feel like it.',
    ),
    ArticleCategory(
      id: 'focus',
      label: 'Focus & Distraction',
      icon: Icons.center_focus_strong_outlined,
      color: Color(0xFF3B82F6),
      blurb: 'Getting your attention back from the people selling it.',
    ),
    ArticleCategory(
      id: 'career-studies',
      label: 'Career & Studies',
      icon: Icons.school_outlined,
      color: Color(0xFF8B5CF6),
      blurb: 'Pressure, failure, comparison — and what actually helps.',
    ),
    ArticleCategory(
      id: 'money',
      label: 'Money & Ambition',
      icon: Icons.savings_outlined,
      color: Color(0xFF22C55E),
      blurb: 'Wanting more without letting it own you.',
    ),
    ArticleCategory(
      id: 'social-media',
      label: 'Social Media',
      icon: Icons.smartphone_outlined,
      color: Color(0xFFF43F5E),
      blurb: 'The comparison machine you carry in your pocket.',
    ),
    ArticleCategory(
      id: 'soul-consciousness',
      label: 'Soul Consciousness',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFA78BFA),
      blurb: 'You are not the role you are playing. Start there.',
    ),
    ArticleCategory(
      id: 'meditation',
      label: 'Meditation & Stillness',
      icon: Icons.spa_outlined,
      color: Color(0xFF0891B2),
      blurb: 'Practice, not theory — including the boring parts.',
    ),
    ArticleCategory(
      id: 'karma',
      label: 'Karma & Destiny',
      icon: Icons.all_inclusive_outlined,
      color: Color(0xFF64748B),
      blurb: 'Cause and effect, minus the superstition.',
    ),
    ArticleCategory(
      id: 'gita',
      label: 'Wisdom for Real Life',
      icon: Icons.menu_book_outlined,
      color: Color(0xFFD97706),
      blurb: 'Ancient answers to arguments you had this week.',
    ),
    ArticleCategory(
      id: 'impermanence',
      label: 'Time & Impermanence',
      icon: Icons.hourglass_empty_rounded,
      color: Color(0xFF94A3B8),
      blurb: 'Everything ends. That is the useful part.',
    ),
    ArticleCategory(
      id: 'forgiveness',
      label: 'Forgiveness',
      icon: Icons.volunteer_activism_outlined,
      color: Color(0xFF34D399),
      blurb: 'Putting a weight down that you were told to carry.',
    ),
    ArticleCategory(
      id: 'gratitude',
      label: 'Gratitude & Contentment',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFFACC15),
      blurb: 'Enough is a decision, not an amount.',
    ),
    ArticleCategory(
      id: 'purpose',
      label: 'Purpose & Meaning',
      icon: Icons.explore_outlined,
      color: Color(0xFF818CF8),
      blurb: 'What you are for, on days it is not obvious.',
    ),
    ArticleCategory(
      id: 'daily-practice',
      label: 'Daily Practice',
      icon: Icons.wb_twilight_rounded,
      color: Color(0xFF2DD4BF),
      blurb: 'Small routines that hold a life together.',
    ),
  ];

  /// Falls back to a neutral category rather than throwing, so a post written
  /// before categories existed still renders.
  static ArticleCategory byId(String? id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return const ArticleCategory(
      id: 'wisdom',
      label: 'Wisdom',
      icon: Icons.auto_stories_outlined,
      color: Color(0xFF7C3AED),
      blurb: 'General reflections.',
    );
  }

  static bool exists(String id) => all.any((c) => c.id == id);
}
