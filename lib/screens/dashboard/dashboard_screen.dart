import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/thoughts_365.dart';
import '../../widgets/sacred.dart';
import '../../widgets/free_access.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/profile_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import '../../services/app_update_service.dart';
import '../../services/profile_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _thoughtOfDay = '';
  bool _showChatbot = false;
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  StreamSubscription? _thoughtSubscription;

  final List<Map<String, dynamic>> _messages = [
    {
      'type': 'bot',
      'message': '🙏 Namaste! I\'m your AI Spiritual Counselor. I\'m here to guide you through life\'s challenges with ancient wisdom and modern psychology.',
    },
    {
      'type': 'bot',
      'message': 'I can help you with stress management, relationship guidance, career decisions, spiritual growth, and emotional healing. How can I support your journey today?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _listenToThought();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _listenToThought() {
    _thoughtSubscription = FirebaseFirestore.instance
        .collection('metadata')
        .doc('thought_of_the_day')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['text'] != null) {
          setState(() {
            _thoughtOfDay = data['text'];
          });
        }
      } else {
        final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1;
        setState(() {
          _thoughtOfDay = Thoughts365.getThoughtForDay(dayOfYear);
        });
      }
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      await context.read<JournalProvider>().loadEntries(auth.user!.uid);
      // Automatically sync profile stats on launch to fix any Firestore mismatches
      ProfileService().syncProfileStats(auth.user!.uid);
    }
    // Check for app update
    _checkForUpdate();
  }

  /// Silent on launch unless there is genuinely something to install — an
  /// update check that interrupts to say "nothing to do" trains people to
  /// dismiss it without reading.
  Future<void> _checkForUpdate() async {
    final release = await AppUpdateService.checkForUpdate();
    if (release != null && mounted) {
      UpdateDialog.show(context, release);
    }
  }

  void _sendMessage() {
    if (_chatCtrl.text.trim().isEmpty) return;
    final userMsg = _chatCtrl.text.trim();
    _chatCtrl.clear();
    setState(() {
      _messages.add({'type': 'user', 'message': userMsg});
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        final response = AppConstants.chatbotResponses[
            Random().nextInt(AppConstants.chatbotResponses.length)];
        setState(() {
          _messages.add({'type': 'bot', 'message': response});
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_chatScrollCtrl.hasClients) {
            _chatScrollCtrl.animateTo(
              _chatScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _thoughtSubscription?.cancel();
    super.dispose();
  }

  void _showEditThoughtDialog() {
    final controller = TextEditingController(text: _thoughtOfDay);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Thought of the Day', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
          decoration: const InputDecoration(hintText: 'Type custom thought...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('metadata').doc('thought_of_the_day').set({
                  'text': text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final journal = context.watch<JournalProvider>();
    final profile = auth.profile;
    final displayName = profile?.displayName ?? auth.user?.email?.split('@').first ?? 'Soul';

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Namaste, $displayName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _getGreeting(),
                                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined, color: AppTheme.textSecondary),
                              onPressed: () => AppUpdateService.shareApp(),
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondary),
                              onPressed: () => context.push('/notifications'),
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.help_outline_outlined, color: AppTheme.textSecondary),
                              onPressed: () => context.push('/support'),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: ProfileAvatar(
                                avatarId: profile?.avatarId,
                                initials: profile?.initials ?? 'S',
                                size: 44,
                                showRing: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(child: _StatCard(
                          icon: Icons.local_fire_department_outlined, label: 'Day Streak',
                          value: '${journal.streak}',
                          color: const Color(0xFFF59E0B),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(
                          icon: Icons.book_outlined, label: 'Total Entries',
                          value: '${journal.entries.length}',
                          color: AppTheme.primary,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(
                          icon: journal.todaysEntry != null ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                          label: "Today's Entry",
                          value: journal.todaysEntry != null ? 'Done' : 'Pending',
                          color: journal.todaysEntry != null ? const Color(0xFF10B981) : const Color(0xFF6B6B8A),
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Free-access countdown — the offer is the headline while
                    // billing is switched off, so it sits above the fold.
                    const FreeAccessBanner(),
                    const SizedBox(height: 20),

                    // Thought of the Day
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Thought of the Day',
                                style: TextStyle(
                                  fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              if (auth.isAdmin) ...[
                                GestureDetector(
                                  onTap: _showEditThoughtDialog,
                                  child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"$_thoughtOfDay"',
                            style: const TextStyle(
                              fontFamily: 'Outfit', fontSize: 17, color: Colors.white,
                              fontStyle: FontStyle.italic, height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Navigation Grid
                    const Text(
                      'Your Journey',
                      style: TextStyle(
                        fontFamily: 'Outfit', fontSize: 21, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _NavCard(icon: Icons.book_outlined, title: 'Journal', subtitle: 'Daily reflection', route: '/journal', color: AppTheme.primary),
                        _NavCard(icon: Icons.spa_outlined, title: 'Meditation', subtitle: 'Find inner peace', route: '/meditation', color: const Color(0xFF0891B2)),
                        _NavCard(icon: Icons.menu_book_outlined, title: 'Gita in Real Life', subtitle: 'Wisdom for your situation', route: '/gita', color: const Color(0xFFF59E0B)),
                        _NavCard(icon: Icons.auto_awesome_outlined, title: 'Affirmations', subtitle: 'Positive mindset', route: '/affirmations', color: const Color(0xFF059669)),
                        _NavCard(icon: Icons.chat_bubble_outline_outlined, title: 'Thoughts', subtitle: 'Share anonymously', route: '/thoughts', color: const Color(0xFFD97706)),
                        _NavCard(icon: Icons.people_outline, title: 'Community', subtitle: 'Fellow seekers', route: '/community', color: const Color(0xFF7C3AED)),
                        _NavCard(icon: Icons.analytics_outlined, title: 'Analytics', subtitle: 'Track progress', route: '/analytics', color: const Color(0xFFDC2626)),
                        _NavCard(icon: Icons.article_outlined, title: 'Sanctuary', subtitle: 'Blogs & Articles', route: '/blogs', color: const Color(0xFFEC4899)),
                        _NavCard(icon: Icons.shopping_bag_outlined, title: 'Library Store', subtitle: 'Books & Resources', route: '/products', color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Chatbot FAB
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _showChatbot = true),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 16, spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(child: Text('🤖', style: TextStyle(fontSize: 24))),
                  ),
                ),
              ),

              // Chatbot Modal
              if (_showChatbot) _buildChatbotModal(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/918078633912');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildChatbotModal() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showChatbot = false),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: Color(0xFF2D2D4E), width: 1.5)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Column(
                      children: [
                        // Drag Handle
                        const SizedBox(height: 12),
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 16),
                        
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient, 
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                    )
                                  ]
                                ),
                                child: const Center(child: Text('🤖', style: TextStyle(fontSize: 22))),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Brahma AI Coach', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary)),
                                  Text('Psychological Analysis', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _showChatbot = false),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFF2D2D4E), height: 24),
                        
                        // Main Scroll Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Coming Soon Banner
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4338CA).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.3)),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🚀 Feature Coming Soon / Under Development',
                                        style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF818CF8), fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'This is an advanced feature which is currently under development. In the future, Brahma AI will analyze your conversation like a real psychiatrist to help track emotional patterns.',
                                        style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Consultation Info Card
                                const Text(
                                  'Urgent Session Needed?',
                                  style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'If you need an urgent session, you can book a 1-to-1 consultation with a qualified mental health psychiatrist right now.',
                                  style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 16),

                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCardLight,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF2D2D4E)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Session Fee',
                                            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 14),
                                          ),
                                          Text(
                                            '₹299 / session',
                                            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.accent, fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Duration',
                                            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 14),
                                          ),
                                          Text(
                                            '30 Minutes',
                                            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(color: Color(0xFF2D2D4E)),
                                      const SizedBox(height: 8),
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'In the session, we provide:',
                                          style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildBulletPoint('One-to-one confidential consultation with a qualified mental health professional.'),
                                      _buildBulletPoint('Personalized emotional assessment based on your concerns and current situation.'),
                                      _buildBulletPoint('Practical coping strategies for stress, anxiety, overthinking, relationship issues, and emotional well-being.'),
                                      _buildBulletPoint('Guidance on improving mental wellness with actionable daily practices.'),
                                      _buildBulletPoint('Opportunity to ask questions and receive personalized recommendations.'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Booking Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() => _showChatbot = false);
                                          context.push('/support');
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppTheme.primary),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text('Fill Form', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.primaryLight, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _launchWhatsApp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                                            SizedBox(width: 6),
                                            Text('Connect Now', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.space4, horizontal: AppTheme.space2),
      child: Column(
        children: [
          // Icon sits in a tinted well rather than floating loose, so the three
          // cards read as a set instead of three unrelated glyphs.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: AppTheme.space3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w800,
              fontSize: 21,
              height: 1.1,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  const _NavCard({required this.icon, required this.title, required this.subtitle, required this.route, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push(route),
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Stack(
        children: [
          // The section's own colour bleeds in from the corner, so eight cards
          // in a grid stay distinguishable at a glance instead of reading as
          // one undifferentiated block.
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Wide and low-opacity with an intermediate stop: a tight,
                // strong radial clipped by the card corner reads as a pasted
                // square rather than as light falling across the surface.
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.20),
                    color.withValues(alpha: 0.06),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Center(child: Icon(icon, size: 21, color: color)),
              ),
              const SizedBox(height: AppTheme.space3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
