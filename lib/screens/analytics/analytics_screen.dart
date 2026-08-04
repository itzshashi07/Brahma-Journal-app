import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      await context.read<JournalProvider>().loadEntries(auth.user!.uid);
    }
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

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final entries = journal.entries;
    final avgMood = _getAverageMood(entries);
    final moodSpots = entries.isNotEmpty ? _getMoodSpots(entries) : <FlSpot>[];

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
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              if (journal.loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
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
