import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'game_core.dart';

/// Games for the slower end of attention: holding something in mind while
/// something else is happening, and noticing what changed.

// ─────────────────────────────── N-Back ───────────────────────────────

/// The hardest game here, and honestly so.
///
/// A square lights somewhere on the grid every couple of seconds. Say MATCH
/// when this position is the same as the one two steps back. Holding a moving
/// two-item window is uncomfortable — that discomfort is the training.
class NBackGame extends StatefulWidget {
  const NBackGame({super.key});

  @override
  State<NBackGame> createState() => _NBackGameState();
}

class _NBackGameState extends State<NBackGame> with GameSession {
  @override
  String get gameId => 'n_back';

  static const _n = 2;
  static const _trials = 22;
  static const _trialMs = 2300;

  final _rand = Random();
  final List<int> _history = [];
  int _active = -1;
  int _trial = 0;
  int _hits = 0, _misses = 0, _falseAlarms = 0;
  bool _pressedThisTrial = false;
  bool _running = false;
  bool _over = false;
  int _best = 0;
  Timer? _loop;
  Timer? _blank;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
  }

  void _start() {
    _history.clear();
    setState(() {
      _trial = 0;
      _hits = 0;
      _misses = 0;
      _falseAlarms = 0;
      _over = false;
      _running = true;
    });
    _nextTrial();
    _loop = Timer.periodic(
        const Duration(milliseconds: _trialMs), (_) => _nextTrial());
  }

  void _nextTrial() {
    if (!mounted) return;

    // Grade the trial that just ended before moving on.
    if (_history.isNotEmpty) {
      final isMatch = _history.length > _n &&
          _history[_history.length - 1] == _history[_history.length - 1 - _n];
      if (isMatch && !_pressedThisTrial) _misses++;
    }

    if (_trial >= _trials) {
      _finish();
      return;
    }

    // A third of trials are planted matches. Pure randomness on nine cells
    // produces runs with almost nothing to catch, which teaches nothing.
    int next;
    if (_history.length > _n && _rand.nextInt(3) == 0) {
      next = _history[_history.length - _n];
    } else {
      next = _rand.nextInt(9);
      if (_history.length > _n && next == _history[_history.length - _n]) {
        next = (next + 1 + _rand.nextInt(8)) % 9;
      }
    }

    _history.add(next);
    _pressedThisTrial = false;
    HapticFeedback.selectionClick();
    setState(() {
      _active = next;
      _trial++;
    });

    _blank?.cancel();
    _blank = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _active = -1);
    });
  }

  void _callMatch() {
    if (!_running || _over || _pressedThisTrial) return;
    _pressedThisTrial = true;
    final isMatch = _history.length > _n &&
        _history[_history.length - 1] == _history[_history.length - 1 - _n];
    if (isMatch) {
      HapticFeedback.mediumImpact();
      setState(() => _hits++);
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _falseAlarms++);
    }
  }

  Future<void> _finish() async {
    _loop?.cancel();
    _blank?.cancel();
    setState(() {
      _running = false;
      _over = true;
      _active = -1;
    });
    final score = max(0, _hits * 3 - _falseAlarms * 2);
    final best = await submitScore(score, lowerIsBetter: false);
    if (mounted && best != null) setState(() => _best = best);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _blank?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = max(0, _hits * 3 - _falseAlarms * 2);

    return GameShell(

      hintsForGame: gameId,
      title: '2-Back',
      subtitle: _running ? 'Trial $_trial of $_trials' : 'Working memory',
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Score $score',
              detail: '$_hits caught · $_misses missed · '
                  '$_falseAlarms false calls.\n'
                  'Six hits on a first run is respectable. Nobody finds this easy.',
              best: 'Best: $_best',
              onRestart: _start,
            )
          : !_running
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.space5),
                    child: GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('How it works',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: AppTheme.space3),
                          const Text(
                            'A square lights up every couple of seconds.\n\n'
                            'Tap MATCH when the square is in the same place it '
                            'was TWO steps ago — not the last one, the one '
                            'before it.\n\n'
                            'Right calls earn 3. Wrong calls cost 2. '
                            'Saying nothing is safer than guessing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                height: 1.6,
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.space4),
                          SacredButton(label: 'Begin', onTap: _start),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: AppTheme.space3),
                    GameStats([
                      ('hits', '$_hits'),
                      ('missed', '$_misses'),
                      ('false', '$_falseAlarms'),
                    ]),
                    const SizedBox(height: AppTheme.space4),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.space5),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                              itemCount: 9,
                              itemBuilder: (_, i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: i == _active
                                      ? AppTheme.primary
                                      : AppTheme.bgCard.withValues(alpha: 0.7),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                      color: i == _active
                                          ? AppTheme.primaryLight
                                          : AppTheme.border),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      footer: _running
          ? SacredButton(
              label: _pressedThisTrial ? 'Called' : 'MATCH',
              icon: Icons.check_rounded,
              onTap: _pressedThisTrial ? null : _callMatch,
            )
          : null,
    );
  }
}

