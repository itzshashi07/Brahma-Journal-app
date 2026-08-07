/// The daily check-in.
///
/// Written as a conversation, not a form. Someone opening this at the end of a
/// hard day should feel asked after, not audited — so every question is
/// optional, the tone is a friend's rather than a clinician's, and skipping is
/// offered as plainly as answering.
///
/// The rotating question exists so the check-in does not become wallpaper. The
/// same five prompts every day for a month stop being read; one that changes
/// keeps the habit feeling like someone is actually there.
class CheckInQuestion {
  final String id;
  final String prompt;
  final String hint;
  final String emoji;

  /// Shown under the prompt to make skipping feel permitted rather than lazy.
  final String skipLabel;

  const CheckInQuestion({
    required this.id,
    required this.prompt,
    required this.hint,
    required this.emoji,
    this.skipLabel = 'Skip this one',
  });
}

class CheckInQuestions {
  /// Asked every day, in this order.
  static const core = <CheckInQuestion>[
    CheckInQuestion(
      id: 'day',
      prompt: 'How was your day, really?',
      hint: 'Not the version you tell people. The real one.',
      emoji: '🌤️',
    ),
    CheckInQuestion(
      id: 'exciting',
      prompt: 'Anything you want to tell someone about?',
      hint: 'Good news that has nowhere to go yet.',
      emoji: '✨',
      skipLabel: 'Nothing today',
    ),
    CheckInQuestion(
      id: 'family',
      prompt: 'How is everyone at home?',
      hint: 'Family, the people you live with, whoever counts.',
      emoji: '🏡',
      skipLabel: 'Skip',
    ),
    CheckInQuestion(
      id: 'plan',
      prompt: 'What is the plan for tomorrow?',
      hint: 'One thing is enough. It does not have to be big.',
      emoji: '🧭',
      skipLabel: 'No plans yet',
    ),
  ];

  /// One of these is added each day, chosen by date so it is stable all day.
  static const rotating = <CheckInQuestion>[
    CheckInQuestion(
      id: 'new_people',
      prompt: 'Did you meet anyone new lately?',
      hint: 'A conversation, a name, someone who surprised you.',
      emoji: '🤝',
      skipLabel: 'Not this week',
    ),
    CheckInQuestion(
      id: 'skill',
      prompt: 'Learned anything new?',
      hint: 'A skill, a fact, something you finally understood.',
      emoji: '🎓',
      skipLabel: 'Not yet',
    ),
    CheckInQuestion(
      id: 'adventure',
      prompt: 'Been anywhere or done anything different?',
      hint: 'A new place, a small adventure, a break in routine.',
      emoji: '🗺️',
      skipLabel: 'Same as usual',
    ),
    CheckInQuestion(
      id: 'proud',
      prompt: 'What are you quietly proud of?',
      hint: 'Something nobody praised you for. It still counts.',
      emoji: '🌟',
      skipLabel: 'Skip',
    ),
    CheckInQuestion(
      id: 'heavy',
      prompt: 'Anything sitting heavy on you?',
      hint: 'Naming it here is enough. You do not have to solve it.',
      emoji: '🫂',
      skipLabel: 'Nothing right now',
    ),
    CheckInQuestion(
      id: 'grateful',
      prompt: 'One thing you are grateful for?',
      hint: 'Small and specific lands better than big and general.',
      emoji: '💛',
      skipLabel: 'Skip',
    ),
    CheckInQuestion(
      id: 'kindness',
      prompt: 'Were you kind to someone — or to yourself?',
      hint: 'Both count. The second one is usually harder.',
      emoji: '🤲',
      skipLabel: 'Skip',
    ),
    CheckInQuestion(
      id: 'body',
      prompt: 'How has your body been treating you?',
      hint: 'Sleep, energy, aches, appetite — anything worth noting.',
      emoji: '🌱',
      skipLabel: 'Fine',
    ),
    CheckInQuestion(
      id: 'letting_go',
      prompt: 'Anything you are ready to put down?',
      hint: 'A worry, a grudge, an expectation of yourself.',
      emoji: '🍃',
      skipLabel: 'Not yet',
    ),
    CheckInQuestion(
      id: 'someone',
      prompt: 'Who has been on your mind?',
      hint: 'You do not have to say why.',
      emoji: '💭',
      skipLabel: 'Skip',
    ),
  ];

  /// The full set for today: the four core questions plus one rotating one,
  /// stable for the whole day so a half-finished check-in does not change
  /// underneath the user.
  static List<CheckInQuestion> forToday([DateTime? now]) {
    final today = now ?? DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    return [...core, rotating[dayOfYear % rotating.length]];
  }
}

/// The mood scale, matched to the values the journal already stores (1–5) so
/// the check-in and the journal never disagree about how a day felt.
class CheckInMoods {
  static const options = <(int, String, String, String)>[
    (1, 'Struggling', '😔', 'Today was heavy'),
    (2, 'Low', '😕', 'Not my best day'),
    (3, 'Okay', '😐', 'Somewhere in the middle'),
    (4, 'Good', '🙂', 'A decent day'),
    (5, 'Wonderful', '😊', 'Today was a gift'),
  ];

  static String labelFor(int mood) {
    for (final m in options) {
      if (m.$1 == mood) return m.$2;
    }
    return 'Okay';
  }

  /// Shown after the mood is chosen — the app answering rather than only
  /// collecting. A low mood should never be met with silence.
  static String responseFor(int mood) => switch (mood) {
        1 =>
          'Thank you for saying so. Heavy days are worth recording too — they are part of the picture, and they pass.',
        2 => 'That is alright. Not every day has to be a good one.',
        3 => 'An ordinary day is still a day you showed up for.',
        4 => 'Good to hear. Worth noticing when things go well.',
        _ => 'That is lovely. Hold on to this one.',
      };
}
