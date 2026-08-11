import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'attention_games.dart';
import 'memory_games.dart';
import 'puzzle_games.dart';
import 'reflex_games.dart';

/// One list of games, read by both the Game Zone and the meditation section.
///
/// Two screens with two hand-written lists is two places to forget a game.
/// Everything that shows games reads this.

enum GameLane { focus, memory, logic, calm }

extension GameLaneLabel on GameLane {
  String get label => switch (this) {
        GameLane.focus => 'Focus',
        GameLane.memory => 'Memory',
        GameLane.logic => 'Logic',
        GameLane.calm => 'Calm',
      };

  Color get color => switch (this) {
        GameLane.focus => const Color(0xFF3B82F6),
        GameLane.memory => const Color(0xFF10B981),
        GameLane.logic => const Color(0xFFF59E0B),
        GameLane.calm => const Color(0xFF7C3AED),
      };
}

class GameEntry {
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final List<Color> colors;
  final GameLane lane;

  /// 1 easy · 2 moderate · 3 hard. Shown as pips, so someone opening the list
  /// tired can pick something that will not defeat them.
  final int difficulty;
  final String duration;

  /// Which direction wins. Seconds and moves rank ascending; points and levels
  /// rank descending. The leaderboard cannot guess this, and guessing wrong
  /// puts the worst player on top.
  final bool lowerIsBetter;

  /// What the number on the board actually is — see [formatScore].
  final String unit;
  final WidgetBuilder builder;

  const GameEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.colors,
    required this.lane,
    required this.difficulty,
    required this.duration,
    required this.lowerIsBetter,
    required this.unit,
    required this.builder,
  });

  /// The number as it should read on a board or a stat card.
  ///
  /// A bare "13" means nothing when one game counts moves and the next counts
  /// milliseconds, so the unit travels with the score everywhere it is shown.
  String formatScore(int score) => switch (unit) {
        'seconds' => '${score}s',
        'ms' => '${score}ms',
        'moves' => '$score moves',
        'points' => '$score pts',
        'level' => 'level $score',
        'round' => 'round $score',
        'words' => '$score words',
        'length' => 'length $score',
        _ => '$score',
      };
}

GameEntry? gameById(String id) {
  for (final g in kGames) {
    if (g.id == id) return g;
  }
  return null;
}