// ────────────────────────────── Mirror Tap ──────────────────────────────

/// Simon, reflected. Watch the pattern, then tap the opposite tile each time.
///
/// Remembering the sequence is the easy half. Every tap then has to be
/// translated, and the hand keeps wanting to go where the light was.
class MirrorTapGame extends StatefulWidget {
  const MirrorTapGame({super.key});

  @override
  State<MirrorTapGame> createState() => _MirrorTapGameState();
}

class _MirrorTapGameState extends State<MirrorTapGame> with GameSession {
  @override
  String get gameId => 'mirror_tap';

  // 2×2 board; the mirror is horizontal, so 0↔1 and 2↔3.
  static const _mirror = [1, 0, 3, 2];
  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  final _rand = Random();
  final List<int> _pattern = [];
  int _inputIndex = 0;
  int _showing = -1;
  bool _playing = false;
  bool _over = false;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    Future.delayed(const Duration(milliseconds: 500), _nextRound);
  }

  Future<void> _nextRound() async {
    if (!mounted) return;
    setState(() {
      _pattern.add(_rand.nextInt(4));
      _inputIndex = 0;
      _playing = true;
    });
    for (final p in _pattern) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _showing = p);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _showing = -1);
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _tap(int i) async {
    if (_playing || _over) return;
    if (_mirror[_pattern[_inputIndex]] != i) {
      HapticFeedback.heavyImpact();
      setState(() => _over = true);
      final best = await submitScore(_pattern.length - 1, lowerIsBetter: false);
      if (mounted && best != null) setState(() => _best = best);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _showing = i;
      _inputIndex++;
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _showing = -1);
    });
    if (_inputIndex == _pattern.length) {
      Future.delayed(const Duration(milliseconds: 520), _nextRound);
    }
  }

  void _restart() {
    setState(() {
      _pattern.clear();
      _over = false;
      _inputIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 350), _nextRound);
  }

  @override
  void dispose() {
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Mirror Tap',
      subtitle: _over
          ? 'Reached ${_pattern.length - 1}'
          : (_playing ? 'Watch' : 'Your turn  ·  ${_pattern.length}'),
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Length ${_pattern.length - 1}',
              detail:
                  'Every tap had to be flipped before your hand was allowed to move. '
                  'Four is fine. Seven is unusual.',
              best: 'Best: $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const Spacer(),
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space5, vertical: AppTheme.space3),
                  padding: const EdgeInsets.all(AppTheme.space3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Tap the tile OPPOSITE the one that lit — left for right, '
                    'right for left.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppTheme.accentLight),
                  ),
                ),
                Wrap(
                  spacing: AppTheme.space4,
                  runSpacing: AppTheme.space4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      GestureDetector(
                        onTap: () => _tap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            color: _colors[i].withValues(
                                alpha: _showing == i ? 0.95 : 0.26),
                            borderRadius: BorderRadius.circular(
                                _showing == i ? 44 : AppTheme.radiusLg),
                            border: Border.all(
                                color: _colors[i].withValues(alpha: 0.6),
                                width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
              ],
            ),
    );
  }
}

// ────────────────────────────── Pair Bloom ──────────────────────────────

/// Sixteen tiles, eight pairs, as few moves as you can manage.
class PairBloomGame extends StatefulWidget {
  const PairBloomGame({super.key});

  @override
  State<PairBloomGame> createState() => _PairBloomGameState();
}

class _PairBloomGameState extends State<PairBloomGame> with GameSession {
  @override
  String get gameId => 'pair_bloom';

  static const _symbols = ['🪷', '🍃', '🔔', '🕯️', '🌙', '🐚', '🌿', '✨'];

  late List<String> _deck;
  final Set<int> _matched = {};
  int? _first;
  int? _second;
  int _moves = 0;
  bool _busy = false;
  bool _over = false;
  int? _best;

  @override
  void initState() {
    super.initState();
    readBest().then((v) => mounted ? setState(() => _best = v) : null);
    _deal();
  }

