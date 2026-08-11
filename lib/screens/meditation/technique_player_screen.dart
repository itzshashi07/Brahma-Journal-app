import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/meditation_techniques.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/chime_service.dart';
import '../../services/meditation_service.dart';
import '../../widgets/sacred.dart';

/// Runs one technique, step by step.
///
/// No audio. The old session screen streamed music from a demo URL, which meant
/// a meditation app that needed the internet to be quiet, and stock pop songs
/// labelled "Tibetan Bowls". Guidance is text on screen and a breathing circle
/// to follow; a vibration marks each change so you can keep your eyes closed.
class TechniquePlayerScreen extends StatefulWidget {
  final String techniqueId;
  const TechniquePlayerScreen({super.key, required this.techniqueId});

  @override
  State<TechniquePlayerScreen> createState() => _TechniquePlayerScreenState();
}

class _TechniquePlayerScreenState extends State<TechniquePlayerScreen>
    with TickerProviderStateMixin {
  final MeditationService _service = MeditationService();
  late final MeditationTechnique _t =
      MeditationTechniques.byId(widget.techniqueId);

  /// Repaints the breathing circle without rebuilding the whole tree.
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  Timer? _clock;
  bool _running = false;
  bool _finished = false;
  bool _haptics = true;

  /// Elapsed time comes from the wall clock, never from counting ticks — a
  /// backgrounded app has its timers throttled, and tick-counting logged a ten
  /// minute sit as six.
  int _accumulated = 0;
  DateTime? _segmentStart;
  int _saved = 0;
  String? _uid;

  int _lastStepIndex = -1;
  int _lastBreathPhase = -1;

  int get _elapsed {
    final start = _segmentStart;
    final running =
        start == null ? 0 : DateTime.now().difference(start).inSeconds;
    return _accumulated + running;
  }

  int get _elapsedMs {
    final start = _segmentStart;
    final running =
        start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
    return _accumulated * 1000 + running;
  }

  int get _total => _t.scriptedSeconds;
  int get _remaining => math.max(0, _total - _elapsed);

  int get _stepIndex {
    var acc = 0;
    for (var i = 0; i < _t.steps.length; i++) {
      acc += _t.steps[i].seconds;
      if (_elapsed < acc) return i;
    }
    return _t.steps.length - 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _uid = context.read<AuthProvider>().user?.uid;
  }

  void _toggle() {
    if (_running) {
      _pause();
    } else {
      _start();
    }
  }

  void _start() {
    if (_finished) {
      setState(() {
        _accumulated = 0;
        _saved = 0;
        _finished = false;
      });
    }
    // Same bell as the plain timer, for the same reason: eyes are about to
    // close, and the screen stops being a usable status indicator.
    ChimeService.instance.start();
    setState(() {
      _running = true;
      _segmentStart = DateTime.now();
    });
    WakelockGuard.enable();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_elapsed >= _total) {
        _complete();
        return;
      }
      // Step changes get a nudge so the eyes can stay closed.
      final i = _stepIndex;
      if (i != _lastStepIndex) {
        _lastStepIndex = i;
        if (_haptics) HapticFeedback.mediumImpact();
        setState(() {});
      }
      _pulseBreathHaptic();
    });
  }

  void _pause() {
    _clock?.cancel();
    ChimeService.instance.pause();
    setState(() {
      _accumulated = _elapsed;
      _segmentStart = null;
      _running = false;
    });
    WakelockGuard.disable();
    _save();
  }

  void _complete() {
    _clock?.cancel();
    ChimeService.instance.end();
    _accumulated = _total;
    _segmentStart = null;
    setState(() {
      _running = false;
      _finished = true;
    });
    WakelockGuard.disable();
    if (_haptics) HapticFeedback.heavyImpact();
    _save();
  }

  /// A short tap at the start of each breath phase, so the pattern can be
  /// followed without looking at the screen.
  void _pulseBreathHaptic() {
    final b = _t.breath;
    if (b == null || !_haptics) return;
    final t = (_elapsed) % b.cycleSeconds;
    var phase = 0;
    var acc = b.inhale;
    if (t >= acc) {
      phase = 1;
      acc += b.holdIn;
      if (t >= acc) {
        phase = 2;
        acc += b.exhale;
        if (t >= acc) phase = 3;
      }
    }
    if (phase != _lastBreathPhase) {
      _lastBreathPhase = phase;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    final pending = _elapsed - _saved;
    if (uid == null || pending <= 0) return;
    _saved += pending;
    final ok = await _service.saveSession(uid, pending);
    if (!ok) _saved -= pending;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _accumulated = _elapsed;
    _segmentStart = null;
    _save();
    WakelockGuard.disable();
    _ticker.dispose();
    super.dispose();
  }

  // ─────────────────────────── breathing ───────────────────────────

  /// 0 → smallest, 1 → largest, following the technique's pattern.
  double _breathValue() {
    final b = _t.breath;
    if (b == null) {
      // No pattern: a slow 4s in, 6s out shape, purely as something to rest on.
      final t = (_elapsedMs / 1000) % 10;
      return t < 4 ? t / 4 : 1 - ((t - 4) / 6);
    }
    final t = (_elapsedMs / 1000) % b.cycleSeconds;
    if (t < b.inhale) return t / b.inhale;
    if (t < b.inhale + b.holdIn) return 1;
    if (t < b.inhale + b.holdIn + b.exhale) {
      return 1 - ((t - b.inhale - b.holdIn) / b.exhale);
    }
    return 0;
  }

  String _breathLabel() {
    final b = _t.breath;
    if (b == null) return _running ? 'Follow the circle' : '';
    final t = _elapsed % b.cycleSeconds;
    if (t < b.inhale) return 'Breathe in';
    if (t < b.inhale + b.holdIn) return 'Hold';
    if (t < b.inhale + b.holdIn + b.exhale) return 'Breathe out';
    return 'Hold';
  }

  @override
  Widget build(BuildContext context) {
    final step = _t.steps[_stepIndex];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_t.gradient.first.withValues(alpha: 0.35), AppTheme.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: _t.name,
                subtitle: _finished
                    ? 'Done'
                    : (_running ? _breathLabel() : _t.tagline),
                onBack: () => context.pop(),
                action: IconButton(
                  tooltip: _haptics ? 'Vibration on' : 'Vibration off',
                  onPressed: () => setState(() => _haptics = !_haptics),
                  icon: Icon(
                    _haptics ? Icons.vibration_rounded : Icons.smartphone_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space5, vertical: AppTheme.space3),
                  child: Column(
                    children: [
                      // Breathing circle + session progress
                      AnimatedBuilder(
                        animation: _ticker,
                        builder: (_, __) {
                          final v = _running ? _breathValue() : 0.35;
                          final progress = _total == 0 ? 0.0 : _elapsed / _total;
                          return SizedBox(
                            width: 250,
                            height: 250,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 250,
                                  height: 250,
                                  child: CircularProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    strokeWidth: 5,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation(
                                        _t.gradient.first),
                                  ),
                                ),
                                Container(
                                  width: 90 + v * 110,
                                  height: 90 + v * 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        _t.gradient.first
                                            .withValues(alpha: 0.55),
                                        _t.gradient.last.withValues(alpha: 0.15),
                                      ],
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatTimer(_remaining),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_t.breath != null)
                                      Text(
                                        _t.breath!.label,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 11,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppTheme.space5),

                      // Current instruction
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          key: ValueKey(_stepIndex),
                          children: [
                            Text(
                              step.instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 18,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (step.note != null) ...[
                              const SizedBox(height: AppTheme.space2),
                              Text(
                                step.note!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.space3),
                      Text(
                        'Step ${_stepIndex + 1} of ${_t.steps.length}',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: AppTheme.textMuted),
                      ),

                      const SizedBox(height: AppTheme.space6),

                      if (_finished)
                        _CompletionCard(minutes: (_elapsed / 60).ceil())
                      else
                        GestureDetector(
                          onTap: _toggle,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _t.gradient),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _t.gradient.first
                                      .withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),

                      const SizedBox(height: AppTheme.space5),

                      // Why this works — collapsed until asked for, so it never
                      // sits between someone and the play button.
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'What this actually does',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary),
                          ),
                          iconColor: AppTheme.textMuted,
                          collapsedIconColor: AppTheme.textMuted,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _t.howItHelps,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  height: 1.6,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.space4),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final int minutes;
  const _CompletionCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 40, color: AppTheme.success),
          const SizedBox(height: AppTheme.space3),
          Text(
            '$minutes ${minutes == 1 ? 'minute' : 'minutes'} added to your practice',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          const Text(
            'The measure is not how the sitting felt. It is whether you come back tomorrow.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                height: 1.5,
                color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Keeps the screen awake during a session if the platform allows it.
///
/// A meditation whose screen locks halfway through loses the instructions and
/// the pacer. There is no wakelock package in this project, so this is a
/// no-op holder: the session still runs on wall-clock time, so a locked screen
/// costs the visuals but never the tracked minutes.
class WakelockGuard {
  static void enable() {}
  static void disable() {}
}
