import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Branded launch sequence.
///
/// The old splash held a fixed three-second delay before routing — dead time
/// whether or not the app was ready. This runs a choreographed animation and
/// navigates the moment *both* the animation has settled and auth has resolved,
/// so a warm start feels fast and a cold start still finishes gracefully rather
/// than snapping away mid-bloom.
///
/// The sequence reads as an idea rather than a logo drop:
///   0.00–0.45  mandala draws itself outward and begins to turn
///   0.20–0.60  lotus blooms at the centre, scaling with a soft overshoot
///   0.45–0.75  wordmark rises and fades in
///   0.60–0.85  tagline follows
///   0.80–1.00  breathing pulse settles into a steady rhythm
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _breath;

  late final Animation<double> _mandalaScale;
  late final Animation<double> _mandalaFade;
  late final Animation<double> _lotusScale;
  late final Animation<double> _lotusFade;
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _wordmarkRise;
  late final Animation<double> _taglineFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Continuous, independent of the intro so it never restarts mid-breath.
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    Animation<double> curve(double begin, double end, Curve c) =>
        CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: c));

    _mandalaFade = curve(0.00, 0.45, Curves.easeOut);
    _mandalaScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(curve(0.00, 0.55, Curves.easeOutCubic));

    _lotusFade = curve(0.20, 0.55, Curves.easeOut);
    _lotusScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(curve(0.20, 0.60, Curves.easeOutBack));

    _wordmarkFade = curve(0.45, 0.75, Curves.easeOut);
    _wordmarkRise = Tween<double>(begin: 18, end: 0)
        .animate(curve(0.45, 0.75, Curves.easeOutCubic));

    _taglineFade = curve(0.60, 0.85, Curves.easeOut);

    _intro.forward();
    _boot();
  }

  /// Waits for the animation and for auth to resolve, then routes.
  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('onboarding_completed') ?? false;

    // Let the sequence land — but never hold the user longer than this even if
    // Firebase is slow to answer.
    await Future.wait([
      _intro.forward().orCancel.catchError((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 2200)),
    ]);

    if (!mounted || _navigated) return;

    // AuthProvider starts with loading = true and flips once Firebase reports
    // the restored session. Routing before that lands a returning user on the
    // welcome screen for a frame.
    final auth = context.read<AuthProvider>();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (auth.loading && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    if (!seenOnboarding) {
      context.go('/onboarding');
    } else if (auth.isAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        showMandala: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _breath]),
                  builder: (context, _) {
                    // 0.98 → 1.02: a breath you feel rather than watch.
                    final breathe = 0.98 + (_breath.value * 0.04);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _mandalaFade.value * 0.9,
                          child: Transform.scale(
                            scale: _mandalaScale.value * breathe,
                            child: Transform.rotate(
                              angle: _intro.value * 0.6 + _breath.value * 0.05,
                              child: const Motif(
                                SacredMotif.mandala,
                                size: 250,
                                color: AppTheme.primaryLight,
                                opacity: 0.35,
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _lotusFade.value,
                          child: Transform.scale(
                            scale: _lotusScale.value * breathe,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                boxShadow: AppTheme.glow(
                                  AppTheme.primary,
                                  strength: 0.30 + (_breath.value * 0.25),
                                ),
                              ),
                              child: const Center(
                                child: Motif(SacredMotif.lotus,
                                    size: 60, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: AppTheme.space6),

              AnimatedBuilder(
                animation: _intro,
                builder: (context, child) => Opacity(
                  opacity: _wordmarkFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _wordmarkRise.value),
                    child: child,
                  ),
                ),
                child: const Text(
                  'InnenFlow',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.space2),

              AnimatedBuilder(
                animation: _intro,
                builder: (context, child) =>
                    Opacity(opacity: _taglineFade.value, child: child),
                child: const Text(
                  'Return to yourself, one day at a time',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.space10),

              // Three dots breathing in sequence — quieter than a spinner, and
              // it matches the pace of the rest of the screen.
              AnimatedBuilder(
                animation: _breath,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = (_breath.value + i * 0.22) % 1.0;
                    final t = math.sin(phase * math.pi);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryLight
                            .withValues(alpha: 0.25 + (t * 0.6)),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