  void _deal() {
    _deck = [..._symbols, ..._symbols]..shuffle(Random());
    _matched.clear();
    _first = null;
    _second = null;
    _moves = 0;
    _over = false;
    _busy = false;
    setState(() {});
  }

  Future<void> _flip(int i) async {
    if (_busy || _over || _matched.contains(i) || i == _first) return;
    HapticFeedback.selectionClick();

    if (_first == null) {
      setState(() => _first = i);
      return;
    }

    setState(() {
      _second = i;
      _moves++;
      _busy = true;
    });

    final isPair = _deck[_first!] == _deck[i];
    await Future.delayed(Duration(milliseconds: isPair ? 320 : 760));
    if (!mounted) return;

    setState(() {
      if (isPair) _matched.addAll([_first!, _second!]);
      _first = null;
      _second = null;
      _busy = false;
    });

    if (_matched.length == _deck.length) {
      HapticFeedback.mediumImpact();
      setState(() => _over = true);
      final best = await submitScore(_moves);
      if (mounted) setState(() => _best = best);
    }
  }

  @override
  void dispose() {
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Pair Bloom',
      subtitle: _over ? 'Cleared' : '$_moves moves  ·  ${_matched.length ~/ 2}/8 pairs',
      best: _best == null ? null : 'Your best: $_best moves',
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: '$_moves moves',
              detail: 'Sixteen tiles, eight pairs. '
                  'Under fourteen means you were genuinely tracking, not turning over tiles.',
              best: _best == null ? null : 'Best: $_best moves',
              onRestart: _deal,
              restartLabel: 'Deal again',
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _deck.length,
                    itemBuilder: (_, i) {
                      final open =
                          _matched.contains(i) || i == _first || i == _second;
                      return GestureDetector(
                        onTap: () => _flip(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: open
                                ? AppTheme.primary.withValues(
                                    alpha: _matched.contains(i) ? 0.28 : 0.18)
                                : AppTheme.bgCard,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                                color: open
                                    ? AppTheme.primary.withValues(alpha: 0.5)
                                    : AppTheme.border),
                          ),
                          child: Center(
                            child: Text(open ? _deck[i] : '',
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

// ──────────────────────────── Spot the Shift ────────────────────────────

/// A grid blinks and one tile comes back different. Which one?
///
/// Change blindness: a blank frame between two images wipes out the motion cue
/// the eye normally uses, so the change has to be found by comparison instead.
class SpotShiftGame extends StatefulWidget {
  const SpotShiftGame({super.key});

  @override
  State<SpotShiftGame> createState() => _SpotShiftGameState();
}

class _SpotShiftGameState extends State<SpotShiftGame> with GameSession {
  @override
  String get gameId => 'spot_shift';

  final _rand = Random();
  List<Color> _tiles = [];
  int _changed = -1;
  int _round = 1;
  int _lives = 3;
  int _best = 0;
  bool _blank = false;
  bool _locked = true;
  bool _over = false;
  Timer? _seq;

  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF64748B),
  ];

  int get _grid => min(5, 3 + (_round - 1) ~/ 4);

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    _startRound();
  }

  void _startRound() {
    final n = _grid * _grid;
    _tiles = List.generate(n, (_) => _palette[_rand.nextInt(_palette.length)]);
    _changed = _rand.nextInt(n);
    _locked = true;
    _blank = false;
    setState(() {});

    // Study time shortens as rounds go up; the blank frame stays constant.
    final studyMs = max(900, 2200 - _round * 90);
    _seq?.cancel();
    _seq = Timer(Duration(milliseconds: studyMs), () {
      if (!mounted) return;
      setState(() => _blank = true);
      _seq = Timer(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        final old = _tiles[_changed];
        var next = _palette[_rand.nextInt(_palette.length)];
        while (next == old) {
          next = _palette[_rand.nextInt(_palette.length)];
        }
        setState(() {
          _tiles[_changed] = next;
          _blank = false;
          _locked = false;
        });
      });
    });
  }

  Future<void> _tap(int i) async {
    if (_locked || _over) return;
    if (i == _changed) {
      HapticFeedback.selectionClick();
      setState(() => _round++);
      _startRound();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _lives--);
      if (_lives <= 0) {
        setState(() => _over = true);
        final best = await submitScore(_round - 1, lowerIsBetter: false);
        if (mounted && best != null) setState(() => _best = best);
      } else {
        _startRound();
      }
    }
  }

  void _restart() {
    setState(() {
      _round = 1;
      _lives = 3;
      _over = false;
    });
    _startRound();
  }

