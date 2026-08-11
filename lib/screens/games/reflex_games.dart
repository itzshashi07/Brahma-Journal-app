import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'game_core.dart';

/// Games that train the fast end of attention: reacting, switching, resisting
/// the obvious answer. All of them get harder while you play, because a game
/// that stays the same difficulty stops teaching after the third round.

// ──────────────────────────── Reaction Bell ────────────────────────────

/// Wait for gold, tap. Five rounds, averaged.
class ReactionBellGame extends StatefulWidget {
  const ReactionBellGame({super.key});

  @override
  State<ReactionBellGame> createState() => _ReactionBellGameState();
}

enum _BellPhase { idle, waiting, armed, tooSoon, scored, done }

class _ReactionBellGameState extends State<ReactionBellGame> with GameSession {
  @override
  String get gameId => 'reaction_bell';

  static const _rounds = 5;

  final _rand = Random();
  final List<int> _times = [];
  _BellPhase _phase = _BellPhase.idle;
  Timer? _armTimer;
  DateTime? _armedAt;
  int _last = 0;
  int? _best;

  @override
  void initState() {
    super.initState();
    readBest().then((v) => mounted ? setState(() => _best = v) : null);
  }

  void _arm() {
    _armTimer?.cancel();
    setState(() => _phase = _BellPhase.waiting);
    // Deliberately unpredictable. A fixed delay is answered by rhythm rather
    // than by attention, and the score stops meaning anything.
    final delay = 1200 + _rand.nextInt(3200);
    _armTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _phase = _BellPhase.armed;
        _armedAt = DateTime.now();
      });
    });
  }

  Future<void> _tap() async {
    switch (_phase) {
      case _BellPhase.idle:
      case _BellPhase.tooSoon:
      case _BellPhase.scored:
        _arm();
      case _BellPhase.waiting:
        _armTimer?.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _BellPhase.tooSoon);
      case _BellPhase.armed:
        final ms = DateTime.now().difference(_armedAt!).inMilliseconds;
        HapticFeedback.mediumImpact();
        _times.add(ms);
        _last = ms;
        if (_times.length >= _rounds) {
          final avg = _times.reduce((a, b) => a + b) ~/ _times.length;
          setState(() => _phase = _BellPhase.done);
          final best = await submitScore(avg);
          if (mounted) setState(() => _best = best);
        } else {
          setState(() => _phase = _BellPhase.scored);
        }
      case _BellPhase.done:
        break;
    }
  }

  void _restart() {
    _times.clear();
    setState(() => _phase = _BellPhase.idle);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    bankTime();
    super.dispose();
  }

  (Color, String, String) get _face => switch (_phase) {
        _BellPhase.idle => (
            AppTheme.bgCard,
            'Tap to begin',
            'Then wait for gold'
          ),
        _BellPhase.waiting => (
            const Color(0xFF1E293B),
            'Wait…',
            'Do not tap yet'
          ),
        _BellPhase.armed => (AppTheme.accent, 'NOW', ''),
        _BellPhase.tooSoon => (
            const Color(0xFF7F1D1D),
            'Too soon',
            'Tap to try that round again'
          ),
        _BellPhase.scored => (
            AppTheme.bgCard,
            '$_last ms',
            'Tap for round ${_times.length + 1}'
          ),
        _BellPhase.done => (AppTheme.bgCard, 'Done', ''),
      };

  @override
  Widget build(BuildContext context) {
    final (color, headline, hint) = _face;
    final avg = _times.isEmpty
        ? 0
        : _times.reduce((a, b) => a + b) ~/ _times.length;

    return GameShell(

      hintsForGame: gameId,
      title: 'Reaction Bell',
      subtitle: 'Round ${min(_times.length + 1, _rounds)} of $_rounds',
      best: _best == null ? null : 'Your best average: ${_best}ms',
      body: _phase == _BellPhase.done
          ? GameResult(
              hintsForGame: gameId,
              headline: '${avg}ms average',
              detail: 'Rounds: ${_times.join(' · ')} ms.\n'
                  'Anything under 250ms is quick for a thumb on glass.',
              best: _best == null ? null : 'Best average: ${_best}ms',
              onRestart: _restart,
            )
          : GestureDetector(
              onTap: _tap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(headline,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: _phase == _BellPhase.armed ? 52 : 30,
                            fontWeight: FontWeight.w800,
                            color: _phase == _BellPhase.armed
                                ? const Color(0xFF1A1A2E)
                                : AppTheme.textPrimary,
                          )),
                      if (hint.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space2),
                        Text(hint,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ───────────────────────────── Rule Switch ─────────────────────────────

/// Two numbers, and a rule that keeps changing under you.
///
/// The numerical Stroop: a 4 printed large next to a 9 printed small argues
/// with itself, and the rule decides which argument wins. Switching rules costs
/// real time — that cost is the whole exercise.
class RuleSwitchGame extends StatefulWidget {
  const RuleSwitchGame({super.key});

  @override
  State<RuleSwitchGame> createState() => _RuleSwitchGameState();
}

class _RuleSwitchGameState extends State<RuleSwitchGame> with GameSession {
  @override
  String get gameId => 'rule_switch';

  final _rand = Random();
  int _left = 3, _right = 8;
  double _leftSize = 30, _rightSize = 60;
  bool _byValue = true;
  bool _wantBigger = true;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _over = false;

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
    _left = 1 + _rand.nextInt(9);
    do {
      _right = 1 + _rand.nextInt(9);
    } while (_right == _left);

    // Incongruent most of the time: the small number is usually the big value.
    final congruent = _rand.nextInt(10) < 3;
    final leftIsBigValue = _left > _right;
    final leftIsBigText = congruent ? leftIsBigValue : !leftIsBigValue;
    _leftSize = leftIsBigText ? 68 : 30;
    _rightSize = leftIsBigText ? 30 : 68;

    _byValue = _rand.nextBool();
    _wantBigger = _rand.nextBool();

    // Squeezes from 3s down to 1.2s as the score climbs.
    _roundMs = max(1200, 3000 - _score * 60).toDouble();
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

  void _answer(bool leftChosen) {
    if (_over) return;
    final bool leftWins = _byValue
        ? (_wantBigger ? _left > _right : _left < _right)
        : (_wantBigger ? _leftSize > _rightSize : _leftSize < _rightSize);
    if (leftChosen == leftWins) {
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

  String get _rule =>
      'Tap the ${_wantBigger ? 'BIGGER' : 'SMALLER'} ${_byValue ? 'NUMBER' : 'TEXT'}';

  @override
  Widget build(BuildContext context) {
    return GameShell(
      hintsForGame: gameId,
      title: 'Rule Switch',
      subtitle: _over ? 'Finished' : 'Score $_score  ·  ${'♥' * _lives}',
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Score $_score',
              detail:
                  'The rule flipped without warning and you kept up $_score times.',
              best: 'Best: $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const SizedBox(height: AppTheme.space2),
                GameTimerBar(value: _remaining),
                const SizedBox(height: AppTheme.space5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space5, vertical: AppTheme.space3),
                  decoration: BoxDecoration(
                    color: (_byValue ? AppTheme.primary : AppTheme.accent)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(
                        color: (_byValue ? AppTheme.primary : AppTheme.accent)
                            .withValues(alpha: 0.5)),
                  ),
                  child: Text(_rule,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _byValue
                              ? AppTheme.primaryLight
                              : AppTheme.accentLight)),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(child: _numberPad(_left, _leftSize, true)),
                    Expanded(child: _numberPad(_right, _rightSize, false)),
                  ],
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.space5),
                  child: Text(
                    'NUMBER means its value. TEXT means how large it is printed. '
                    'They usually disagree.',
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
    );
  }

  Widget _numberPad(int value, double size, bool isLeft) {
    return GestureDetector(
      onTap: () => _answer(isLeft),
      child: Container(
        height: 190,
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text('$value',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ),
      ),
    );
  }
}

// ───────────────────────────── Quick Math ─────────────────────────────

/// Mental arithmetic against a clock that keeps tightening.
class QuickMathGame extends StatefulWidget {
  const QuickMathGame({super.key});

  @override
  State<QuickMathGame> createState() => _QuickMathGameState();
}

class _QuickMathGameState extends State<QuickMathGame> with GameSession {
  @override
  String get gameId => 'quick_math';

  final _rand = Random();
  String _question = '';
  int _answer = 0;
  List<int> _options = [];
  int _score = 0;
  int _streak = 0;
  int _lives = 3;
  int _best = 0;
  bool _over = false;

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
    // Difficulty rides on the score, not on a fixed level table, so a good run
    // gets genuinely hard instead of running out of content.
    final tier = min(4, _score ~/ 5);
    final a = 2 + _rand.nextInt(9 + tier * 6);
    final b = 2 + _rand.nextInt(6 + tier * 5);
    final ops = ['+', '-', '×', if (tier >= 2) '×', if (tier >= 3) '÷'];
    final op = ops[_rand.nextInt(ops.length)];

    switch (op) {
      case '+':
        _answer = a + b;
        _question = '$a + $b';
      case '-':
        _answer = max(a, b) - min(a, b);
        _question = '${max(a, b)} − ${min(a, b)}';
      case '×':
        final x = 2 + _rand.nextInt(9 + tier * 2);
        final y = 2 + _rand.nextInt(9);
        _answer = x * y;
        _question = '$x × $y';
      default:
        final y = 2 + _rand.nextInt(9);
        final product = y * (2 + _rand.nextInt(9));
        _answer = product ~/ y;
        _question = '$product ÷ $y';
    }

    final set = <int>{_answer};
    while (set.length < 4) {
      final delta = 1 + _rand.nextInt(max(3, _answer ~/ 3 + 2));
      final candidate = _rand.nextBool() ? _answer + delta : _answer - delta;
      if (candidate >= 0) set.add(candidate);
    }
    _options = set.toList()..shuffle(_rand);

    _roundMs = max(2000, 6000 - _score * 120).toDouble();
    _remaining = 1;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 50 / _roundMs);
      if (_remaining <= 0) _wrong();
    });
    setState(() {});
  }

  void _wrong() {
    _tick?.cancel();
    HapticFeedback.heavyImpact();
    _streak = 0;
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

  void _pick(int value) {
    if (_over) return;
    if (value == _answer) {
      HapticFeedback.selectionClick();
      _score++;
      _streak++;
      _nextRound();
    } else {
      _wrong();
    }
  }

  void _restart() {
    setState(() {
      _score = 0;
      _streak = 0;
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
      title: 'Quick Math',
      subtitle: _over ? 'Finished' : '${'♥' * _lives}  ·  streak $_streak',
      best: _best > 0 ? 'Your best: $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: '$_score solved',
              detail: 'The clock tightens with every answer — '
                  'past twenty it is no longer arithmetic, it is nerve.',
              best: 'Best: $_best',
              onRestart: _restart,
            )
          : Column(
              children: [
                const SizedBox(height: AppTheme.space2),
                GameTimerBar(value: _remaining),
                const SizedBox(height: AppTheme.space4),
                GameStats([
                  ('score', '$_score'),
                  ('streak', '$_streak'),
                  ('lives', '$_lives'),
                ]),
                const Spacer(),
                Text(_question,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.space4),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppTheme.space3,
                    mainAxisSpacing: AppTheme.space3,
                    childAspectRatio: 2.4,
                    children: [
                      for (final o in _options)
                        GameChoice(
                          onTap: () => _pick(o),
                          child: Text('$o',
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────── Odd Colour Out ───────────────────────────

/// One tile is a slightly different shade. It gets less different every level.
class OddColourGame extends StatefulWidget {
  const OddColourGame({super.key});

  @override
  State<OddColourGame> createState() => _OddColourGameState();
}

class _OddColourGameState extends State<OddColourGame> with GameSession {
  @override
  String get gameId => 'odd_colour';

  static const _totalSeconds = 45;

  final _rand = Random();
  int _level = 1;
  int _oddIndex = 0;
  int _grid = 2;
  late Color _base;
  late Color _odd;
  int _left = _totalSeconds;
  Timer? _clock;
  int _best = 0;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    readBest()
        .then((v) => mounted && v != null ? setState(() => _best = v) : null);
    _build();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _build() {
    _grid = min(6, 2 + (_level - 1) ~/ 3);
    final hue = _rand.nextDouble() * 360;
    final sat = 0.55 + _rand.nextDouble() * 0.3;
    final light = 0.45 + _rand.nextDouble() * 0.15;
    _base = HSLColor.fromAHSL(1, hue, sat, light).toColor();
    // The gap closes as the grid grows; by level 15 it is a few percent of
    // lightness across 36 tiles, which is where it stops being casual.
    final delta = max(0.035, 0.24 - _level * 0.014);
    final lighter = light + delta > 0.85 ? light - delta : light + delta;
    _odd = HSLColor.fromAHSL(1, hue, sat, lighter).toColor();
    _oddIndex = _rand.nextInt(_grid * _grid);
    setState(() {});
  }

  void _tap(int i) {
    if (_over) return;
    if (i == _oddIndex) {
      HapticFeedback.selectionClick();
      _level++;
      _build();
    } else {
      HapticFeedback.heavyImpact();
      // Wrong taps cost clock rather than ending the run — guessing across a
      // 36-tile grid should be expensive, not fatal.
      setState(() => _left = max(1, _left - 3));
    }
  }

  Future<void> _finish() async {
    _clock?.cancel();
    setState(() => _over = true);
    final best = await submitScore(_level - 1, lowerIsBetter: false);
    if (mounted && best != null) setState(() => _best = best);
  }

  void _restart() {
    setState(() {
      _level = 1;
      _left = _totalSeconds;
      _over = false;
    });
    _build();
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
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
      title: 'Odd Colour Out',
      subtitle: _over ? 'Time up' : 'Level $_level  ·  ${_left}s left',
      best: _best > 0 ? 'Your best: level $_best' : null,
      body: _over
          ? GameResult(
              hintsForGame: gameId,
              headline: 'Level ${_level - 1}',
              detail:
                  'Past level ten the difference is a few percent of lightness. '
                  'Softening your gaze finds it faster than staring does.',
              best: 'Best: level $_best',
              onRestart: _restart,
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Column(
                children: [
                  GameTimerBar(value: _left / _totalSeconds),
                  const SizedBox(height: AppTheme.space4),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _grid,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                          itemCount: _grid * _grid,
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _tap(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == _oddIndex ? _odd : _base,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
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
