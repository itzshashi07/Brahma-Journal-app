import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/profile_service.dart';

import '../../services/journal_service.dart';
import '../../models/user_profile.dart';
import '../../core/theme/app_theme.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ProfileService _profileService = ProfileService();
  final JournalService _journalService = JournalService();
  List<_CommunityMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommunity();
    });
  }

  Future<void> _loadCommunity() async {
    setState(() => _isLoading = true);
    final profiles = await _profileService.getAllProfiles();
    final members = await Future.wait(profiles.map((p) async {
      try {
        final streak = await _journalService.calculateStreak(p.uid);
        return _CommunityMember(profile: p, streak: streak, badges: _generateBadges(streak));
      } catch (_) {
        return _CommunityMember(profile: p, streak: 0, badges: []);
      }
    }));
    members.sort((a, b) => b.streak.compareTo(a.streak));
    setState(() { _members = members; _isLoading = false; });
  }

  List<String> _generateBadges(int streak) {
    final badges = <String>[];
    if (streak >= 1) badges.add('First Step');
    if (streak >= 7) badges.add('7-Day Streak');
    if (streak >= 30) badges.add('30-Day Master');
    if (streak >= 100) badges.add('Centurion');
    return badges;
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
                      _HeaderStat(value: '${_members.where((m) => m.streak > 0).length}', label: 'Active Today'),
                      Container(width: 1, height: 40, color: Colors.white30),
                      _HeaderStat(
                        value: _members.isEmpty ? '0' : '${_members.first.streak}',
                        label: 'Top Streak',
                      ),
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
                    const Spacer(),
                    Text('${_members.length} seekers', style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _members.length,
                    itemBuilder: (ctx, i) {
                      final m = _members[i];
                      return _MemberCard(member: m, rank: i + 1);
                    },
                  ),
                ),
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
  _CommunityMember({required this.profile, required this.streak, required this.badges});
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

  const _MemberCard({required this.member, required this.rank});

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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rank <= 3 ? rankColor.withOpacity(0.3) : const Color(0xFF2D2D4E)),
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
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            child: Text(
              member.profile.initials,
              style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.profile.displayName, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14)),
                if (member.badges.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
