import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sacred.dart';
import '../games/game_catalog.dart';

/// Attention training, as games.
///
/// Two honest claims and no more. These train the thing meditation also trains
/// — noticing that attention has moved and bringing it back — with a scoreboard
/// instead of silence, which is the only version some people will open. They
/// are not meditation, they are counted separately, and nobody should expect a
/// puzzle to do what sitting does.
///
/// The games themselves live in screens/games and are shared with the Game
/// Zone on the home screen; this screen is the meditation section's door into
/// them, grouped by what each one trains.
class MindGamesScreen extends StatelessWidget {
  const MindGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Train the Mind',
                subtitle: '${kGames.length} short games. Real attention.',
                onBack: () => context.pop(),
                action: IconButton(
                  tooltip: 'Game Zone',
                  icon: const Icon(Icons.sports_esports_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: () => context.push('/games'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.space4, 0, AppTheme.space4, AppTheme.space8),
                  children: [
                    for (final lane in GameLane.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppTheme.space2, bottom: AppTheme.space3),
                        child: SectionHeading(
                          title: _laneTitle(lane),
                          icon: _laneIcon(lane),
                        ),
                      ),
                      for (final game in kGames.where((g) => g.lane == lane))
                        GameCard(game: game),
                    ],
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

  static String _laneTitle(GameLane lane) => switch (lane) {
        GameLane.focus => 'Focus — holding attention still',
        GameLane.memory => 'Memory — holding something in mind',
        GameLane.logic => 'Logic — thinking under pressure',
        GameLane.calm => 'Calm — closest to practice',
      };

  static IconData _laneIcon(GameLane lane) => switch (lane) {
        GameLane.focus => Icons.center_focus_strong_rounded,
        GameLane.memory => Icons.psychology_outlined,
        GameLane.logic => Icons.extension_outlined,
        GameLane.calm => Icons.spa_outlined,
      };
}
