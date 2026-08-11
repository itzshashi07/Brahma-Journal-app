import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import 'game_catalog.dart';

/// The Game Zone: every attention game in the app, in one place.
///
/// Reached from the home screen as its own section rather than buried three
/// taps inside meditation, because the person who will actually open a game is
/// usually not the person who came here to sit still.
class GameZoneScreen extends StatefulWidget {
  const GameZoneScreen({super.key});

  @override
  State<GameZoneScreen> createState() => _GameZoneScreenState();
}

class _GameZoneScreenState extends State<GameZoneScreen> {
  GameLane? _lane;

  List<GameEntry> get _visible =>
      _lane == null ? kGames : kGames.where((g) => g.lane == _lane).toList();

  void _surprise() {
    final pool = _visible;
    openGame(context, pool[Random().nextInt(pool.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final games = _visible;

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Game Zone',
                subtitle: '${kGames.length} games · attention, trained sideways',
                onBack: () => context.pop(),
                action: IconButton(
                  tooltip: 'Leaderboard',
                  icon: const Icon(Icons.emoji_events_outlined,
                      color: AppTheme.accentLight, size: 20),
                  onPressed: () => context.push('/games/leaderboard'),
                ),
              ),
              // Lane filter. Four lanes and an all — enough to find something by
              // mood without turning the list into a search problem.
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4),
                  children: [
                    _LaneChip(
                      label: 'All ${kGames.length}',
                      color: AppTheme.primaryLight,
                      selected: _lane == null,
                      onTap: () => setState(() => _lane = null),
                    ),
                    for (final lane in GameLane.values)
                      _LaneChip(
                        label: lane.label,
                        color: lane.color,
                        selected: _lane == lane,
                        onTap: () => setState(() => _lane = lane),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.space4, 0, AppTheme.space4, AppTheme.space8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: Row(
                        children: [
                          Expanded(
                            child: SacredButton(
                              label: 'Surprise me',
                              icon: Icons.casino_rounded,
                              secondary: true,
                              onTap: _surprise,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: SacredButton(
                              label: 'Leaderboard',
                              icon: Icons.emoji_events_outlined,
                              secondary: true,
                              onTap: () => context.push('/games/leaderboard'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final game in games) GameCard(game: game),
                    const SizedBox(height: AppTheme.space2),
                    const GameZoneFootnote(),
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

class _LaneChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LaneChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space2),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4, vertical: AppTheme.space2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.22 : 0.07),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: color.withValues(alpha: selected ? 0.7 : 0.22)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
