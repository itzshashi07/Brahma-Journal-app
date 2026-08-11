import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/meditation_categories.dart';
import '../../core/constants/meditation_techniques.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/meditation_service.dart';
import '../../widgets/sacred.dart';
import 'meditation_library_screen.dart';
import '../games/game_catalog.dart';

/// Choose what you are sitting *for*.
///
/// The timer screen answers "how long"; this answers "why", which is the
/// question that actually gets someone to sit down. Picking a theme carries a
/// suggested duration and a set of visualisations through to the session.
class MeditationCategoriesScreen extends StatefulWidget {
  const MeditationCategoriesScreen({super.key});

  @override
  State<MeditationCategoriesScreen> createState() =>
      _MeditationCategoriesScreenState();
}

class _MeditationCategoriesScreenState
    extends State<MeditationCategoriesScreen> {
  final MeditationService _service = MeditationService();
  int _todaySeconds = 0;
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  /// Practice time is the one number worth putting at the top: it is the only
  /// thing here that is actually evidence.
  Future<void> _loadStats() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final sessions = await _service.getSessions(uid);
    if (!mounted) return;
    setState(() {
      _todaySeconds = _service.todaySeconds(sessions);
      _totalSeconds = _service.totalSeconds(sessions);
    });
  }

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
                                Text('Silent timer, no guidance',
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
                    const SizedBox(height: AppTheme.space3),

                    // Practice minutes, stated plainly.
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Today',
                            value: '${(_todaySeconds / 60).floor()} min',
                            icon: Icons.today_rounded,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space3),
                        Expanded(
                          child: _StatTile(
                            label: 'All time',
                            value: '${(_totalSeconds / 60).floor()} min',
                            icon: Icons.timeline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space5),

                    // The quiz sits above everything else because "which one
                    // should I do" is the question that stops most people.
                    _BigActionCard(
                      title: 'Which meditation suits me?',
                      subtitle: '5 quick questions · nothing is saved',
                      icon: Icons.psychology_alt_outlined,
                      colors: const [Color(0xFF7C3AED), Color(0xFF4338CA)],
                      onTap: () => context.push('/meditation/quiz'),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    _BigActionCard(
                      title: 'Train the mind (games)',
                      subtitle: '${kGames.length} games · focus, memory, logic, calm',
                      icon: Icons.sports_esports_outlined,
                      colors: const [Color(0xFF0EA5E9), Color(0xFF075985)],
                      onTap: () => context.push('/meditation/games'),
                    ),

                    const SizedBox(height: AppTheme.space5),
                    // SectionHeading already carries a trailing action. Wrapping
                    // it in another Row hands its Spacer unbounded width, which
                    // throws during layout and blanks the whole list.
                    SectionHeading(
                      title: 'Ways to meditate',
                      icon: Icons.self_improvement_rounded,
                      trailingLabel: 'See all',
                      onTrailingTap: () => context.push('/meditation/all'),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    ...MeditationTechniques.all
                        .take(5)
                        .map((t) => TechniqueCard(technique: t)),

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


class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4, vertical: AppTheme.space3),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryLight),
          const SizedBox(width: AppTheme.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors.map((c) => c.withValues(alpha: 0.35)).toList(),
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: colors.first.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
