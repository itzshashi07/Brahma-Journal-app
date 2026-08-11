import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/meditation_techniques.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Every technique, filterable by what you need.
///
/// The old screen offered one timer and a list of background tracks, which
/// assumes the visitor already knows how to meditate and only lacks a clock.
/// Most people do not — they need to be told what to actually do with the ten
/// minutes, which is what these are.
class MeditationLibraryScreen extends StatefulWidget {
  /// Optional tag to open pre-filtered, e.g. from a category card.
  final MindTag? initialTag;

  const MeditationLibraryScreen({super.key, this.initialTag});

  @override
  State<MeditationLibraryScreen> createState() =>
      _MeditationLibraryScreenState();
}

class _MeditationLibraryScreenState extends State<MeditationLibraryScreen> {
  late MindTag? _tag = widget.initialTag;

  @override
  Widget build(BuildContext context) {
    final list = _tag == null
        ? MeditationTechniques.all
        : MeditationTechniques.forTag(_tag!);

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'All practices',
                subtitle: '${MeditationTechniques.all.length} ways to sit',
                onBack: () => context.pop(),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4),
                  children: [
                    _chip('All', _tag == null, () => setState(() => _tag = null)),
                    for (final entry in mindTagLabels.entries)
                      _chip(entry.value, _tag == entry.key,
                          () => setState(() => _tag = entry.key)),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                      AppTheme.space4, AppTheme.space8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => TechniqueCard(technique: list[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary.withValues(alpha: 0.2)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: active ? AppTheme.primary : AppTheme.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppTheme.primaryLight : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One technique, as a tappable card. Shared by the library and the home screen.
class TechniqueCard extends StatelessWidget {
  final MeditationTechnique technique;
  const TechniqueCard({super.key, required this.technique});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: GestureDetector(
        onTap: () => context.push('/meditation/technique/${technique.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: technique.gradient),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(technique.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            technique.name,
                            style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: technique.modern
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            technique.modern ? 'MODERN' : 'CLASSIC',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 8.5,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: technique.modern
                                  ? AppTheme.primaryLight
                                  : AppTheme.accentLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      technique.tagline,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${technique.minutes} min  ·  ${technique.bestFor.take(2).map((t) => mindTagLabels[t]).join(', ')}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_outline_rounded,
                  color: AppTheme.textMuted, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
