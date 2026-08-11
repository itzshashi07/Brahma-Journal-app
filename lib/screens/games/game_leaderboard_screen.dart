import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_stats_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/sacred.dart';
import 'game_catalog.dart';

/// Who is fastest, sharpest and most stubborn — per game.
///
/// One board per game rather than a single combined ranking: the games measure
/// different things in different units, and a combined score would be an
/// invented number dressed up as a fact. The only cross-game board is Overall,
/// which ranks time spent training, because seconds are the one quantity every
/// game genuinely shares.
class GameLeaderboardScreen extends StatefulWidget {
  final String? initialGameId;

  const GameLeaderboardScreen({super.key, this.initialGameId});

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  final GameStatsService _stats = GameStatsService();

  late String _gameId;
  List<GameScoreRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _gameId = widget.initialGameId ?? GameStatsService.overallId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool get _isOverall => _gameId == GameStatsService.overallId;

  Future<void> _load() async {
    setState(() => _loading = true);
    final game = gameById(_gameId);
    final rows = await _stats.top(
      _gameId,
      // Overall ranks total seconds trained, so more is better there even
      // though most of the individual boards that measure time rank ascending.
      lowerIsBetter: _isOverall ? false : (game?.lowerIsBetter ?? false),
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _select(String id) {
    if (_gameId == id) return;
    setState(() => _gameId = id);
    _load();
  }

  String _format(GameScoreRow row) {
    if (_isOverall) return formatTrainingTime(row.score);
    return gameById(_gameId)?.formatScore(row.score) ?? '${row.score}';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.watch<AuthProvider>().user?.uid;
    final game = gameById(_gameId);

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Leaderboard',
                subtitle: _isOverall
                    ? 'Overall · total time trained'
                    : '${game?.title ?? _gameId} · '
                        '${game?.lowerIsBetter == true ? 'lower is better' : 'higher is better'}',
                onBack: () => context.pop(),
                action: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: _load,
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                  children: [
                    _Chip(
                      label: 'Overall',
                      color: AppTheme.accent,
                      selected: _isOverall,
                      onTap: () => _select(GameStatsService.overallId),
                    ),
                    for (final g in kGames)
                      _Chip(
                        label: g.title,
                        color: g.lane.color,
                        selected: _gameId == g.id,
                        onTap: () => _select(g.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2))
                    : _rows.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.bgCard,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  AppTheme.space4,
                                  0,
                                  AppTheme.space4,
                                  AppTheme.space8),
                              itemCount: _rows.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _rows.length) return _footnote();
                                final row = _rows[i];
                                return _Row(
                                  rank: i + 1,
                                  row: row,
                                  value: _format(row),
                                  isMe: row.uid == myUid,
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 44, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.space3),
            Text(
              _isOverall
                  ? 'Nobody has played yet.'
                  : 'No scores on ${gameById(_gameId)?.title ?? 'this game'} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: AppTheme.space2),
            const Text(
              'Play a round and the first name on the board is yours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.space4),
            SacredButton(
              label: 'Open Game Zone',
              icon: Icons.sports_esports_outlined,
              secondary: true,
              expand: false,
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footnote() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space4),
      child: Text(
        _isOverall
            ? 'Overall ranks the seconds you actually spent training, banked as '
                'you play. It is the one number every game shares.'
            : 'Only your best run is published — playing more does not move you '
                'up, playing better does.',
        style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11.5,
            height: 1.5,
            color: AppTheme.textMuted),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final GameScoreRow row;
  final String value;
  final bool isMe;

  const _Row({
    required this.rank,
    required this.row,
    required this.value,
    required this.isMe,
  });

  static const _medals = {1: Color(0xFFFBBF24), 2: Color(0xFF94A3B8), 3: Color(0xFFB45309)};

  @override
  Widget build(BuildContext context) {
    final medal = _medals[rank];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: GlassCard(
        highlighted: isMe,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space3, vertical: AppTheme.space3),
        radius: AppTheme.radiusMd,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: medal != null ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: medal ?? AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            ProfileAvatar(
              avatarId: row.avatarId,
              initials: row.displayName.isEmpty
                  ? 'S'
                  : row.displayName.substring(0, 1).toUpperCase(),
              size: 34,
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${row.displayName}  (you)' : row.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isMe ? AppTheme.primaryLight : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${row.plays} ${row.plays == 1 ? 'run' : 'runs'}',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
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
