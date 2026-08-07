import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/meditation_categories.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';

/// Choose what you are sitting *for*.
///
/// The timer screen answers "how long"; this answers "why", which is the
/// question that actually gets someone to sit down. Picking a theme carries a
/// suggested duration and a set of visualisations through to the session.
class MeditationCategoriesScreen extends StatelessWidget {
  const MeditationCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Meditation',
                subtitle: 'What do you need today?',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                      AppTheme.space4, AppTheme.space8),
                  children: [
                    GlassCard(
                      onTap: () => context.push('/meditation/session'),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: const Icon(Icons.timer_outlined,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: AppTheme.space3),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Just sit',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    )),
                                Text('Open timer, no theme',
                                    style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 13, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    const SectionHeading(
                        title: 'Guided themes',
                        icon: Icons.auto_awesome_rounded),
                    const SizedBox(height: AppTheme.space3),
                    ...MeditationCategories.all.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space3),
                        child: _CategoryCard(category: c),
                      ),
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

class _CategoryCard extends StatelessWidget {
  final MeditationCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/meditation/theme/${category.id}'),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: category.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(category.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  category.tagline,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppTheme.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  '${category.thoughts.length} practices · ${category.suggestedMinutes} min',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: category.gradient.first,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

/// A theme's visualisations, with a button through to the timer.
class MeditationThemeScreen extends StatelessWidget {
  final String categoryId;
  const MeditationThemeScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final c = MeditationCategories.byId(categoryId);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Unknown theme')));
    }

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: c.name,
                subtitle: c.tagline,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                      AppTheme.space4, AppTheme.space6),
                  children: [
                    ...c.thoughts.asMap().entries.map(
                          (e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppTheme.space3),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                              colors: c.gradient),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${e.key + 1}',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.space2 + 2),
                                      Expanded(
                                        child: Text(
                                          e.value.title,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.space3),
                                  Text(
                                    e.value.guidance,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13.5,
                                      height: 1.65,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.space5, 0,
                    AppTheme.space5, AppTheme.space5),
                child: SacredButton(
                  label: 'Begin ${c.suggestedMinutes} minute session',
                  icon: Icons.self_improvement_rounded,
                  onTap: () => context.push(
                      '/meditation/session?minutes=${c.suggestedMinutes}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
