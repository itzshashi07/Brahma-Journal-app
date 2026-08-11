import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_stats_service.dart';
import '../../services/meditation_service.dart';
import '../../widgets/sacred.dart';
import 'game_hints.dart';

/// The pieces every game in the Game Zone is built from.
///
/// Fifteen games written independently would drift into fifteen slightly
/// different scoreboards, back buttons and best-score keys. They share this
/// instead: one session recorder, one shell, one result panel.

/// Banks time into focus_sessions and remembers a personal best per game.
///
/// Time is banked under the game's own id and lands in focus_sessions, never
/// meditation_sessions — a puzzle is not sitting still, and mixing the two
/// numbers would only flatter the person reading them.
mixin GameSession<T extends StatefulWidget> on State<T> {
  final FocusService _focus = FocusService();
  final GameStatsService _stats = GameStatsService();
  DateTime? _startedAt;
  String? _uid;
  String _displayName = 'Friend';
  String? _avatarId;

  String get gameId;
  String get bestKey => 'focus_best_$gameId';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _uid ??= auth.user?.uid;
    // Captured here rather than read at write time: the write can land after
    // the widget is disposed, and reading a provider off a dead context throws.
    final profile = auth.profile;
    _displayName = profile?.displayName ??
        auth.user?.email?.split('@').first ??
        'Friend';
    _avatarId = profile?.avatarId;
    _startedAt ??= DateTime.now();
  }

  Future<void> bankTime() async {
    final start = _startedAt;
    final uid = _uid;
    if (start == null || uid == null) return;
    final seconds = DateTime.now().difference(start).inSeconds;
    _startedAt = DateTime.now();
    if (seconds <= 2) return;
    await _focus.saveSession(uid, seconds, gameId);
    // The overall board ranks time trained, so it accrues from banked seconds
    // rather than from finishing a run — quitting halfway still counts the
    // minutes that were actually spent.
    await _stats.addTrainingTime(
      uid: uid,
      seconds: seconds,
      displayName: _displayName,
      avatarId: _avatarId,
    );
  }

  Future<int?> readBest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(bestKey);
  }

  Future<void> writeBest(int value, {bool lowerIsBetter = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(bestKey);
    final better =
        current == null || (lowerIsBetter ? value < current : value > current);
    if (better) await prefs.setInt(bestKey, value);
  }

  /// Writes the score, publishes it to the leaderboard, re-reads the stored
  /// best and hands it back — the pattern every game repeated by hand, usually
  /// with a mounted check missing.
  ///
  /// The local best is written first and never depends on the network: someone
  /// playing on a train should still see their own record move.
  Future<int?> submitScore(int value, {bool lowerIsBetter = true}) async {
    await writeBest(value, lowerIsBetter: lowerIsBetter);
    await bankTime();
    final uid = _uid;
    if (uid != null) {
      await _stats.publishScore(
        uid: uid,
        gameId: gameId,
        score: value,
        lowerIsBetter: lowerIsBetter,
        displayName: _displayName,
        avatarId: _avatarId,
      );
    }
    final best = await readBest();
    return mounted ? best : null;
  }
}

/// Standard frame: backdrop, header, body, optional footer.
class GameShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? best;
  final Widget body;
  final Widget? footer;

  /// Passing this puts a lightbulb in the header carrying that game's strategy
  /// tips. Someone who keeps losing has no way, otherwise, to tell whether they
  /// are unlucky or playing it wrong — and that is when people stop playing.
  final String? hintsForGame;

  const GameShell({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.best,
    this.footer,
    this.hintsForGame,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: title,
                subtitle: subtitle,
                onBack: () => Navigator.of(context).pop(),
                action: hintsForGame == null
                    ? null
                    : GameHintButton(gameId: hintsForGame!, title: title),
              ),
              if (best != null)
                Text(
                  best!,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppTheme.textMuted),
                ),
              Expanded(child: body),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.space4,
                      AppTheme.space2, AppTheme.space4, AppTheme.space5),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// End-of-run panel. Same shape everywhere so a result always reads the same
/// way: what happened, the number, the best, one button.
class GameResult extends StatelessWidget {
  final String headline;
  final String detail;
  final String? best;
  final VoidCallback onRestart;
  final String restartLabel;

  /// Offers the strategy sheet from the end of a run. A result screen that
  /// gives a number and nothing else is where a discouraged player leaves.
  final String? hintsForGame;
  final String? gameTitle;

  const GameResult({
    super.key,
    required this.headline,
    required this.detail,
    required this.onRestart,
    this.best,
    this.restartLabel = 'Play again',
    this.hintsForGame,
    this.gameTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space2),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary)),
              if (best != null) ...[
                const SizedBox(height: AppTheme.space2),
                Text(best!,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.accentLight)),
              ],
              const SizedBox(height: AppTheme.space4),
              SacredButton(label: restartLabel, onTap: onRestart),
              if (hintsForGame != null && GameHints.has(hintsForGame!)) ...[
                const SizedBox(height: AppTheme.space2),
                TextButton.icon(
                  onPressed: () => showHints(
                      context, hintsForGame!, gameTitle ?? 'this game'),
                  icon: const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: AppTheme.accentLight),
                  label: const Text(
                    'Show me how to do better',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AppTheme.accentLight),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of small labelled numbers — score, lives, round, timer.
class GameStats extends StatelessWidget {
  final List<(String, String)> items;

  const GameStats(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (label, value) in items)
            Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: AppTheme.textMuted)),
              ],
            ),
        ],
      ),
    );
  }
}

/// A countdown drawn as a thinning bar. Games that use a per-round clock all
/// used to draw their own; this one is driven by a 0–1 value.
class GameTimerBar extends StatelessWidget {
  final double value;
  final Color color;

  const GameTimerBar({super.key, required this.value, this.color = AppTheme.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(
              value < 0.3 ? const Color(0xFFEF4444) : color),
        ),
      ),
    );
  }
}

/// A tappable answer tile — used by every multiple-choice game.
class GameChoice extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final double height;

  const GameChoice({
    super.key,
    required this.child,
    required this.onTap,
    this.color = AppTheme.primary,
    this.filled = false,
    this.height = 62,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.45)),
        ),
        child: Center(child: child),
      ),
    );
  }
}
