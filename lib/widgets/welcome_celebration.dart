import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The moment someone arrives.
///
/// Shown once per sign-in, over the dashboard, and it exists for one reason:
/// the gap between "I made an account" and "I understand why I am here" is
/// where most people leave. A line of copy that names them, tells them what
/// they have joined and gives them one thing to do next closes that gap in the
/// three seconds they are already looking at the screen.
///
/// Everything is drawn rather than imported — the halo, the orbiting petals,
/// the drifting motes — so there is no asset to load and nothing to wait for.
/// Three layers of motion, deliberately at different speeds so it reads as
/// depth rather than as one thing spinning:
///
///   • **the halo** breathes on a 3.2s cycle, slowest, furthest back
///   • **the petals** orbit once every 12s, carrying the eye around the mark
///   • **the motes** drift upward continuously and are the only fast thing
///
/// The content itself lands in four beats — mark, name, message, button — so
/// the eye is led down the card instead of being handed all of it at once.
class WelcomeCelebration extends StatefulWidget {
  /// What to call them. Their own name is the whole point of the popup.
  final String name;

  /// True on the sign-in that follows registration. Changes the words, not the
  /// design: telling a member of six months "welcome to the family" reads as a
  /// system that has not noticed them.
  final bool isNewMember;

  const WelcomeCelebration({
    super.key,
    required this.name,
    this.isNewMember = false,
  });

