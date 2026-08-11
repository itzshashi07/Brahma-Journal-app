import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../services/meditation_service.dart';
import '../../services/game_stats_service.dart';
import '../../widgets/craft_consistency_card.dart';
import '../games/game_catalog.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final MeditationService _meditationService = MeditationService();
  final FocusService _focusService = FocusService();
  final GameStatsService _gameStats = GameStatsService();
  List<Map<String, dynamic>> _meditationSessions = [];
  bool _loadingMeditation = true;

  /// Game Zone data, kept separate from meditation throughout — same reason the
  /// sessions live in a different collection. A puzzle is not practice.
  List<FocusSession> _focusSessions = [];
  Map<String, GameScoreRow> _gameBests = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) {
      // Otherwise the meditation cards spin forever for a signed-out user.
      setState(() => _loadingMeditation = false);
      return;
    }

    await context.read<JournalProvider>().loadEntries(uid);
    final sessions = await _meditationService.getSessions(uid);
    // Fired together: three independent reads, and doing them in sequence made
    // the screen spin for as long as the slowest one plus the other two.
    final results = await Future.wait([
      _focusService.sessions(uid),
      _gameStats.myRows(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _meditationSessions = sessions;
      _focusSessions = results[0] as List<FocusSession>;
      _gameBests = results[1] as Map<String, GameScoreRow>;
      _loadingMeditation = false;
    });
  }

  List<FlSpot> _getMoodSpots(List<JournalEntry> entries) {
    final last7 = entries.take(7).toList().reversed.toList();
    return last7.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.mood.toDouble())).toList();
  }

  Color _getMoodColor(double mood) {
    if (mood <= 1) return AppTheme.moodVerySad;
    if (mood <= 2) return AppTheme.moodSad;
    if (mood <= 3) return AppTheme.moodNeutral;
    if (mood <= 4) return AppTheme.moodHappy;
    return AppTheme.moodVeryHappy;
  }

  double _getAverageMood(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    final sum = entries.fold(0, (acc, e) => acc + e.mood);
    return sum / entries.length;
  }

  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReportAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // Small delay to ensure render is stable
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/innenflow_report.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My InnenFlow Progress Report 📈',
        );
      }
    } catch (e) {
      print('❌ Error sharing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final entries = journal.entries;
    final avgMood = _getAverageMood(entries);
    final moodSpots = entries.isNotEmpty ? _getMoodSpots(entries) : <FlSpot>[];

    final totalSeconds = _meditationService.totalSeconds(_meditationSessions);
    final todaySeconds = _meditationService.todaySeconds(_meditationSessions);

    // Game Zone figures. Time comes from the banked sessions (what was
    // actually spent), the best scores from the published rows (what was
    // actually achieved) — two different questions, two different sources.
    final gameSeconds =
        _focusSessions.fold<int>(0, (acc, s) => acc + s.seconds);
    final perGameSeconds = <String, int>{};
    for (final session in _focusSessions) {
      perGameSeconds[session.game] =
          (perGameSeconds[session.game] ?? 0) + session.seconds;
    }
    final playedGames = kGames
        .where((g) =>
            perGameSeconds.containsKey(g.id) || _gameBests.containsKey(g.id))
        .toList()
      ..sort((a, b) =>
          (perGameSeconds[b.id] ?? 0).compareTo(perGameSeconds[a.id] ?? 0));

    final totalMinStr = (totalSeconds / 60).toStringAsFixed(1) + "m";
    final todayStr = todaySeconds > 0
        ? "${(todaySeconds ~/ 60)}m ${todaySeconds % 60}s"
        : "0m 0s";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20), onPressed: () => context.pop()),
                    const Expanded(child: Text('📊 Analytics', style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center)),
                    _isSharing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                        : IconButton(
                            icon: const Icon(Icons.share, color: AppTheme.primary),
                            onPressed: _shareReportAsImage,
                          ),
                  ],
                ),
              ),

              // Wait for the meditation sessions too — rendering early showed a
              // real streak next to 0.0m of meditation, which reads as wrong
              // data rather than as "still loading".
              if (journal.loading || _loadingMeditation)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                         RepaintBoundary(
                          key: _boundaryKey,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF13132B), Color(0xFF1E1E3F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF2D2D4E)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.spa_outlined, size: 18, color: AppTheme.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      'Progress Report',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats Grid
                                Row(
                                  children: [
                                    Expanded(child: _AnalyticCard(icon: Icons.book_outlined, value: '${entries.length}', label: 'Total Entries', color: AppTheme.primary)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _AnalyticCard(icon: Icons.local_fire_department_outlined, value: '${journal.streak}', label: 'Current Streak', color: const Color(0xFFF59E0B))),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _AnalyticCard(
                                      icon: _getMoodIcon(avgMood),
                                      value: avgMood > 0 ? avgMood.toStringAsFixed(1) : '-',
                                      label: 'Avg Mood',
                                      color: _getMoodColor(avgMood),
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(child: _AnalyticCard(
                                      icon: Icons.calendar_month_outlined,
                                      value: entries.isNotEmpty ? '${_getMonthCount(entries)}' : '0',
                                      label: 'This Month',
                                      color: const Color(0xFF10B981),
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _AnalyticCard(
                                      icon: Icons.spa_outlined,
                                      value: totalMinStr,
                                      label: 'Total Meditation',
                                      color: const Color(0xFF0891B2),
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(child: _AnalyticCard(
                                      icon: Icons.timer_outlined,
                                      value: todayStr,
                                      label: "Today's Meditation",
                                      color: const Color(0xFF06D6A0),
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _AnalyticCard(
                                      icon: Icons.sports_esports_outlined,
                                      value: formatTrainingTime(gameSeconds),
                                      label: 'Game Zone Time',
                                      color: const Color(0xFF8B5CF6),
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(child: _AnalyticCard(
                                      icon: Icons.videogame_asset_outlined,
                                      value: '${playedGames.length}/${kGames.length}',
                                      label: 'Games Played',
                                      color: const Color(0xFFF59E0B),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mood Chart
                        if (moodSpots.length >= 2) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2D2D4E)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mood Trend (Last 7 Days)', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15)),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 180,
                                  child: LineChart(
                                    LineChartData(
                                      minY: 1, maxY: 5,
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFF2D2D4E), strokeWidth: 1),
                                      ),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 1,
                                            getTitlesWidget: (v, _) {
                                              final labels = {1: 'Rst', 2: 'Hvy', 3: 'Neu', 4: 'Clm', 5: 'Joy'};
                                              return Text(labels[v.toInt()] ?? '', style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 10));
                                            },
                                            reservedSize: 32,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: moodSpots,
                                          isCurved: true,
                                          color: AppTheme.primary,
                                          barWidth: 3,
                                          dotData: FlDotData(
                                            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                              radius: 5,
                                              color: _getMoodColor(spot.y),
                                              strokeWidth: 2,
                                              strokeColor: Colors.white,
                                            ),
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppTheme.primary.withOpacity(0.1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Are you actually doing the work? The one question
                        // mood charts and meditation minutes cannot answer.
                        CraftConsistencyCard(entries: entries),
                        const SizedBox(height: 24),

                        // Game Zone breakdown
                        Row(
                          children: [
                            const Text('Game Zone',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => context.push('/games/leaderboard'),
                              child: const Row(
                                children: [
                                  Icon(Icons.emoji_events_outlined, size: 15, color: AppTheme.accentLight),
                                  SizedBox(width: 4),
                                  Text('Leaderboard',
                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.accentLight)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (playedGames.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF2D2D4E)),
                            ),
                            child: GestureDetector(
                              onTap: () => context.push('/games'),
                              child: const Text(
                                'No games played yet. The Game Zone tracks time and best score per game, separately from your meditation minutes.',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ...playedGames.map((g) => _GameStatTile(
                                game: g,
                                seconds: perGameSeconds[g.id] ?? 0,
                                best: _gameBests[g.id]?.score,
                                plays: _gameBests[g.id]?.plays ?? 0,
                              )),
                        const SizedBox(height: 20),

                        // Recent Entries
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Recent Entries', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                        const SizedBox(height: 12),
                        ...entries.take(10).map((e) => _EntryTile(entry: e)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMoodIcon(double mood) {
    if (mood <= 0) return Icons.sentiment_neutral_outlined;
    if (mood <= 1.5) return Icons.sentiment_very_dissatisfied_outlined;
    if (mood <= 2.5) return Icons.sentiment_dissatisfied_outlined;
    if (mood <= 3.5) return Icons.sentiment_neutral_outlined;
    if (mood <= 4.5) return Icons.sentiment_satisfied_outlined;
    return Icons.sentiment_very_satisfied_outlined;
  }

  int _getMonthCount(List<JournalEntry> entries) {
    final now = DateTime.now();
    return entries.where((e) => e.createdAt.month == now.month && e.createdAt.year == now.year).length;
  }
}

class _AnalyticCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AnalyticCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

/// One game's line in Analytics: best score, time spent, runs.
///
/// Best and time are deliberately both shown. Time alone rewards grinding, and
/// a best alone hides that it took forty attempts.
class _GameStatTile extends StatelessWidget {
  final GameEntry game;
  final int seconds;
  final int? best;
  final int plays;

  const _GameStatTile({
    required this.game,
    required this.seconds,
    required this.best,
    required this.plays,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/games/leaderboard?game=${game.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D4E)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: game.colors),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(game.icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  Text(
                    '${formatTrainingTime(seconds)} played'
                    '${plays > 0 ? '  ·  $plays ${plays == 1 ? 'run' : 'runs'}' : ''}',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  best == null ? '—' : game.formatScore(best!),
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentLight),
                ),
                const Text('best',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final JournalEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final moodColors = {
      1: const Color(0xFFEF4444),
      2: const Color(0xFFF59E0B),
      3: const Color(0xFF6B7280),
      4: const Color(0xFF3B82F6),
      5: const Color(0xFF10B981),
    };
    final moodLabels = {
      1: 'Restless',
      2: 'Heavy',
      3: 'Neutral',
      4: 'Calm',
      5: 'Joyful',
    };
    final color = moodColors[entry.mood] ?? const Color(0xFF6B7280);
    final label = moodLabels[entry.mood] ?? 'Neutral';

    return GestureDetector(
      onTap: () => context.push('/journal', extra: entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D4E)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                label,
                style: TextStyle(fontFamily: 'Outfit', color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppDateUtils.formatDate(entry.createdAt), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14)),
                  if (entry.bestMoment.isNotEmpty)
                    Text(entry.bestMoment, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
