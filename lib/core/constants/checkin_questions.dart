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
///
/// Every question now ships with tappable answers. An empty text box at 11pm is
/// the single biggest reason a check-in goes unanswered — most people have an
/// answer in mind but no appetite for typing it. Tapping "Tiring, but fine" is
/// a real answer, takes one second, and still lands in the same journal entry.
/// The keyboard and the microphone stay available underneath for the evenings
/// somebody actually wants to say more.
library;

/// How a question expects to be answered.
enum CheckInInput {
  /// Tap one of the offered answers. Writing more is optional.
  pickOne,

  /// Tap as many as apply. Writing more is optional.
  pickMany,

  /// No canned answers fit — this one wants words, spoken or typed.
  speak,
}

class CheckInQuestion {
  final String id;
  final String prompt;
  final String hint;
  final String emoji;

  /// Shown under the prompt to make skipping feel permitted rather than lazy.
  final String skipLabel;

  /// How the question is answered. [CheckInInput.speak] leads with the
  /// microphone; the others lead with the chips and keep writing as a follow-up.
  final CheckInInput input;

  /// Tappable answers. Empty for [CheckInInput.speak].
  final List<String> options;

  /// Placeholder for the free-text box that sits under the chips.
  final String writeHint;

  const CheckInQuestion({
    required this.id,
    required this.prompt,
    required this.hint,
    required this.emoji,
    this.skipLabel = 'Skip this one',
    this.input = CheckInInput.pickOne,
    this.options = const [],
    this.writeHint = 'Add your own words…',
  });

  bool get isSpoken => input == CheckInInput.speak;
  bool get isMultiSelect => input == CheckInInput.pickMany;
}

class CheckInQuestions {
  /// Asked every day, in this order.
  ///
  /// Four questions, and the first three can be finished entirely by tapping.
  /// The one that asks for words is placed last, once the conversation has
  /// warmed up — leading with a blank box is what makes people close the sheet.
  static const core = <CheckInQuestion>[
    CheckInQuestion(
      id: 'day',
      prompt: 'How was your day, really?',
      hint: 'Not the version you tell people. The real one.',
      emoji: '🌤️',
      options: [
        'Good, genuinely',
        'Quiet and ordinary',
        'Tiring, but fine',
        'Stressful',
        'Rough, honestly',
        'All over the place',
      ],
      writeHint: 'Want to say what made it that way?',
    ),
    CheckInQuestion(
      id: 'body',
      prompt: 'How has your body been today?',
      hint: 'Sleep, energy, aches, appetite — anything worth noting.',
      emoji: '🌱',
      input: CheckInInput.pickMany,
      skipLabel: 'Nothing to note',
      options: [
        'Slept well',
        'Barely slept',
        'Full of energy',
        'Drained',
        'Headache',
        'Body ache',
        'Ate properly',
        'Skipped meals',
        'Moved / exercised',
      ],
      writeHint: 'Anything else your body is telling you?',
    ),
    CheckInQuestion(
      id: 'family',
      prompt: 'How is everyone at home?',
      hint: 'Family, the people you live with, whoever counts.',
      emoji: '🏡',
      skipLabel: 'Skip',
      options: [
        'All good',
        'Same as always',
        'Someone is unwell',
        'There was an argument',
        'Feeling distant from them',
        'Had a lovely moment together',
        'I live alone',
      ],
      writeHint: 'Tell me about it, if you want.',
    ),
    CheckInQuestion(
      id: 'exciting',
      prompt: 'Anything you want to tell someone about?',
      hint: 'Good news that has nowhere to go yet. Speak it or type it.',
      emoji: '✨',
      skipLabel: 'Nothing today',
      input: CheckInInput.speak,
      writeHint: 'Tap the mic and just say it, or type here…',
    ),
  ];

