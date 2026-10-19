import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        showMandala: false,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, bounds) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 440,
                      minHeight:
                          (bounds.maxHeight - 48).clamp(0.0, double.infinity)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [
                        Icon(Icons.blur_circular_rounded,
                            color: AppTheme.primaryLight, size: 24),
                        SizedBox(width: 10),
                        Flexible(
                            child: Text('InnenFlow',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary))),
                      ]),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                  child: ExcludeSemantics(
                                      child: SizedBox(
                                height: 160,
                                width: 160,
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const BreathingMandala(
                                          size: 160, opacity: 0.24),
                                      Container(
                                          width: 84,
                                          height: 84,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient:
                                                  AppTheme.primaryGradient,
                                              boxShadow: AppTheme.glow(
                                                  AppTheme.primary,
                                                  strength: 0.25)),
                                          child: const Center(
                                              child: Motif(SacredMotif.lotus,
                                                  size: 44,
                                                  color: Colors.white))),
                                    ]),
                              ))),
                              const SizedBox(height: 28),
                              const Text('LESS NOISE. MORE YOU.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFE7CDA5))),
                              const SizedBox(height: 14),
                              const Text('Find a little\nroom to breathe.',
                                  style: TextStyle(
                                      fontSize: 38,
                                      height: 1.1,
                                      letterSpacing: -1.3,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 16),
                              const Text(
                                  'A journal for your thoughts. A pause for your mind.\nA small practice that belongs to you.',
                                  style: TextStyle(
                                      fontSize: 16,
                                      height: 1.6,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 24),
                              const Wrap(spacing: 8, runSpacing: 8, children: [
                                _Pillar(
                                    icon: Icons.edit_note_rounded,
                                    label: 'Reflect'),
                                _Pillar(
                                    icon: Icons.air_rounded, label: 'Breathe'),
                                _Pillar(
                                    icon: Icons.insights_rounded,
                                    label: 'Grow'),
                              ]),
                            ]),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SacredButton(
                                label: 'Create your account',
                                icon: Icons.arrow_forward_rounded,
                                onTap: () => context.push('/signup')),
                            const SizedBox(height: 12),
                            SacredButton(
                                label: 'Sign in',
                                secondary: true,
                                onTap: () => context.push('/login')),
                            const SizedBox(height: 16),
                            const Text('Start small. Come as you are.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13, color: AppTheme.textMuted)),
                          ]),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppTheme.primaryLight),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ]),
      );
}
