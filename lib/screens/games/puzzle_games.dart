import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'game_core.dart';
import 'game_hints.dart';

/// The slower games: a puzzle to solve, a word to rebuild, a rhythm to sit in.
/// Nothing here is racing you except the clock you agreed to.

// ────────────────────────────── Slide Nine ──────────────────────────────

/// The eight-tile sliding puzzle. Fewest moves wins.
class SlideNineGame extends StatefulWidget {
  const SlideNineGame({super.key});

  @override
  State<SlideNineGame> createState() => _SlideNineGameState();
}

class _SlideNineGameState extends State<SlideNineGame> with GameSession {
  @override
  String get gameId => 'slide_nine';

  // 0 is the empty square.
  late List<int> _board;
  int _moves = 0;
  bool _over = false;
  int? _best;
  DateTime? _started;

  @override
  void initState() {
    super.initState();
    readBest().then((v) => mounted ? setState(() => _best = v) : null);
    _shuffle();
  }

  /// Shuffles by walking the empty square, never by permuting the list.
  ///
  /// Half of all random permutations of a 15/8-puzzle are unsolvable, and
  /// handing someone a board that cannot be finished is the worst bug this
  /// screen could have. Legal moves from a solved board are always solvable.
  void _shuffle() {
    _board = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    final rand = Random();
    var blank = 8;
    var last = -1;
    for (var i = 0; i < 120; i++) {
      final options = _neighbours(blank).where((n) => n != last).toList();
      final pick = options[rand.nextInt(options.length)];
      _board[blank] = _board[pick];
      _board[pick] = 0;
      last = blank;
      blank = pick;
    }
    _moves = 0;
    _over = false;
    _started = DateTime.now();
    setState(() {});
  }

  List<int> _neighbours(int i) {
    final row = i ~/ 3, col = i % 3;
    return [
      if (row > 0) i - 3,
      if (row < 2) i + 3,
      if (col > 0) i - 1,
      if (col < 2) i + 1,
    ];
  }

  Future<void> _tap(int i) async {
    if (_over) return;
    final blank = _board.indexOf(0);
    if (!_neighbours(blank).contains(i)) return;

    HapticFeedback.selectionClick();
    setState(() {
      _board[blank] = _board[i];
      _board[i] = 0;
      _moves++;
    });

    if (_solved) {
      HapticFeedback.mediumImpact();
      setState(() => _over = true);
      final best = await submitScore(_moves);
      if (mounted) setState(() => _best = best);
    }
  }

  bool get _solved {
    for (var i = 0; i < 8; i++) {
      if (_board[i] != i + 1) return false;
    }
    return true;
  }

