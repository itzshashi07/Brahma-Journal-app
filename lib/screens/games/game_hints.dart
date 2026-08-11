import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// How to actually play each game, and what to do about a wrong answer.
///
/// The games explain their rules and then say nothing else, so someone who
/// keeps losing has no way to work out whether they are unlucky or approaching
/// it wrong. That is the moment people quit — not because the game is hard, but
/// because it is opaque. Every game now carries a short strategy sheet behind a
/// lightbulb, and the ones where a wrong move can strand you carry a real
/// in-game hint as well.
///
/// The tips are deliberately concrete ("finish the top row and never break it")
/// rather than encouraging ("keep trying!"). Encouragement does not change
/// anybody's next move.
class GameHints {
  /// Two to four tips per game, ordered most-useful-first.
  static const _tips = <String, List<String>>{
    'slide_nine': [
      'Solve the top row first — 1, 2, 3 — then never move those three again.',
      'Then the left column. What is left is a 2×2 corner, which is easy.',
      'Rushing costs moves. The score is moves, not seconds.',
      'Stuck in a loop? Move the blank in a small circle to break the pattern.',
    ],
    'mantra_scramble': [
      'Read the meaning line first — it usually names the word outright.',
      'Look for the vowels. Most of these words alternate consonant–vowel.',
      'Common endings: -A, -I, -AM. Try placing the last letter first.',
      'Undo is free. A wrong full word costs you the whole attempt.',
    ],
    'breath_rhythm': [
      'Do not watch the number. Follow the circle and let the count blur.',
      'If you are always early, you are anticipating. Breathe out longer.',
      'Sit upright. A slouched chest makes an even rhythm almost impossible.',
    ],
    'n_back': [
      'Say each item out loud in your head. Sub-vocalising doubles recall.',
      'Do not try to hold a list. Hold only the last two and let the rest go.',
      'When you lose the thread, guess "no" and re-anchor on the next one.',
    ],
    'mirror_tap': [
      'Watch the shape, not the position — position is the thing that lies.',
      'Blink deliberately between rounds. Fixed staring makes you miss changes.',
    ],
    'pair_bloom': [
      'Turn cards in a fixed order — left to right, top to bottom.',
      'Name each card as you flip it. Naming stores it; looking does not.',
      'Early on, flip to learn. Matching comes almost free after that.',
    ],
    'spot_shift': [
      'Look at the whole grid softly rather than scanning it square by square.',
      'The change is usually at the edge of where you were last looking.',
    ],
    'dot_count': [
      'Do not count. Group in threes and fours and add the groups.',
      'Trust the first number that comes to mind — second-guessing is slower and no more accurate.',
    ],
    'focus_grid': [
      'Work in reading order and never jump back. Jumping is where time goes.',
      'Rest your eyes on the centre between numbers instead of hunting.',
    ],
    'ink_test': [
      'Say the colour out loud before you tap. It overrides the reading reflex.',
      'Half-close your eyes so the word blurs and the colour does not.',
      'Getting slower means you are reading again. Slow down deliberately for one round.',
    ],
    'memory_bloom': [
      'Turn the sequence into a shape or a little tune, not a list of taps.',
      'Watch the whole pattern before it ends — do not start rehearsing early.',
    ],
    'reaction_bell': [
      'Rest your thumb on the screen. Travel time is most of a bad score.',
      'Do not tense up waiting. Tense muscles react more slowly, not faster.',
      'Anticipating gives you a false start, which counts against you.',
    ],
    'rule_switch': [
      'Read the rule out loud each time it changes. Silent reading skips it.',
      'After a switch, take the first one slowly on purpose. Speed comes back.',
    ],
    'quick_math': [
      'Round, then correct: 47 + 38 is 50 + 38 − 3.',
      'For ×9, multiply by 10 and subtract the number.',
      'If it is close, take the answer that is obviously wrong out first.',
    ],
    'odd_colour': [
      'Let your eyes go soft. The odd tile pops out of peripheral vision.',
      'Do not compare tiles in pairs — scan the whole block at once.',
    ],
  };

  static List<String> forGame(String gameId) => _tips[gameId] ?? const [];

  static bool has(String gameId) => _tips.containsKey(gameId);

  /// Shown right after a wrong answer, in the game itself.
  ///
  /// One short line, because a paragraph at the moment of failure does not get
  /// read. Falls back to the game's first strategy tip.
  static String nudge(String gameId) => switch (gameId) {
        'mantra_scramble' =>
          'Not quite. Read the meaning line again — it names the word.',
        'ink_test' => 'You read the word. Tap the colour it is printed in.',
        'rule_switch' => 'The rule changed. Read it before the next one.',
        'n_back' => 'Lost the thread? Hold only the last two and start again.',
        'quick_math' => 'Round first, then correct — it is faster than exact.',
        'reaction_bell' => 'Too early. Wait for the bell, do not predict it.',
        _ => _tips[gameId]?.first ?? 'Take the next one slowly.',
      };
}

/// The lightbulb in a game's header, and the sheet behind it.
class GameHintButton extends StatelessWidget {
  final String gameId;
  final String title;

  const GameHintButton({super.key, required this.gameId, required this.title});

  @override
  Widget build(BuildContext context) {
    if (!GameHints.has(gameId)) return const SizedBox(width: 44);

    return IconButton(
      tooltip: 'How to play this well',
      icon: const Icon(Icons.lightbulb_outline_rounded,
          size: 21, color: AppTheme.accentLight),
      onPressed: () => showHints(context, gameId, title),
    );
  }
}

/// Opens the strategy sheet. Also reachable from a result screen, so a losing
/// run ends with something actionable rather than just a number.
Future<void> showHints(BuildContext context, String gameId, String title) {
  final tips = GameHints.forGame(gameId);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppTheme.space3),
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded,
                    size: 20, color: AppTheme.accentLight),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    'How to play $title well',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            for (final (i, tip) in tips.indexed) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentLight),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          height: 1.55,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space4),
            ],
            const Text(
              'None of this is required. Losing at a game you played to calm '
              'down is not a problem to solve.',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A one-line correction shown inside a game after a wrong answer.
class GameNudge extends StatelessWidget {
  final String text;

  const GameNudge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space3, vertical: AppTheme.space2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              size: 15, color: AppTheme.accentLight),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
