import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/profile_service.dart';

import '../../models/user_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/stats_utils.dart';
import '../../widgets/profile_avatar.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/community_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ProfileService _profileService = ProfileService();
  List<_CommunityMember> _members = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUid;
  bool _rebuilding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunity();
    });
  }

  Future<void> _loadCommunity() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    _currentUid = auth.user?.uid;

    try {
      // Recompute the signed-in member's stats first so their own row is right
      // the moment the board renders. Other members' numbers are refreshed by
      // their own devices — the leaderboard only ever reads them here.
      if (_currentUid != null) {
        await _profileService.syncProfileStats(_currentUid!);
      }

      final profiles = await _profileService.getLeaderboard();
      final members = profiles.map(_toMember).toList()..sort(_byStreak);

      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the leaderboard. Check your connection and try again.';
        _isLoading = false;
      });
      print('❌ Community load failed: $e');
    }
  }

  _CommunityMember _toMember(UserProfile p) => _CommunityMember(
        profile: p,
        // currentStreak, not the raw stored value: a member who stopped
        // practising can't rewrite their own profile from here, so their streak
        // is aged out on read instead of freezing at the top of the board.
        streak: p.currentStreak,
        // Badges come off the best streak ever reached — an earned milestone
        // shouldn't vanish the first day someone misses.
        badges: _generateBadges(
          p.longestStreak > p.currentStreak ? p.longestStreak : p.currentStreak,
        ),
        totalMeditationSeconds: p.totalMeditationSeconds,
        totalJournalEntries: p.totalJournalEntries,
        isActiveToday: p.isActiveToday,
      );

  /// Rank by streak, then by the practice behind it.
  int _byStreak(_CommunityMember a, _CommunityMember b) {
    final streakCmp = b.streak.compareTo(a.streak);
    if (streakCmp != 0) return streakCmp;
    final medCmp = b.totalMeditationSeconds.compareTo(a.totalMeditationSeconds);
    if (medCmp != 0) return medCmp;
    final entryCmp = b.totalJournalEntries.compareTo(a.totalJournalEntries);
    if (entryCmp != 0) return entryCmp;
    // Stable last resort so ranks don't shuffle between refreshes.
    return a.profile.displayName.toLowerCase().compareTo(b.profile.displayName.toLowerCase());
  }

  int get _topStreak => _members.isEmpty ? 0 : _members.first.streak;
  int get _activeToday => _members.where((m) => m.isActiveToday).length;

  /// Admin-only: repopulate the board from every member's profile.
  ///
  /// Rows are normally written by their owner's device, so anyone who has not
  /// opened the app since the leaderboard was introduced is missing from it.
  /// This pulls them all in at once.
  Future<void> _rebuildLeaderboard() async {
    setState(() => _rebuilding = true);
    try {
      final count = await _profileService.rebuildLeaderboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leaderboard rebuilt — $count members',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
        ),
      );
      await _loadCommunity();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not rebuild the leaderboard.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  /// Highest milestone first — the card only has room for two, and a Centurion
  /// showing off "First Step" was not the intent.
  List<String> _generateBadges(int streak) {
    final badges = <String>[];
    if (streak >= 100) badges.add('Centurion');
    if (streak >= 30) badges.add('30-Day Master');
    if (streak >= 7) badges.add('7-Day Streak');
    if (streak >= 1) badges.add('First Step');
    return badges;
  }

  void _shareLeaderboard() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || _members.isEmpty) return;

    final topMember = _members.first;
    final topStreak = topMember.streak;

    final content = '🏆 *Spiritual Leaderboard Celebration!* 🌟\n'
        '- Top Streak seeker: ${topMember.profile.displayName} with $topStreak days! 🔥\n'
        '- Seekers practising today: $_activeToday of ${_members.length} 🙏\n'
        '- Keep logging your reflections and finding quiet moments. We are in this together! ✨';

    try {
      await CommunityService().saveAnonymousThought(content, auth.user!.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leaderboard shared to Community feed! 🏆', style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share the leaderboard. Please try again.', style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      print('❌ Share leaderboard failed: $e');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_error != null) {
      return _CommunityMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Leaderboard unavailable',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _loadCommunity,
      );
    }

    if (_members.isEmpty) {
      return _CommunityMessage(
        icon: Icons.groups_outlined,
        title: 'No seekers yet',
        message: 'Write your first reflection to open the leaderboard.',
        actionLabel: 'Refresh',
        onAction: _loadCommunity,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCommunity,
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _members.length,
        itemBuilder: (ctx, i) {
          final m = _members[i];
          return _MemberCard(
            member: m,
            rank: i + 1,
            isCurrentUser: m.profile.uid == _currentUid,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    const Expanded(
                      child: Text('Community', style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                    ),
                    if (context.watch<AuthProvider>().isAdmin)
                      IconButton(
                        tooltip: 'Rebuild leaderboard',
                        icon: _rebuilding
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary))
                            : const Icon(Icons.sync, color: AppTheme.primary),
                        onPressed: _rebuilding ? null : _rebuildLeaderboard,
                      ),
                    IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textMuted), onPressed: _loadCommunity),
                  ],
                ),
              ),

              // Header Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4338CA), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _HeaderStat(value: '${_members.length}', label: 'Members'),
                      Container(width: 1, height: 40, color: Colors.white30),
                      // Active today means they actually journalled or
                      // meditated today — a live streak from yesterday isn't
                      // the same thing.
                      _HeaderStat(value: '$_activeToday', label: 'Active Today'),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _HeaderStat(value: '$_topStreak', label: 'Top Streak'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Leaderboard
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Leaderboard', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18, color: AppTheme.primary),
                      onPressed: _shareLeaderboard,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    Text('${_members.length} seekers', style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityMember {
  final UserProfile profile;
  final int streak;
  final List<String> badges;
  final int totalMeditationSeconds;
  final int totalJournalEntries;
  final bool isActiveToday;
  _CommunityMember({
    required this.profile,
    required this.streak,
    required this.badges,
    required this.totalMeditationSeconds,
    required this.totalJournalEntries,
    required this.isActiveToday,
  });
}

class _CommunityMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _CommunityMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
              label: Text(
                actionLabel,
                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final _CommunityMember member;
  final int rank;
  final bool isCurrentUser;

  const _MemberCard({required this.member, required this.rank, this.isCurrentUser = false});

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    String rankText;
    if (rank == 1) { rankColor = const Color(0xFFF59E0B); rankText = '1st'; }
    else if (rank == 2) { rankColor = const Color(0xFF94A3B8); rankText = '2nd'; }
    else if (rank == 3) { rankColor = const Color(0xFFCD7C33); rankText = '3rd'; }
    else { rankColor = AppTheme.textMuted; rankText = '#$rank'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.primary.withOpacity(0.08) : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primary.withOpacity(0.5)
              : (rank <= 3 ? rankColor.withOpacity(0.3) : const Color(0xFF2D2D4E)),
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                rankText,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: rankColor,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          ProfileAvatar(
            avatarId: member.profile.avatarId,
            initials: member.profile.initials,
            size: 40,
            showRing: rank <= 3,
            ringColor: rankColor,
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('You', style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                    ],
                    if (member.isActiveToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.spa_outlined, size: 12, color: Color(0xFF0891B2)),
                    const SizedBox(width: 4),
                    Text(
                      // formatDurationShort keeps short practices visible —
                      // everything under 6 minutes used to render as "0.0h".
                      formatDurationShort(member.totalMeditationSeconds),
                      style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.book_outlined, size: 12, color: AppTheme.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${member.totalJournalEntries}',
                      style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                if (member.badges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: member.badges.take(2).map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        b,
                        style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_outlined, size: 18, color: rankColor),
                  const SizedBox(width: 2),
                  Text('${member.streak}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: rankColor)),
                ],
              ),
              const Text('day streak', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