  /// One of these is added each day, chosen by date so it is stable all day.
  static const rotating = <CheckInQuestion>[
    CheckInQuestion(
      id: 'plan',
      prompt: 'What is the plan for tomorrow?',
      hint: 'One thing is enough. It does not have to be big.',
      emoji: '🧭',
      skipLabel: 'No plans yet',
      input: CheckInInput.pickMany,
      options: [
        'Work / study',
        'Rest properly',
        'Meet someone',
        'Finish something pending',
        'Exercise',
        'Meditate',
        'Sort out money',
        'Take it as it comes',
      ],
      writeHint: 'Name the one thing that matters most.',
    ),
    CheckInQuestion(
      id: 'new_people',
      prompt: 'Did you meet anyone new lately?',
      hint: 'A conversation, a name, someone who surprised you.',
      emoji: '🤝',
      skipLabel: 'Not this week',
      options: [
        'Yes, someone new',
        'Reconnected with someone old',
        'Only the usual people',
        'Barely spoke to anyone',
      ],
      writeHint: 'Who was it, and how did it go?',
    ),
    CheckInQuestion(
      id: 'skill',
      prompt: 'Learned anything new?',
      hint: 'A skill, a fact, something you finally understood.',
      emoji: '🎓',
      skipLabel: 'Not yet',
      options: [
        'Something about my work',
        'Something about myself',
        'A practical skill',
        'Read or watched something good',
        'Not really today',
      ],
      writeHint: 'What was it?',
    ),
    CheckInQuestion(
      id: 'adventure',
      prompt: 'Been anywhere or done anything different?',
      hint: 'A new place, a small adventure, a break in routine.',
      emoji: '🗺️',
      skipLabel: 'Same as usual',
      options: [
        'Went somewhere new',
        'Broke my routine a little',
        'Spent time outdoors',
        'Stayed in all day',
        'Same as every day',
      ],
      writeHint: 'Where did you go?',
    ),
    CheckInQuestion(
      id: 'proud',
      prompt: 'What are you quietly proud of?',
      hint: 'Something nobody praised you for. It still counts.',
      emoji: '🌟',
      skipLabel: 'Skip',
      options: [
        'I showed up anyway',
        'I kept my temper',
        'I finished something hard',
        'I asked for help',
        'I said no to something',
        'I was there for someone',
      ],
      writeHint: 'Say it in your own words.',
    ),
    CheckInQuestion(
      id: 'heavy',
      prompt: 'Anything sitting heavy on you?',
      hint: 'Naming it here is enough. You do not have to solve it.',
      emoji: '🫂',
      skipLabel: 'Nothing right now',
      input: CheckInInput.pickMany,
      options: [
        'Money',
        'Work or studies',
        'Family',
        'A relationship',
        'Health',
        'The future',
        'Loneliness',
        'Something I cannot name yet',
      ],
      writeHint: 'You can put the rest of it down here.',
    ),
    CheckInQuestion(
      id: 'grateful',
      prompt: 'One thing you are grateful for?',
      hint: 'Small and specific lands better than big and general.',
      emoji: '💛',
      skipLabel: 'Skip',
      options: [
        'A person in my life',
        'My health',
        'A small comfort today',
        'Work I have',
        'A roof and a meal',
        'Making it through the day',
      ],
      writeHint: 'What exactly? Small is fine.',
    ),
    CheckInQuestion(
      id: 'kindness',
      prompt: 'Were you kind to someone — or to yourself?',
      hint: 'Both count. The second one is usually harder.',
      emoji: '🤲',
      skipLabel: 'Skip',
      input: CheckInInput.pickMany,
      options: [
        'Helped someone',
        'Listened to someone',
        'Let something go',
        'Rested without guilt',
        'Was hard on myself',
        'Neither, really',
      ],
      writeHint: 'What happened?',
    ),
    CheckInQuestion(
      id: 'letting_go',
      prompt: 'Anything you are ready to put down?',
      hint: 'A worry, a grudge, an expectation of yourself.',
      emoji: '🍃',
      skipLabel: 'Not yet',
      options: [
        'A worry about tomorrow',
        'Something someone said',
        'An expectation of myself',
        'A regret',
        'Anger at someone',
        'Not ready yet',
      ],
      writeHint: 'Name it, and leave it here.',
    ),
    CheckInQuestion(
      id: 'someone',
      prompt: 'Who has been on your mind?',
      hint: 'You do not have to say why. Speak it if it is easier.',
      emoji: '💭',
      skipLabel: 'Skip',
      input: CheckInInput.speak,
      writeHint: 'Tap the mic and say their name, or type it…',
    ),
    CheckInQuestion(
      id: 'unsaid',
      prompt: 'Anything you wanted to say today but did not?',
      hint: 'It can live here instead. Nobody else reads this.',
      emoji: '🤐',
      skipLabel: 'Nothing left unsaid',
      input: CheckInInput.speak,
      writeHint: 'Say it out loud here — the mic is listening…',
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

  /// Shown on the closing card, so the check-in ends with a sentence rather
  /// than a spinner.
  static String farewellFor(int mood) => switch (mood) {
        1 => 'You showed up on a hard day. That is the whole practice.',
        2 => 'Written down and kept. Tomorrow gets to be different.',
        3 => 'Noted, exactly as it was. See you tomorrow.',
        4 => 'Saved. Good days are worth the same ink as hard ones.',
        _ => 'Saved. Come back and read this one when you need it.',
      };
}