  /// Opens the celebration. Returns when it is dismissed.
  ///
  /// `showGeneralDialog` rather than `showDialog` because the entrance is part
  /// of the message: the card rises and blooms instead of appearing, which is
  /// the difference between a greeting and an alert.
  static Future<void> show(
    BuildContext context, {
    required String name,
    bool isNewMember = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Welcome',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) =>
          WelcomeCelebration(name: name, isNewMember: isNewMember),
      transitionBuilder: (_, animation, __, child) {
        final eased =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WelcomeCelebration> createState() => _WelcomeCelebrationState();
}

class _WelcomeCelebrationState extends State<WelcomeCelebration>
    with TickerProviderStateMixin {
  /// Staggered reveal of the card's contents. Runs once.
  late final AnimationController _reveal;

  /// Never stops. Drives the halo, the orbit and the motes at once — one
  /// controller instead of three, because three would drift out of phase and
  /// the composition would slowly fall apart while someone reads.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// A fade + rise between [begin] and [end] of the reveal.
  Widget _beat(double begin, double end, Widget child) {
    final curve =
        CurvedAnimation(parent: _reveal, curve: Interval(begin, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curve,
      builder: (_, __) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.isNewMember;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.42), width: 1.2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1D1638), Color(0xFF120F22)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.34),
                    blurRadius: 46,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── the mark ──
                  SizedBox(
                    height: 148,
                    child: AnimatedBuilder(
                      animation: _ambient,
                      builder: (_, __) => CustomPaint(
                        painter: _CelebrationPainter(_ambient.value),
                        child: Center(
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.3, end: 1).animate(
                              CurvedAnimation(
                                parent: _reveal,
                                curve: const Interval(0.0, 0.45,
                                    curve: Curves.easeOutBack),
                              ),
                            ),
                            child: const Text('🪷', style: TextStyle(fontSize: 54)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── the badge ──
                  _beat(
                    0.30,
                    0.55,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        first ? '✨  YOU ARE IN' : '✨  WELCOME BACK',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: AppTheme.accentLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),

                  // ── their name ──
                  _beat(
                    0.38,
                    0.65,
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Color(0xFFF8F8FF), AppTheme.accentLight],
                      ).createShader(rect),
                      child: Text(
                        first
                            ? 'Congratulations,\n${widget.name}'
                            : 'Welcome, ${widget.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 27,
                          height: 1.22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space3),

                  // ── the message ──
                  _beat(
                    0.48,
                    0.78,
                    Text(
                      first
                          ? 'You are now part of the InnenFlow family — a small '
                              'circle of people who decided to sit with themselves '
                              'every day instead of running from the noise.\n\n'
                              'Nothing here is a competition. Write one honest line, '
                              'breathe for five minutes, and let the days add up. '
                              'That is the whole practice.'
                          : 'The InnenFlow family is glad you came back. '
                              'Every day you show up is one more day you chose '
                              'yourself over the noise.\n\n'
                              'One honest line is enough. Begin where you are.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        height: 1.65,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),

                  // ── the three things they get ──
                  _beat(
                    0.58,
                    0.88,
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Perk(emoji: '📖', label: 'Journal'),
                        _Perk(emoji: '🧘', label: 'Meditate'),
                        _Perk(emoji: '🔥', label: 'Build a streak'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space6),

                  // ── the way out ──
                  _beat(
                    0.68,
                    1.0,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: Text(
                          first ? 'Begin my first day' : 'Continue',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final String emoji;
  final String label;

  const _Perk({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Halo, orbiting petals and rising motes, all driven by one 0→1 phase.
///
/// Positions are derived from the phase rather than accumulated frame to frame,
/// so the animation is identical however long the popup stays open and cannot
/// drift or jump when the device drops frames.
class _CelebrationPainter extends CustomPainter {
  final double phase;

  const _CelebrationPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final turn = phase * 2 * math.pi;

    // Halo — breathes on its own slower cycle so it never pulses in time with
    // the orbit, which would read as a single mechanism rather than as depth.
    final breath = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 3.75);
    final haloRadius = 46 + 7 * breath;
    canvas.drawCircle(
      centre,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.42 * (0.6 + 0.4 * breath)),
            AppTheme.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: haloRadius * 2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Two rings, counter-rotating: the outer one is what makes the mark feel
    // like it is being held rather than simply sitting there.
    for (final ring in const [(r: 52.0, alpha: 0.30, dir: 1.0, dashes: 22),
                              (r: 64.0, alpha: 0.16, dir: -1.0, dashes: 34)]) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = AppTheme.accentLight.withValues(alpha: ring.alpha);
      final step = 2 * math.pi / ring.dashes;
      for (var i = 0; i < ring.dashes; i++) {
        final start = i * step + turn * ring.dir;
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: ring.r),
          start,
          step * 0.45,
          false,
          paint,
        );
      }
    }

    // Petals on the orbit.
    const petals = 6;
    for (var i = 0; i < petals; i++) {
      final angle = turn + i * (2 * math.pi / petals);
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * 58;
      // Fade with vertical position so the ones "behind" the mark recede.
      final depth = 0.45 + 0.55 * ((math.sin(angle) + 1) / 2);
      canvas.drawCircle(
        at,
        2.6,
        Paint()
          ..color = AppTheme.accentLight.withValues(alpha: 0.85 * depth)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }

    // Motes drifting upward. Each is offset in the cycle so they arrive
    // staggered rather than as a single rising row.
    const motes = 14;
    for (var i = 0; i < motes; i++) {
      final seed = i / motes;
      final t = (phase * 2 + seed) % 1.0;
      final x = size.width * (0.12 + 0.76 * _hash(i));
      final y = size.height * (1.05 - 1.15 * t);
      // In at the bottom, out at the top — a mote that vanishes mid-air reads
      // as a rendering bug.
      final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x + 5 * math.sin(t * 6 + i), y),
        1.1 + 1.0 * _hash(i + 7),
        Paint()
          ..color = (i.isEven ? AppTheme.primaryLight : AppTheme.accentLight)
              .withValues(alpha: 0.55 * fade),
      );
    }
  }

  /// Deterministic 0–1 scatter. A real RNG would reshuffle every repaint and
  /// the motes would flicker across the card instead of drifting up it.
  double _hash(int i) {
    final v = math.sin(i * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.phase != phase;
}