  @override
  void dispose() {
    _seq?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Spot the Shift',
      subtitle:
          _over ? 'Finished' : 'Round $_round  ·  ${'♥' * max(0, _lives)}',
      best: _best > 0 ? 'Your best: round $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Round ${_round - 1}',
              detail:
                  'The blank frame removes the flicker your eye would normally '
                  'catch. Holding the whole grid loosely beats scanning it tile by tile.',
              best: 'Best: round $_best',
              onRestart: _restart,
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Column(
                children: [
                  Text(
                    _locked ? 'Remember this grid…' : 'One tile changed. Tap it.',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _locked
                            ? AppTheme.textSecondary
                            : AppTheme.accentLight),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedOpacity(
                          opacity: _blank ? 0 : 1,
                          duration: const Duration(milliseconds: 90),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _grid,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: _tiles.length,
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _tap(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _tiles[i],
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSm),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ────────────────────────────── Dot Count ──────────────────────────────

/// Dots flash for under a second. How many were there?
///
/// Up to four the answer arrives without counting. Past that the mind starts
/// counting and runs out of time, which is where estimation has to take over.
class DotCountGame extends StatefulWidget {
  const DotCountGame({super.key});

  @override
  State<DotCountGame> createState() => _DotCountGameState();
}

class _DotCountGameState extends State<DotCountGame> with GameSession {
  @override
  String get gameId => 'dot_count';

  final _rand = Random();
  List<Offset> _dots = [];
  List<int> _options = [];
  int _count = 0;
  int _round = 1;
  int _lives = 3;
  int _best = 0;
  bool _showing = false;
  bool _over = false;
  Timer? _flash;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    _startRound();
  }

  void _startRound() {
    final low = 4 + _round;
    _count = low + _rand.nextInt(5);
    // Fractional positions, so the layout survives any screen size.
    _dots = List.generate(
        _count, (_) => Offset(_rand.nextDouble(), _rand.nextDouble()));

    final set = <int>{_count};
    while (set.length < 4) {
      final delta = 1 + _rand.nextInt(3);
      final candidate = _rand.nextBool() ? _count + delta : _count - delta;
      if (candidate > 0) set.add(candidate);
    }
    _options = set.toList()..shuffle(_rand);

    setState(() => _showing = true);
    _flash?.cancel();
    _flash = Timer(Duration(milliseconds: max(320, 900 - _round * 45)), () {
      if (mounted) setState(() => _showing = false);
    });
  }

  Future<void> _answer(int value) async {
    if (_showing || _over) return;
    if (value == _count) {
      HapticFeedback.selectionClick();
      setState(() => _round++);
      _startRound();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _lives--);
      if (_lives <= 0) {
        setState(() => _over = true);
        final best = await submitScore(_round - 1, lowerIsBetter: false);
        if (mounted && best != null) setState(() => _best = best);
      } else {
        _startRound();
      }
    }
  }

  void _restart() {
    setState(() {
      _round = 1;
      _lives = 3;
      _over = false;
    });
    _startRound();
  }

  @override
  void dispose() {
    _flash?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Dot Count',
      subtitle: _over ? 'Finished' : 'Round $_round  ·  ${'♥' * max(0, _lives)}',
      best: _best > 0 ? 'Your best: round $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Round ${_round - 1}',
              detail: 'It was $_count that time. '
                  'Past six, counting is too slow — the trick is to take in the '
                  'whole cluster at once and trust the first number that appears.',
              best: 'Best: round $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const SizedBox(height: AppTheme.space2),
                Text(_showing ? 'Look…' : 'How many?',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _showing
                            ? AppTheme.textSecondary
                            : AppTheme.accentLight)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.space4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: LayoutBuilder(
                        builder: (_, c) => Stack(
                          children: [
                            if (_showing)
                              for (final d in _dots)
                                Positioned(
                                  left: 14 + d.dx * (c.maxWidth - 42),
                                  top: 14 + d.dy * (c.maxHeight - 42),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentLight,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                      AppTheme.space4, AppTheme.space4),
                  child: Row(
                    children: [
                      for (final o in _options) ...[
                        Expanded(
                          child: Opacity(
                            opacity: _showing ? 0.35 : 1,
                            child: GameChoice(
                              onTap: () => _answer(o),
                              height: 56,
                              child: Text('$o',
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary)),
                            ),
                          ),
                        ),
                        if (o != _options.last)
                          const SizedBox(width: AppTheme.space3),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