  @override
  void dispose() {
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _started == null
        ? 0
        : DateTime.now().difference(_started!).inSeconds;

    return GameShell(

      hintsForGame: gameId,
      title: 'Slide Nine',
      subtitle: _over ? 'Solved in $_moves moves' : '$_moves moves',
      best: _best == null ? null : 'Your best: $_best moves',
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Solved',
              detail: '$_moves moves in ${seconds}s.\n'
                  'Most boards can be done in under forty if you finish the top '
                  'row first and never break it again.',
              best: _best == null ? null : 'Best: $_best moves',
              onRestart: _shuffle,
              restartLabel: 'New board',
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Column(
                children: [
                  const Text(
                    'Slide the tiles until 1–8 sit in order, blank last.',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: 9,
                          itemBuilder: (_, i) {
                            final value = _board[i];
                            if (value == 0) return const SizedBox();
                            final home = value == i + 1;
                            return GestureDetector(
                              onTap: () => _tap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: home
                                      ? AppTheme.primary.withValues(alpha: 0.26)
                                      : AppTheme.bgCard,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                      color: home
                                          ? AppTheme.primary
                                              .withValues(alpha: 0.5)
                                          : AppTheme.border),
                                ),
                                child: Center(
                                  child: Text('$value',
                                      style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: home
                                              ? AppTheme.primaryLight
                                              : AppTheme.textPrimary)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      footer: _over
          ? null
          : SacredButton(
              label: 'New board', icon: Icons.shuffle_rounded, onTap: _shuffle),
    );
  }
}

// ──────────────────────────── Mantra Scramble ────────────────────────────

/// Rebuild the word from its letters, ninety seconds on the clock.
class MantraScrambleGame extends StatefulWidget {
  const MantraScrambleGame({super.key});

  @override
  State<MantraScrambleGame> createState() => _MantraScrambleGameState();
}

class _MantraScrambleGameState extends State<MantraScrambleGame>
    with GameSession {
  @override
  String get gameId => 'mantra_scramble';

  static const _totalSeconds = 90;

  /// Words worth knowing rather than words that merely scramble well — the
  /// hint is the point as much as the puzzle is.
  static const _words = <(String, String)>[
    ('SHANTI', 'Peace — the closing word of many prayers'),
    ('KARMA', 'Action, and what action returns'),
    ('DHARMA', 'The right way to live your own life'),
    ('MANTRA', 'A sound repeated until the mind quiets'),
    ('PRANA', 'Breath as life force'),
    ('MOKSHA', 'Release from the cycle'),
    ('SEVA', 'Service given without expecting return'),
    ('SATYA', 'Truthfulness'),
    ('AHIMSA', 'Non-harm, to others and to yourself'),
    ('VIVEKA', 'Discernment — telling the real from the passing'),
    ('SAMADHI', 'Absorption; the mind resting undivided'),
    ('ANANDA', 'Bliss that is not caused by anything'),
    ('TAPAS', 'Discipline; heat that refines'),
    ('SANGHA', 'The company you keep on the path'),
    ('CHAKRA', 'A wheel of energy along the spine'),
    ('GURU', 'One who moves you from dark to light'),
    ('YOGA', 'Union — of body, breath and attention'),
    ('BHAKTI', 'Devotion as a practice'),
    ('DHYANA', 'Meditation itself'),
    ('SANTOSHA', 'Contentment with what is'),
  ];

  final _rand = Random();
  late List<(String, String)> _queue;
  int _index = 0;
  List<String> _pool = [];
  final List<int> _picked = [];
  int _solved = 0;
  int _left = _totalSeconds;
  int _best = 0;
  bool _over = false;
  bool _flash = false;
  Timer? _clock;

  /// Shown under the clue after a wrong attempt, cleared on the next action.
  String? _nudge;
  int _hintsUsed = 0;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    _queue = [..._words]..shuffle(_rand);
    _load();
    _startClock();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  (String, String) get _current => _queue[_index % _queue.length];

  void _load() {
    final word = _current.$1;
    // Reshuffle until it actually looks scrambled — handing back the answer
    // is a real outcome on a four-letter word.
    var letters = word.split('')..shuffle(_rand);
    var guard = 0;
    while (letters.join() == word && guard++ < 12) {
      letters = word.split('')..shuffle(_rand);
    }
    _pool = letters;
    _picked.clear();
    setState(() {});
  }

  String get _attempt => _picked.map((i) => _pool[i]).join();

  Future<void> _pick(int i) async {
    if (_over || _picked.contains(i)) return;
    HapticFeedback.selectionClick();
    setState(() => _picked.add(i));

    if (_picked.length == _pool.length) {
      if (_attempt == _current.$1) {
        HapticFeedback.mediumImpact();
        setState(() {
          _solved++;
          _index++;
          // A small reward of clock, so a good run extends itself.
          _left = min(_totalSeconds, _left + 5);
        });
        await Future.delayed(const Duration(milliseconds: 260));
        if (mounted) _load();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _flash = true;
          // Say what went wrong instead of only flashing red. A wrong answer
          // with no explanation is where someone decides the game is unfair.
          _nudge = GameHints.nudge(gameId);
        });
        await Future.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
        setState(() {
          _flash = false;
          _picked.clear();
        });
      }
    }
  }

  void _undo() {
    if (_picked.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _picked.removeLast();
      _nudge = null;
    });
  }

  /// Places the next correct letter for you.
  ///
  /// A scramble you cannot see is not a puzzle, it is a wall — and the honest
  /// thing to do when someone hits a wall is to give them a step, not a
  /// consolation message. It costs eight seconds so it stays a trade rather
  /// than a free solve, and it works from wherever they are: any wrong letters
  /// already placed are cleared first, because otherwise the hint would append
  /// a correct letter onto a broken prefix and look like it had lied.
  void _hint() {
    final answer = _current.$1;
    if (_picked.length >= answer.length) return;

    // Drop any prefix that has already gone wrong.
    while (_picked.isNotEmpty && _attempt != answer.substring(0, _picked.length)) {
      _picked.removeLast();
    }

    final needed = answer[_picked.length];
    final at = List.generate(_pool.length, (i) => i).firstWhere(
      (i) => !_picked.contains(i) && _pool[i] == needed,
      orElse: () => -1,
    );
    if (at < 0) return;

    HapticFeedback.selectionClick();
    setState(() {
      _picked.add(at);
      _left = max(1, _left - 8);
      _hintsUsed++;
      _nudge = null;
    });

    // A hint that completes the word should still count as solved — the clock
    // already took its payment.
    if (_picked.length == _pool.length && _attempt == answer) {
      setState(() {
        _solved++;
        _index++;
      });
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _load();
      });
    }
  }

  void _skip() {
    setState(() {
      _index++;
      _left = max(1, _left - 5);
      _nudge = null;
    });
    _load();
  }

  Future<void> _finish() async {
    _clock?.cancel();
    setState(() => _over = true);
    final best = await submitScore(_solved, lowerIsBetter: false);
    if (mounted && best != null) setState(() => _best = best);
  }

  void _restart() {
    setState(() {
      _solved = 0;
      _left = _totalSeconds;
      _over = false;
      _index = 0;
      _hintsUsed = 0;
      _nudge = null;
    });
    _queue.shuffle(_rand);
    _load();
    _startClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Mantra Scramble',
      subtitle: _over ? 'Time up' : '$_solved solved  ·  ${_left}s',
      best: _best > 0 ? 'Your best: $_best words' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: '$_solved words',
              detail: 'Ninety seconds of Sanskrit. '
                  'Each one you unscrambled you also read the meaning of, '
                  'which is the half that stays with you.'
                  '${_hintsUsed == 0 ? '' : '\nHints used: $_hintsUsed — no shame in it, that is what they are for.'}',
              best: 'Best: $_best words',
              onRestart: _restart,
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Column(
                children: [
                  GameTimerBar(value: _left / _totalSeconds),
                  const SizedBox(height: AppTheme.space5),
                  Text(_current.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary)),
                  if (_nudge != null) ...[
                    const SizedBox(height: AppTheme.space3),
                    GameNudge(_nudge!),
                  ],
                  const SizedBox(height: AppTheme.space5),
                  // Slots being filled in.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < _pool.length; s++)
                        Container(
                          width: 38,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _flash
                                ? const Color(0xFF7F1D1D)
                                : AppTheme.bgCard,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                                color: s < _picked.length
                                    ? AppTheme.primary.withValues(alpha: 0.6)
                                    : AppTheme.border),
                          ),
                          child: Center(
                            child: Text(
                              s < _picked.length ? _pool[_picked[s]] : '',
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _pool.length; i++)
                        GestureDetector(
                          onTap: () => _pick(i),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: _picked.contains(i) ? 0.22 : 1,
                            child: Container(
                              width: 46,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.16),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                                border: Border.all(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.45)),
                              ),
                              child: Center(
                                child: Text(_pool[i],
                                    style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
      footer: _over
          ? null
          : Row(
              children: [
                Expanded(
                  child: SacredButton(
                      label: 'Undo',
                      icon: Icons.backspace_outlined,
                      secondary: true,
                      onTap: _picked.isEmpty ? null : _undo),
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: SacredButton(
                      label: 'Hint (−8s)',
                      icon: Icons.lightbulb_outline_rounded,
                      secondary: true,
                      onTap: _picked.length >= _pool.length ? null : _hint),
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: SacredButton(
                      label: 'Skip (−5s)',
                      secondary: true,
                      onTap: _skip),
                ),
              ],
            ),
    );
  }
}

