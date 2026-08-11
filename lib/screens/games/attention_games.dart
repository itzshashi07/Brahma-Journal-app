import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'game_core.dart';

/// The three games the Game Zone started as, moved here intact so the catalogue
/// has one home. Their scores and banked minutes carry over — the game ids are
/// unchanged, which is what SharedPreferences and focus_sessions key on.

// ───────────────────────────── Focus Grid ─────────────────────────────

/// A Schulte table: find 1 to 25 in order.
class FocusGridGame extends StatefulWidget {
  const FocusGridGame({super.key});

  @override
  State<FocusGridGame> createState() => _FocusGridGameState();
}

class _FocusGridGameState extends State<FocusGridGame> with GameSession {
  @override
  String get gameId => 'focus_grid';

  static const _size = 5;
  late List<int> _numbers;
  int _next = 1;
  DateTime? _runStart;
  Timer? _tick;
  int? _best;
  int? _lastResult;

  @override
  void initState() {
    super.initState();
    _shuffle();
    readBest().then((v) => mounted ? setState(() => _best = v) : null);
  }

  void _shuffle() {
    _numbers = List.generate(_size * _size, (i) => i + 1)..shuffle(Random());
    _next = 1;
    _runStart = null;
    _tick?.cancel();
  }

  Future<void> _tap(int n) async {
    if (n != _next) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    if (_next == 1) {
      _runStart = DateTime.now();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() => _next++);

    if (_next > _size * _size) {
      _tick?.cancel();
      final seconds = DateTime.now().difference(_runStart!).inSeconds;
      _lastResult = seconds;
      HapticFeedback.mediumImpact();
      final best = await submitScore(seconds);
      if (mounted) setState(() => _best = best);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _next > _size * _size;
    final elapsed =
        _runStart == null ? 0 : DateTime.now().difference(_runStart!).inSeconds;

    return GameShell(

      hintsForGame: gameId,
      title: 'Focus Grid',
      subtitle: done
          ? 'Done in ${_lastResult}s'
          : (_runStart == null ? 'Tap 1 to start' : 'Find $_next  ·  ${elapsed}s'),
      best: _best == null ? null : 'Your best: ${_best}s',
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _size,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _numbers.length,
              itemBuilder: (_, i) {
                final n = _numbers[i];
                final cleared = n < _next;
                return GestureDetector(
                  onTap: cleared ? null : () => _tap(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: cleared
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                          color: cleared
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.border),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cleared
                              ? AppTheme.primaryLight
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      footer: SacredButton(
        label: done ? 'Again' : 'Shuffle',
        icon: Icons.shuffle_rounded,
        onTap: () => setState(_shuffle),
      ),
    );
  }
}

// ────────────────────────────── Ink Test ──────────────────────────────

/// The Stroop test: tap the colour of the ink, not the word.
class InkTestGame extends StatefulWidget {
  const InkTestGame({super.key});

  @override
  State<InkTestGame> createState() => _InkTestGameState();
}

class _InkTestGameState extends State<InkTestGame> with GameSession {
  @override
  String get gameId => 'ink_test';

  static const _names = ['RED', 'BLUE', 'GREEN', 'YELLOW'];
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  final _rand = Random();
  int _wordIndex = 0;
  int _inkIndex = 1;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _over = false;

  // A round clock, which the original did not have — without one the test can
  // be passed by answering slowly, and slow answering is the thing it measures.
  Timer? _tick;
  double _remaining = 1;
  late double _roundMs;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    _nextRound();
  }

  void _nextRound() {
    _wordIndex = _rand.nextInt(_names.length);
    _inkIndex = _rand.nextInt(_names.length);
    // Mostly mismatched — a matching pair is easy and teaches nothing.
    if (_inkIndex == _wordIndex && _rand.nextBool()) {
      _inkIndex = (_inkIndex + 1) % _names.length;
    }
    _roundMs = max(1300, 3200 - _score * 55).toDouble();
    _remaining = 1;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 50 / _roundMs);
      if (_remaining <= 0) _miss();
    });
    setState(() {});
  }

  void _miss() {
    _tick?.cancel();
    HapticFeedback.heavyImpact();
    _lives--;
    if (_lives <= 0) {
      _finish();
    } else {
      _nextRound();
    }
  }

  Future<void> _finish() async {
    _tick?.cancel();
    setState(() => _over = true);
    final best = await submitScore(_score, lowerIsBetter: false);
    if (mounted && best != null) setState(() => _best = best);
  }

  void _answer(int colorIndex) {
    if (_over) return;
    if (colorIndex == _inkIndex) {
      HapticFeedback.selectionClick();
      _score++;
      _nextRound();
    } else {
      _miss();
    }
  }

  void _restart() {
    setState(() {
      _score = 0;
      _lives = 3;
      _over = false;
    });
    _nextRound();
  }

  @override
  void dispose() {
    _tick?.cancel();
    bankTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Ink Test',
      subtitle: _over ? 'Finished' : 'Score $_score  ·  ${'♥' * _lives}',
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Score $_score',
              detail: 'Reading is automatic; not reading is the work. '
                  'It is the same muscle you use when you decide not to react.',
              best: 'Best: $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const SizedBox(height: AppTheme.space2),
                GameTimerBar(value: _remaining),
                const SizedBox(height: AppTheme.space4),
                const Text(
                  'Tap the COLOUR of the ink — not the word.',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  _names[_wordIndex],
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: _colors[_inkIndex],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.space4),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppTheme.space3,
                    mainAxisSpacing: AppTheme.space3,
                    childAspectRatio: 2.6,
                    children: [
                      for (var i = 0; i < _colors.length; i++)
                        GameChoice(
                          onTap: () => _answer(i),
                          color: _colors[i],
                          filled: true,
                          child: Text(
                            _names[i],
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────── Memory Bloom ───────────────────────────

/// Watch the petals, repeat the pattern, one step longer each round.
class MemoryBloomGame extends StatefulWidget {
  const MemoryBloomGame({super.key});

  @override
  State<MemoryBloomGame> createState() => _MemoryBloomGameState();
}

class _MemoryBloomGameState extends State<MemoryBloomGame> with GameSession {
  @override
  String get gameId => 'memory_bloom';

  static const _petalColors = [
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
    Future.delayed(const Duration(milliseconds: 400), _nextRound);
  }

  Future<void> _nextRound() async {
    if (!mounted) return;
    setState(() {
      _pattern.add(_rand.nextInt(4));
      _inputIndex = 0;
      _playing = true;
    });
    // Speeds up as the pattern grows, so length is not the only pressure.
    final gap = max(140, 320 - _pattern.length * 12);
    final lit = max(200, 420 - _pattern.length * 14);
    for (final p in _pattern) {
      await Future.delayed(Duration(milliseconds: gap));
      if (!mounted) return;
      setState(() => _showing = p);
      HapticFeedback.selectionClick();
      await Future.delayed(Duration(milliseconds: lit));
      if (!mounted) return;
      setState(() => _showing = -1);
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _tap(int i) async {
    if (_playing || _over) return;
    if (_pattern[_inputIndex] != i) {
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
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showing = -1);
    });
    if (_inputIndex == _pattern.length) {
      Future.delayed(const Duration(milliseconds: 500), _nextRound);
    }
  }

  void _restart() {
    setState(() {
      _pattern.clear();
      _over = false;
      _inputIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 300), _nextRound);
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
      title: 'Memory Bloom',
      subtitle: _over
          ? 'Reached ${_pattern.length - 1}'
          : (_playing ? 'Watch' : 'Your turn  ·  ${_pattern.length}'),
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Length ${_pattern.length - 1}',
              detail:
                  'The interesting part is that you felt the exact moment attention '
                  'moved — usually a step or two before the mistake.',
              best: 'Best: $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const Spacer(),
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
                            color: _petalColors[i].withValues(
                                alpha: _showing == i ? 0.95 : 0.28),
                            borderRadius: BorderRadius.circular(
                                _showing == i ? 44 : AppTheme.radiusLg),
                            border: Border.all(
                                color: _petalColors[i].withValues(alpha: 0.6),
                                width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(AppTheme.space5),
                  child: Text(
                    'Watch the pattern, then repeat it. One longer each round.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
    );
  }
}
