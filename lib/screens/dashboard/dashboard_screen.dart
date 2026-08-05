import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/thoughts_365.dart';
import 'dart:math';

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
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1;
    _thoughtOfDay = Thoughts365.getThoughtForDay(dayOfYear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      await context.read<JournalProvider>().loadEntries(auth.user!.uid);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final journal = context.watch<JournalProvider>();
    final profile = auth.profile;
    final displayName = profile?.displayName ?? auth.user?.email?.split('@').first ?? 'Soul';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
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
                                  fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _getGreeting(),
                                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.help_outline_outlined, color: AppTheme.textSecondary),
                              onPressed: () => context.push('/support'),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primary.withOpacity(0.2),
                                child: Text(
                                  profile?.initials ?? 'S',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit', color: AppTheme.primary, fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Thought of the Day',
                                style: TextStyle(
                                  fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"$_thoughtOfDay"',
                            style: const TextStyle(
                              fontFamily: 'Outfit', fontSize: 15, color: Colors.white,
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
                        fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600,
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
                        _NavCard(icon: Icons.auto_awesome_outlined, title: 'Affirmations', subtitle: 'Positive mindset', route: '/affirmations', color: const Color(0xFF059669)),
                        _NavCard(icon: Icons.chat_bubble_outline_outlined, title: 'Thoughts', subtitle: 'Share anonymously', route: '/thoughts', color: const Color(0xFFD97706)),
                        _NavCard(icon: Icons.people_outline, title: 'Community', subtitle: 'Fellow seekers', route: '/community', color: const Color(0xFF7C3AED)),
                        _NavCard(icon: Icons.analytics_outlined, title: 'Analytics', subtitle: 'Track progress', route: '/analytics', color: const Color(0xFFDC2626)),
                        _NavCard(icon: Icons.article_outlined, title: 'Sanctuary', subtitle: 'Blogs & Articles', route: '/blogs', color: const Color(0xFFEC4899)),
                        _NavCard(icon: Icons.shopping_bag_outlined, title: 'Library Store', subtitle: 'Books & Resources', route: '/products', color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 80),
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

  Widget _buildChatbotModal() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showChatbot = false),
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: const BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Spiritual Counselor', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              Text('Here to guide your journey', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
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
                    const Divider(color: Color(0xFF2D2D4E)),
                    // Messages
                    Expanded(
                      child: ListView.builder(
                        controller: _chatScrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isBot = msg['type'] == 'bot';
                          return Align(
                            alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isBot ? AppTheme.bgCardLight : AppTheme.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                msg['message'],
                                style: TextStyle(
                                  fontFamily: 'Outfit', fontSize: 14,
                                  color: isBot ? AppTheme.textPrimary : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Input
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts...',
                                hintStyle: const TextStyle(color: AppTheme.textMuted, fontFamily: 'Outfit'),
                                filled: true,
                                fillColor: AppTheme.bgCardLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted), textAlign: TextAlign.center),
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
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2D4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Icon(icon, size: 18, color: color)),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