// ──────────────────────────── Breath Rhythm ────────────────────────────

/// Tap exactly when the circle fills the ring. Eight taps, averaged.
///
/// The one game here that gets easier when you stop trying. Chasing the ring
/// with your eyes always lands late; breathing with it lands early enough.
class BreathRhythmGame extends StatefulWidget {
  const BreathRhythmGame({super.key});

  @override
  State<BreathRhythmGame> createState() => _BreathRhythmGameState();
}

class _BreathRhythmGameState extends State<BreathRhythmGame>
    with GameSession, SingleTickerProviderStateMixin {
  @override
  String get gameId => 'breath_rhythm';

  static const _periodMs = 3000;
  static const _taps = 8;

  late final AnimationController _ctrl;
  final List<int> _errors = [];
  bool _over = false;
  int? _best;
  int _lastError = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _periodMs),
    )..repeat();
    readBest().then((v) => mounted ? setState(() => _best = v) : null);
  }

  Future<void> _tap() async {
    if (_over) return;
    final phase = _ctrl.value;
    // The beat is the wrap point, so error is the distance to whichever end of
    // the cycle is nearer — early taps and late taps cost the same.
    final error = (min(phase, 1 - phase) * _periodMs).round();
    _errors.add(error);
    _lastError = error;
    HapticFeedback.selectionClick();

    if (_errors.length >= _taps) {
      final avg = _errors.reduce((a, b) => a + b) ~/ _errors.length;
      _ctrl.stop();
      setState(() => _over = true);
      final best = await submitScore(avg);
      if (mounted) setState(() => _best = best);
    } else {
      setState(() {});
    }
  }

  void _restart() {
    _errors.clear();
    setState(() => _over = false);
    _ctrl
      ..reset()
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avg = _errors.isEmpty
        ? 0
        : _errors.reduce((a, b) => a + b) ~/ _errors.length;

    return GameShell(

      hintsForGame: gameId,
      title: 'Breath Rhythm',
      subtitle: _over
          ? 'Finished'
          : 'Tap ${_errors.length + 1} of $_taps'
              '${_errors.isEmpty ? '' : '  ·  last ${_lastError}ms off'}',
      best: _best == null ? null : 'Your best: ${_best}ms off',
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: '${avg}ms off',
              detail:
                  'Averaged over eight taps. Under 120ms means you were riding '
                  'the rhythm rather than reacting to it.',
              best: _best == null ? null : 'Best: ${_best}ms',
              onRestart: _restart,
            )
          : GestureDetector(
              onTap: _tap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.space4),
                  const Text('Tap the moment the circle fills the ring.',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          color: AppTheme.textSecondary)),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) {
                          final v = _ctrl.value;
                          return SizedBox(
                            width: 260,
                            height: 260,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.accent
                                            .withValues(alpha: 0.65),
                                        width: 2.5),
                                  ),
                                ),
                                Container(
                                  width: 240 * v,
                                  height: 240 * v,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.25 + 0.4 * v),
                                  ),
                                ),
                                Text('${_errors.length}/$_taps',
                                    style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppTheme.space5, 0,
                        AppTheme.space5, AppTheme.space5),
                    child: Text(
                      'Tap anywhere on the screen. Watching the edge makes you '
                      'late; feeling the cycle does not.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          height: 1.5,
                          color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
