/// Tap-to-select options for the daily journal.
///
/// Most days people do not want to compose paragraphs — they want to record
/// what happened in twenty seconds. Every field here is optional and selectable;
/// the free-text boxes remain for the days someone has more to say.
///
/// **Deliberately open to every faith and none.** The journal previously asked
/// for a "Shiv Baba line", which only makes sense inside one tradition. The
/// wording is now about practice and reflection, so a Hindu, Muslim, Christian,
/// Sikh, Buddhist or entirely secular member can all use the same page honestly.
class JournalOptions {
  /// How the day felt overall.
  static const energyLevels = [
    ('drained', 'Drained', '🪫'),
    ('low', 'Low', '🌥️'),
    ('steady', 'Steady', '🌤️'),
    ('good', 'Good', '☀️'),
    ('radiant', 'Radiant', '✨'),
  ];

  /// Practices, named so they belong to no single tradition.
  static const practices = [
    ('meditation', 'Meditation', '🧘'),
    ('prayer', 'Prayer', '🙏'),
    ('scripture', 'Scripture / Reading', '📖'),
    ('gratitude', 'Gratitude', '💛'),
    ('service', 'Service to others', '🤲'),
    ('silence', 'Silence', '🤫'),
    ('nature', 'Time in nature', '🌿'),
    ('chanting', 'Chanting / Music', '🎵'),
  ];

  /// What shaped the day.
  static const influences = [
    ('family', 'Family', '👨‍👩‍👧'),
    ('work', 'Work', '💼'),
    ('health', 'Health', '🩺'),
    ('friends', 'Friends', '🫂'),
    ('money', 'Money', '💰'),
    ('study', 'Study', '📚'),
    ('solitude', 'Solitude', '🌙'),
    ('travel', 'Travel', '✈️'),
  ];

  /// Habits worth noticing, phrased without judgement.
  static const habits = [
    ('early_rise', 'Woke early', '🌅'),
    ('exercise', 'Moved my body', '🏃'),
    ('ate_well', 'Ate well', '🥗'),
    ('slept_well', 'Slept well', '😴'),
    ('screen_limit', 'Limited screens', '📵'),
    ('helped', 'Helped someone', '🤝'),
    ('learned', 'Learned something', '💡'),
    ('rested', 'Rested properly', '🛋️'),
  ];

  /// What pulled at you today — chosen instead of typed, because naming a
  /// difficulty from a list is far easier than writing about it.
  static const challenges = [
    ('anger', 'Anger', '🔥'),
    ('worry', 'Worry', '😰'),
    ('comparison', 'Comparison', '👀'),
    ('procrastination', 'Putting things off', '⏳'),
    ('overthinking', 'Overthinking', '🌀'),
    ('loneliness', 'Loneliness', '🕯️'),
    ('impatience', 'Impatience', '⏱️'),
    ('none', 'Nothing much', '🕊️'),
  ];

  static String labelFor(List<(String, String, String)> list, String id) {
    for (final o in list) {
      if (o.$1 == id) return o.$2;
    }
    return id;
  }
}

/// Lines shown when the journal opens, to give a reason to begin.
///
/// Chosen by day so the same person sees the same one all day — a prompt that
/// changes on every rebuild reads as decoration rather than as something said
/// to you.
class JournalPrompts {
  static const lines = [
    'The day you least feel like writing is usually the one worth recording.',
    'You are not writing for anyone. Say the true thing.',
    'Five honest sentences beat five polished paragraphs.',
    'What went well today? Start there — the mind will skip it otherwise.',
    'Nobody reads this but you. Nothing here has to be impressive.',
    'A streak is not built by good days. It is built by showing up on ordinary ones.',
    'Name the feeling and it loosens its grip a little.',
    'What would you tell a friend who had lived your day?',
    'The version of you reading this in a year will be glad you wrote it.',
    'Progress is invisible day to day and obvious month to month.',
    'You survived every day you thought you could not. Today is on that list.',
    'Write the thing you would rather not write. That is where it is.',
    'Small and true beats long and performed.',
    'What are you carrying that is not yours to carry?',
    'One page today is one page more than yesterday.',
  ];

  static String forToday() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return lines[dayOfYear % lines.length];
  }
}
