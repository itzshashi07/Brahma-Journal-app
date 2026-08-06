import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Staggered entrance: each element fades and rises slightly, offset from the
  /// last. Everything arriving at once reads as a screenshot; a short stagger
  /// reads as an app.
  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - anim.value)), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        showMandala: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Hero: the mandala turns slowly behind a lotus mark.
                _staggered(
                  index: 0,
                  child: SizedBox(
                    height: 210,
                    width: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const BreathingMandala(size: 210, opacity: 0.22),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow:
                                AppTheme.glow(AppTheme.primary, strength: 0.5),
                          ),
                          child: const Center(
                            child: Motif(SacredMotif.lotus,
                                size: 58, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.space8),

                _staggered(
                  index: 1,
                  child: const Text(
                    'Brahma Journal',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                _staggered(
                  index: 2,
                  child: const Text(
                    'A quiet place to reflect, meditate,\nand return to yourself.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      height: 1.6,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.space8),

                _staggered(
                  index: 3,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Pillar(icon: Icons.edit_note_rounded, label: 'Journal'),
                      _Pillar(icon: Icons.self_improvement_rounded, label: 'Meditate'),
                      _Pillar(icon: Icons.auto_awesome_rounded, label: 'Affirm'),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                _staggered(
                  index: 4,
                  child: SacredButton(
                    label: 'Begin your journey',
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => context.push('/signup'),
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                _staggered(
                  index: 5,
                  child: SacredButton(
                    label: 'I already have an account',
                    secondary: true,
                    onTap: () => context.push('/login'),
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                _staggered(
                  index: 6,
                  child: const Text(
                    'ॐ शान्तिः',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pillar({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space5),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 23, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
