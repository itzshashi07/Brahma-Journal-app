import 'meditation_techniques.dart';

/// Five questions that pick a practice for you.
///
/// A library of twenty techniques is worse than three unless somebody tells you
/// which one to open. Most people who "cannot meditate" simply started with the
/// wrong method for the state they were in — a racing mind sent to sit in
/// silence concludes it has failed, when what it needed was a breath count or a
/// walk.
///
/// Deliberately short: five taps, no scoring theatre, and it can be retaken any
/// day because the honest answer changes with the day.
class QuizOption {
  final String label;

  /// Tags this answer argues for, strongest first.
  final List<MindTag> tags;

  const QuizOption(this.label, this.tags);
}

class QuizQuestion {
  final String question;
  final String? hint;
  final List<QuizOption> options;

  const QuizQuestion(this.question, this.options, {this.hint});
}

class MeditationQuiz {
  static const questions = <QuizQuestion>[
    QuizQuestion(
      'Right now, what is going on?',
      [
        QuizOption('Mind racing, cannot switch off', [MindTag.overthinking, MindTag.anxiety]),
        QuizOption('Tense, on edge, chest tight', [MindTag.anxiety, MindTag.restlessness]),
        QuizOption('Angry or irritated', [MindTag.anger, MindTag.restlessness]),
        QuizOption('Flat, low, heavy', [MindTag.sadness, MindTag.selfWorth]),
        QuizOption('Tired but cannot sleep', [MindTag.sleep, MindTag.overthinking]),
        QuizOption('Fine — I just want to practise', [MindTag.spiritual, MindTag.focus]),
      ],
      hint: 'Answer for today, not for how you usually are.',
    ),
    QuizQuestion(
      'What would you most like back?',
      [
        QuizOption('Sleep', [MindTag.sleep]),
        QuizOption('Focus for work or study', [MindTag.focus]),
        QuizOption('Calm in the chest', [MindTag.anxiety]),
        QuizOption('Patience with people', [MindTag.anger]),
        QuizOption('Feeling okay about myself', [MindTag.selfWorth, MindTag.sadness]),
        QuizOption('A sense of something larger', [MindTag.spiritual]),
      ],
    ),
    QuizQuestion(
      'How long can you honestly give it?',
      [
        QuizOption('2 minutes', [MindTag.noTime]),
        QuizOption('5 minutes', [MindTag.noTime, MindTag.beginner]),
        QuizOption('10 minutes', []),
        QuizOption('15 minutes or more', [MindTag.spiritual]),
      ],
      hint: 'Pick the number you will actually do, not the impressive one.',
    ),
    QuizQuestion(
      'When you sit still with your eyes closed…',
      [
        QuizOption('I get restless within a minute', [MindTag.restlessness, MindTag.beginner]),
        QuizOption('I fall asleep', [MindTag.sleep, MindTag.restlessness]),
        QuizOption('Thoughts get louder, not quieter', [MindTag.overthinking, MindTag.anxiety]),
        QuizOption('It is fine, I have done this before', [MindTag.spiritual, MindTag.focus]),
      ],
    ),
    QuizQuestion(
      'Anything heavy you are carrying?',
      [
        QuizOption('A loss, or someone I miss', [MindTag.grief, MindTag.sadness]),
        QuizOption('Something someone did to me', [MindTag.anger, MindTag.grief]),
        QuizOption('Pressure — exams, work, money', [MindTag.anxiety, MindTag.focus]),
        QuizOption('Nothing specific', [MindTag.beginner]),
      ],
      hint: 'This only changes what gets suggested. Nothing is stored.',
    ),
  ];

  /// Scores every technique against the chosen tags and returns the best few.
  ///
  /// The first tag on an answer counts double — the thing someone names first is
  /// usually the thing that actually brought them here.
  static List<MeditationTechnique> recommend(List<QuizOption> answers) {
    final weights = <MindTag, int>{};
    for (final a in answers) {
      for (var i = 0; i < a.tags.length; i++) {
        weights.update(a.tags[i], (v) => v + (i == 0 ? 2 : 1),
            ifAbsent: () => i == 0 ? 2 : 1);
      }
    }

    // A short session was asked for, so short practices get a nudge and long
    // ones a penalty — recommending a twelve-minute nidra to someone who has
    // two minutes is how a recommendation loses trust.
    final wantsShort = (weights[MindTag.noTime] ?? 0) > 0;

    final scored = MeditationTechniques.all.map((t) {
      var score = 0;
      for (final tag in t.bestFor) {
        score += weights[tag] ?? 0;
      }
      if (wantsShort) {
        if (t.minutes <= 5) score += 2;
        if (t.minutes >= 10) score -= 2;
      }
      return MapEntry(t, score);
    }).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (scored.isEmpty) {
      return [
        MeditationTechniques.byId('two-minute-reset'),
        MeditationTechniques.byId('coherent'),
        MeditationTechniques.byId('soul-consciousness'),
      ];
    }
    return scored.take(3).map((e) => e.key).toList();
  }

  /// One honest line explaining the top suggestion, built from the answers.
  static String reasonFor(MeditationTechnique t) {
    final tags = t.bestFor.take(2).map((e) => mindTagLabels[e]).join(' and ');
    return 'Suggested because it is built for ${tags.toLowerCase()}.';
  }
}
