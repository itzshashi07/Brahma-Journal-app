import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import '../../widgets/free_access.dart';

/// First-run walkthrough.
///
/// Rewritten from a feature list into a guided explanation of *how the app is
/// used*. The previous version named six features in isolation; nobody forms a
/// habit from a feature list. This walks the actual daily loop — check in,
/// sit, reflect, watch it compound — and closes on the free window, because
/// that is the reason to start today rather than eventually.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(
      motif: SacredMotif.lotus,
      kicker: 'WELCOME',
      title: 'Five minutes a day\nis the whole practice',
      body:
          'InnenFlow is not another app to keep up with. It asks for one short check-in — '
          'and gives you back a record of who you are becoming.',
      bullets: [
        _Bullet(Icons.schedule_rounded, 'Under five minutes daily'),
        _Bullet(Icons.lock_outline_rounded, 'Private by default — only you read your entries'),
        _Bullet(Icons.self_improvement_rounded, 'Built on practices anyone can use'),
      ],
    ),
    _Slide(
      motif: SacredMotif.ripple,
      kicker: 'THE DAILY LOOP',
      title: 'How a day\nactually works',
      body:
          'Four steps, in order, every day. The dashboard walks you through them — '
          'you never have to decide what to do next.',
      flow: [
        _FlowStep('1', 'Read', 'Today\'s thought sets the tone', Icons.lightbulb_outline_rounded),
        _FlowStep('2', 'Sit', 'Meditate with a timer and mantras', Icons.spa_outlined),
        _FlowStep('3', 'Write', 'Log your mood, habits and reflection', Icons.edit_note_rounded),
        _FlowStep('4', 'Grow', 'Your streak and mood trend build themselves', Icons.trending_up_rounded),
      ],
    ),
    _Slide(
      motif: SacredMotif.mandala,
      kicker: 'WHY IT STICKS',
      title: 'The streak does\nthe hard part',
      body:
          'Motivation fades; a visible streak does not. Every entry extends it, the leaderboard '
          'shows you are not practising alone, and your mood chart quietly proves the practice is working.',
      bullets: [
        _Bullet(Icons.local_fire_department_outlined, 'A streak you will not want to break'),
        _Bullet(Icons.groups_outlined, 'A community of seekers, ranked by consistency'),
        _Bullet(Icons.insights_outlined, 'Mood analytics that reveal the pattern'),
      ],
    ),
    _Slide(
      motif: SacredMotif.lotus,
      kicker: 'AND WHEN IT IS HEAVY',
      title: 'Somewhere to put\nwhat you cannot say',
      body:
          'Some things need to leave your head without your name attached. Anonymous reflections '
          'are posted under a generated name, never your own, and fade away after a week.',
      bullets: [
        _Bullet(Icons.visibility_off_outlined, 'Your identity is never stored on the post'),
        _Bullet(Icons.auto_delete_outlined, 'Every reflection disappears after 7 days'),
        _Bullet(Icons.favorite_border_rounded, 'Replies from people walking the same path'),
      ],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    context.go(auth.isAuthenticated ? '/dashboard' : '/welcome');
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppTheme.space4, top: AppTheme.space2),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),

              // Free-access reminder rides along on the last slide — the moment
              // the user is deciding whether to bother signing up.
              if (isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.space6),
                  child: FreeAccessBanner(),
                ),

              Padding(
                padding: const EdgeInsets.all(AppTheme.space6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 6,
                          width: active ? 24 : 6,
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.primary
                                : AppTheme.textMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    SacredButton(
                      label: isLast ? 'Begin my practice' : 'Next',
                      icon: isLast
                          ? Icons.self_improvement_rounded
                          : Icons.arrow_forward_rounded,
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── slide model ───────────────────────────

class _Slide {
  final SacredMotif motif;
  final String kicker;
  final String title;
  final String body;
  final List<_Bullet> bullets;
  final List<_FlowStep> flow;

  const _Slide({
    required this.motif,
    required this.kicker,
    required this.title,
    required this.body,
    this.bullets = const [],
    this.flow = const [],
  });
}

class _Bullet {
  final IconData icon;
  final String text;
  const _Bullet(this.icon, this.text);
}

class _FlowStep {
  final String number;
  final String label;
  final String detail;
  final IconData icon;
  const _FlowStep(this.number, this.label, this.detail, this.icon);
}

// ─────────────────────────── slide view ───────────────────────────

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.space4),
          Center(
            child: SizedBox(
              height: 150,
              width: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const BreathingMandala(size: 150, opacity: 0.16),
                  Motif(slide.motif, size: 62, color: AppTheme.primaryLight),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space6),

          Text(
            slide.kicker,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            slide.title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 27,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          Text(
            slide.body,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14.5,
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space6),

          if (slide.flow.isNotEmpty) _FlowDiagram(steps: slide.flow),

          ...slide.bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(b.icon, size: 16, color: AppTheme.primaryLight),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        b.text,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space4),
        ],
      ),
    );
  }
}

/// Vertical numbered flow with a connecting rail — the four steps of a day,
/// drawn as a sequence so the order is the message.
class _FlowDiagram extends StatelessWidget {
  final List<_FlowStep> steps;
  const _FlowDiagram({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.glow(AppTheme.primary, strength: 0.22),
                    ),
                    child: Center(
                      child: Text(
                        step.number,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.55),
                              AppTheme.primary.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(step.icon, size: 15, color: AppTheme.primaryLight),
                          const SizedBox(width: AppTheme.space2),
                          Text(
                            step.label,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.detail,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