/// Seconds as a board figure: "9m 05s", or "1h 12m" once it gets long.
String formatTrainingTime(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ${(seconds % 60).toString().padLeft(2, '0')}s';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}

const kGames = <GameEntry>[
  // ── focus ──
  GameEntry(
    id: 'focus_grid',
    title: 'Focus Grid',
    subtitle: 'Find 1 to 25 in order, as fast as you can',
    detail: 'A Schulte table — used to widen the span of attention. Keep your '
        'eyes near the middle and let them find the numbers instead of hunting '
        'one by one.',
    icon: Icons.grid_view_rounded,
    colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    lane: GameLane.focus,
    difficulty: 1,
    duration: '1 min',
    lowerIsBetter: true,
    unit: 'seconds',
    builder: _focusGrid,
  ),
  GameEntry(
    id: 'ink_test',
    title: 'Ink Test',
    subtitle: 'Tap the colour of the ink, not the word',
    detail: 'The Stroop test. Reading is automatic, so ignoring the word takes '
        'deliberate control — exactly the muscle used when you decide not to '
        'react to something. Now on a clock that tightens as you go.',
    icon: Icons.palette_outlined,
    colors: [Color(0xFFEC4899), Color(0xFF831843)],
    lane: GameLane.focus,
    difficulty: 2,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'points',
    builder: _inkTest,
  ),
  GameEntry(
    id: 'reaction_bell',
    title: 'Reaction Bell',
    subtitle: 'Wait for gold. Tap the instant it turns.',
    detail: 'Five rounds, averaged. The delay is deliberately unpredictable, so '
        'the only way to be fast is to actually be present — anticipating is '
        'punished harder than being slow.',
    icon: Icons.bolt_rounded,
    colors: [Color(0xFFF59E0B), Color(0xFF92400E)],
    lane: GameLane.focus,
    difficulty: 1,
    duration: '1 min',
    lowerIsBetter: true,
    unit: 'ms',
    builder: _reactionBell,
  ),
  GameEntry(
    id: 'rule_switch',
    title: 'Rule Switch',
    subtitle: 'Bigger number or bigger text? The rule keeps changing.',
    detail: 'A 4 printed large beside a 9 printed small argues with itself, and '
        'the rule flips without warning. Switching rules costs real time — '
        'noticing that cost is the training.',
    icon: Icons.swap_horiz_rounded,
    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    lane: GameLane.focus,
    difficulty: 3,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'points',
    builder: _ruleSwitch,
  ),
  GameEntry(
    id: 'odd_colour',
    title: 'Odd Colour Out',
    subtitle: 'One tile is a slightly different shade',
    detail: 'The difference shrinks every level and the grid grows to thirty-six '
        'tiles. Softening your gaze finds it faster than staring does, which is '
        'a strange and useful thing to learn about looking.',
    icon: Icons.blur_circular_rounded,
    colors: [Color(0xFF06B6D4), Color(0xFF155E75)],
    lane: GameLane.focus,
    difficulty: 2,
    duration: '45 sec',
    lowerIsBetter: false,
    unit: 'level',
    builder: _oddColour,
  ),
  GameEntry(
    id: 'dot_count',
    title: 'Dot Count',
    subtitle: 'Dots flash for half a second. How many?',
    detail: 'Up to four, the answer arrives without counting. Past that the mind '
        'starts counting and runs out of time — so you have to let the estimate '
        'come instead of building it.',
    icon: Icons.scatter_plot_rounded,
    colors: [Color(0xFFFBBF24), Color(0xFF78350F)],
    lane: GameLane.focus,
    difficulty: 2,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'round',
    builder: _dotCount,
  ),

  // ── memory ──
  GameEntry(
    id: 'memory_bloom',
    title: 'Memory Bloom',
    subtitle: 'Watch the petals, repeat the pattern',
    detail: 'Working memory, one step longer and a little faster each round. '
        'Ends the moment you slip — which is the interesting part, because you '
        'will feel exactly when attention wandered.',
    icon: Icons.blur_on_rounded,
    colors: [Color(0xFF10B981), Color(0xFF065F46)],
    lane: GameLane.memory,
    difficulty: 1,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'length',
    builder: _memoryBloom,
  ),
  GameEntry(
    id: 'mirror_tap',
    title: 'Mirror Tap',
    subtitle: 'Repeat the pattern — but tap the opposite tile',
    detail: 'Remembering the sequence is the easy half. Every tap then has to be '
        'flipped before your hand is allowed to move, and the hand keeps wanting '
        'to go where the light was.',
    icon: Icons.flip_rounded,
    colors: [Color(0xFF14B8A6), Color(0xFF115E59)],
    lane: GameLane.memory,
    difficulty: 3,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'length',
    builder: _mirrorTap,
  ),
  GameEntry(
    id: 'n_back',
    title: '2-Back',
    subtitle: 'Was this square here two steps ago?',
    detail: 'The hardest game here, honestly so. Holding a moving two-item window '
        'is uncomfortable, and that discomfort is the whole exercise. Wrong calls '
        'cost more than saying nothing.',
    icon: Icons.replay_rounded,
    colors: [Color(0xFF6366F1), Color(0xFF312E81)],
    lane: GameLane.memory,
    difficulty: 3,
    duration: '1 min',
    lowerIsBetter: false,
    unit: 'points',
    builder: _nBack,
  ),
  GameEntry(
    id: 'pair_bloom',
    title: 'Pair Bloom',
    subtitle: 'Sixteen tiles, eight pairs, fewest moves',
    detail: 'The gentlest game in the list, and the one most people play twice. '
        'Under fourteen moves means you were genuinely tracking rather than '
        'turning tiles over hopefully.',
    icon: Icons.style_rounded,
    colors: [Color(0xFFA855F7), Color(0xFF581C87)],
    lane: GameLane.memory,
    difficulty: 1,
    duration: '2 min',
    lowerIsBetter: true,
    unit: 'moves',
    builder: _pairBloom,
  ),
  GameEntry(
    id: 'spot_shift',
    title: 'Spot the Shift',
    subtitle: 'The grid blinks. One tile comes back different.',
    detail: 'Change blindness: the blank frame wipes out the flicker your eye '
        'normally uses to catch movement, so the change has to be found by '
        'comparison. Holding the whole grid loosely beats scanning it.',
    icon: Icons.compare_rounded,
    colors: [Color(0xFF0EA5E9), Color(0xFF075985)],
    lane: GameLane.memory,
    difficulty: 2,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'round',
    builder: _spotShift,
  ),

  // ── logic ──
  GameEntry(
    id: 'quick_math',
    title: 'Quick Math',
    subtitle: 'Arithmetic against a clock that keeps tightening',
    detail: 'The sums get harder and the clock gets shorter at the same time. '
        'Past twenty it stops being arithmetic and becomes nerve — which is the '
        'part worth practising.',
    icon: Icons.calculate_outlined,
    colors: [Color(0xFFEF4444), Color(0xFF7F1D1D)],
    lane: GameLane.logic,
    difficulty: 2,
    duration: '2 min',
    lowerIsBetter: false,
    unit: 'points',
    builder: _quickMath,
  ),
  GameEntry(
    id: 'slide_nine',
    title: 'Slide Nine',
    subtitle: 'The eight-tile sliding puzzle',
    detail: 'No clock, no lives, no pressure — just a board that will not be '
        'rushed. Every board dealt here is solvable, and most go in under forty '
        'moves if you finish the top row first and never break it again.',
    icon: Icons.apps_rounded,
    colors: [Color(0xFF64748B), Color(0xFF1E293B)],
    lane: GameLane.logic,
    difficulty: 2,
    duration: '3 min',
    lowerIsBetter: true,
    unit: 'moves',
    builder: _slideNine,
  ),
  GameEntry(
    id: 'mantra_scramble',
    title: 'Mantra Scramble',
    subtitle: 'Rebuild the word from its letters',
    detail: 'Twenty Sanskrit words with their meanings, ninety seconds on the '
        'clock. Each one you unscramble you also read the meaning of, which is '
        'the half that stays with you.',
    icon: Icons.abc_rounded,
    colors: [Color(0xFFF97316), Color(0xFF7C2D12)],
    lane: GameLane.logic,
    difficulty: 2,
    duration: '90 sec',
    lowerIsBetter: false,
    unit: 'words',
    builder: _mantraScramble,
  ),

  // ── calm ──
  GameEntry(
    id: 'breath_rhythm',
    title: 'Breath Rhythm',
    subtitle: 'Tap exactly when the circle fills the ring',
    detail: 'The one game here that gets easier when you stop trying. Chasing '
        'the ring with your eyes always lands late; breathing with it does not. '
        'The closest thing in this list to actual practice.',
    icon: Icons.self_improvement_rounded,
    colors: [Color(0xFF7C3AED), Color(0xFF3B0764)],
    lane: GameLane.calm,
    difficulty: 1,
    duration: '1 min',
    lowerIsBetter: true,
    unit: 'ms',
    builder: _breathRhythm,
  ),
];

// Torn-off builders, because a const list cannot hold closures.
Widget _focusGrid(BuildContext _) => const FocusGridGame();
Widget _inkTest(BuildContext _) => const InkTestGame();
Widget _memoryBloom(BuildContext _) => const MemoryBloomGame();
Widget _reactionBell(BuildContext _) => const ReactionBellGame();
Widget _ruleSwitch(BuildContext _) => const RuleSwitchGame();
Widget _quickMath(BuildContext _) => const QuickMathGame();
Widget _oddColour(BuildContext _) => const OddColourGame();
Widget _nBack(BuildContext _) => const NBackGame();
Widget _mirrorTap(BuildContext _) => const MirrorTapGame();
Widget _pairBloom(BuildContext _) => const PairBloomGame();
Widget _spotShift(BuildContext _) => const SpotShiftGame();
Widget _dotCount(BuildContext _) => const DotCountGame();
Widget _slideNine(BuildContext _) => const SlideNineGame();
Widget _mantraScramble(BuildContext _) => const MantraScrambleGame();
Widget _breathRhythm(BuildContext _) => const BreathRhythmGame();

void openGame(BuildContext context, GameEntry game) {
  Navigator.of(context).push(MaterialPageRoute(builder: game.builder));
}

/// The card used in every list of games.
class GameCard extends StatelessWidget {
  final GameEntry game;
  final bool compact;

  const GameCard({super.key, required this.game, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: GlassCard(
        onTap: () => openGame(context, game),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: game.colors),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(game.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.title,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      Text(game.subtitle,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            Row(
              children: [
                _Pill(text: game.lane.label, color: game.lane.color),
                const SizedBox(width: AppTheme.space2),
                _Pill(text: game.duration, color: AppTheme.textMuted),
                const Spacer(),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < game.difficulty
                            ? AppTheme.accent
                            : AppTheme.border,
                      ),
                    ),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: AppTheme.space3),
              Text(game.detail,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      height: 1.55,
                      color: AppTheme.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

/// The honest note that sits under every list of games.
class GameZoneFootnote extends StatelessWidget {
  const GameZoneFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
      ),
      child: const Text(
        'These minutes are counted separately from meditation. A game trains '
        'attention; sitting still trains something else, and mixing the two '
        'numbers would only flatter you.',
        style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            height: 1.55,
            color: AppTheme.textMuted),
      ),
    );
  }
}
