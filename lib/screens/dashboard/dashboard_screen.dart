import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/thoughts_365.dart';
import '../../core/utils/stats_utils.dart';
import '../../widgets/sacred.dart';
import '../../widgets/free_access.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/welcome_celebration.dart';
import '../../widgets/thought_banner.dart';
import '../../widgets/quick_prompt.dart';
import '../checkin/daily_checkin_sheet.dart';
import 'thought_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/profile_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../services/api_service.dart';
import '../../models/counselling_session.dart';
import '../../services/app_update_service.dart';
import '../../services/counselling_service.dart';
import '../../services/notification_center.dart';
import '../../services/profile_service.dart';
import '../../services/streak_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  String _thoughtOfDay = '';
  bool _showChatbot = false;

  /// The day the banner currently on screen was worked out for, and the timer
  /// that expires with it. Both exist so a phone left on the dashboard
  /// overnight does not still be showing yesterday in the morning.
  String _thoughtDay = '';
  Timer? _midnight;

  // The canned-reply chatbot that used to live here is gone. It held a
  // controller, a scroll controller, a message list and a random-response
  // generator — none of which were ever rendered, because the sheet has no
  // input field. Talking to a person now happens in /counselling, which is a
  // real conversation with a real counsellor rather than a shuffled list of
  // reassuring sentences.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThought();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// A phone that was asleep does not fire timers. Coming back to the app is
  /// therefore the other moment the date can have moved on without anything
  /// noticing, and the cheap check below reloads only when it actually has.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _thoughtDay != Thoughts365.dateKey(DateTime.now())) {
      _loadThought();
    }
  }

  /// The thought of the day.
  ///
  /// This was a Firestore `snapshots()` listener held open for the whole life
  /// of the dashboard — a websocket per device, watching one document that
  /// changes once a day, to render one line of text. It is a read on open now.
  ///
  /// The API caches the value for a minute and sends `Cache-Control` with it,
  /// so a launch spike costs one query rather than one per install. When an
  /// operator publishes a new thought the write invalidates that cache
  /// immediately, and the picker sheet refreshes this screen on the way out.
  ///
  /// The offline fallback is the point of the local set: 365 thoughts ship in
  /// the binary, so a member with no connection still opens the app to
  /// something rather than to a blank card.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// An override belongs to the day it was published on
  ///
  /// The banner used to show whatever an operator had last set, forever: one
  /// thought published in March was still the thought of the day in August,
  /// because nothing ever cleared it. The day-of-year library underneath it —
  /// the whole reason 365 lines are written and shipped — was unreachable
  /// unless somebody remembered to press "Back to automatic".
  ///
  /// So the picker stamps its write with the day it was made on, and an
  /// override is only honoured while that stamp is today. Come midnight the
  /// banner returns to the line for the new day on its own, and if the operator
  /// wants a different one they set it again — which is a deliberate act about
  /// one day, not a switch left flipped.
  ///
  /// A stored value with no stamp is one written before this existed. It is
  /// treated as expired rather than as today's: honouring it would keep exactly
  /// the frozen banner this replaces.
  Future<void> _loadThought() async {
    final now = DateTime.now();
    final today = Thoughts365.dateKey(now);

    String text = Thoughts365.getThoughtForDay(Thoughts365.dayOfYear(now));
    try {
      final body = await ApiService().get('/api/support/metadata/thought_of_the_day');
      final published = body?['value']?['text'];
      final publishedOn = body?['value']?['date'];
      if (published is String &&
          published.trim().isNotEmpty &&
          publishedOn == today) {
        text = published;
      }
    } catch (e) {
      // A 404 is the ordinary case before anybody has published one, and an
      // offline device is the other. Both land on the bundled thought.
      debugPrint('▶ dashboard: using bundled thought ($e)');
    }

    if (!mounted) return;
    setState(() {
      _thoughtOfDay = text;
      _thoughtDay = today;
    });
    _scheduleMidnightRefresh();
  }

  /// One timer, aimed at the next midnight rather than a poll every minute.
  ///
  /// The extra seconds are slack: a timer that fires a hair *before* the date
  /// changes would recompute the same day and then not run again until the one
  /// after.
  void _scheduleMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      tomorrow.difference(now) + const Duration(seconds: 5),
      () {
        if (mounted) _loadThought();
      },
    );
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      await context.read<JournalProvider>().loadEntries(auth.user!.uid);
      // Automatically sync profile stats on launch to fix any Firestore mismatches
      ProfileService().syncProfileStats(auth.user!.uid);
    }
    // Before anything else that can interrupt: the greeting belongs to the
    // sign-in that just happened, and it reads as an afterthought if an update
    // prompt or the check-in sheet gets there first.
    await _maybeCelebrate();
    // Check for app update
    _checkForUpdate();
    await _maybeCheckIn();
    // If the check-in did not run — already journalled, already dismissed —
    // there may still be a gap worth one small question. JournalNudge decides;
    // it is rate-limited, random, and silent when today's entry is complete.
    if (mounted) await JournalNudge.maybeShow(context);
  }

  /// The welcome celebration, once per sign-in.
  ///
  /// Gated on [AuthProvider.consumeJustSignedIn] rather than on a stored date,
  /// because the popup marks an *event* — someone signing in — and not a day.
  /// Reaching the dashboard any other way (returning from the journal, a cold
  /// start on a saved session) leaves it silent, which is the difference
  /// between a greeting and a nag.
  Future<void> _maybeCelebrate() async {
    final auth = context.read<AuthProvider>();
    if (!auth.consumeJustSignedIn()) return;

    // "New" means the account was created in the last few minutes — i.e. this
    // sign-in is the one that followed registration.
    //
    // Read from the Firebase user's own metadata rather than from the profile
    // document: on a brand new account the profile write has often not come
    // back through its snapshot listener yet, so `profile.createdAt` is null at
    // exactly the moment it matters and every new member was greeted as a
    // returning one. The auth metadata is there the instant the credential is.
    final created = auth.user?.metadata.creationTime;
    final isNew = created != null &&
        DateTime.now().difference(created) < const Duration(minutes: 10);

    // A beat after the dashboard has drawn, so the card rises over a finished
    // screen rather than over one still filling in.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    await WelcomeCelebration.show(
      context,
      name: auth.profile?.displayName ??
          auth.user?.displayName ??
          auth.user?.email?.split('@').first ??
          'Friend',
      isNewMember: isNew,
    );
  }

  /// Opens the daily check-in once a day.
  ///
  /// Only when today's entry has not been written — otherwise it interrupts
  /// someone who has already journalled, which is exactly the person you least
  /// want to nag. Also skipped if they dismissed it earlier today: asked once,
  /// not asked repeatedly.
  Future<void> _maybeCheckIn() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final journal = context.read<JournalProvider>();
    if (journal.todaysEntry != null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'checkin_asked_${DateTime.now().toIso8601String().substring(0, 10)}';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    // A beat after launch so it does not collide with the opening animation.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Stamped so a random prompt cannot arrive on the heels of the check-in.
    await JournalNudge.markCheckInShown();
    await DailyCheckInSheet.show(context);
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

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Admin: choose today's thought from the bundled library, or write one.
  ///
  /// Was a bare text box, which meant the 365 lines already written for this
  /// app were unreachable unless you happened to remember one word for word.
  Future<void> _showEditThoughtDialog() async {
    await ThoughtPickerSheet.show(context, _thoughtOfDay);
    // The sheet writes through the API; re-read rather than guess. The read
    // also re-applies the day stamp, so cancelling out of the sheet cannot
    // leave the banner claiming an override that is no longer live.
    await _loadThought();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final journal = context.watch<JournalProvider>();
    final profile = auth.profile;
    final displayName = profile?.displayName ?? auth.user?.email?.split('@').first ?? 'Friend';

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
                                'Hello, $displayName',
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
                            // Was "share the app". The app is not on any store
                            // yet, so sharing it sent people to a link they
                            // cannot install from — the WhatsApp community is
                            // where someone can actually be told when it is.
                            IconButton(
                              tooltip: 'Join the community',
                              icon: const Icon(Icons.groups_outlined, color: AppTheme.textSecondary),
                              onPressed: () => _openCommunity(),
                            ),
                            const SizedBox(width: 2),
                            // A red count, not just a bell. The old icon looked
                            // identical whether four things had happened or
                            // none, so nobody ever opened it.
                            Consumer<NotificationCenter>(
                              builder: (_, centre, __) => Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      centre.hasUnread
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_outlined,
                                      color: centre.hasUnread
                                          ? AppTheme.accentLight
                                          : AppTheme.textSecondary,
                                    ),
                                    onPressed: () => context.push('/notifications'),
                                  ),
                                  if (centre.hasUnread)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        constraints: const BoxConstraints(minWidth: 17),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                              color: AppTheme.bgDark, width: 1.5),
                                        ),
                                        child: Text(
                                          centre.unreadCount > 9
                                              ? '9+'
                                              : '${centre.unreadCount}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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

                    // Directly under the streak number, because that is the
                    // number it is talking about. Renders nothing at all unless
                    // there is exactly one day to repair.
                    const _StreakRecoveryCard(),

                    // Free-access countdown — the offer is the headline while
                    // billing is switched off, so it sits above the fold.
                    const FreeAccessBanner(),
                    const SizedBox(height: 20),

                    // Thought of the Day
                    ThoughtBanner(
                      text: _thoughtOfDay,
                      onEdit: auth.isAdmin ? _showEditThoughtDialog : null,
                    ),
                    const SizedBox(height: 20),

                    // Navigation, grouped by what the person came to DO.
                    //
                    // This was one flat nine-tile grid under a single heading,
                    // and nine equally-weighted tiles is not a menu — it is a
                    // wall. Nothing told you that Journal and Affirmations are
                    // the same kind of act, or that the Community screen is a
                    // leaderboard rather than a chat room, so the way to find
                    // anything was to read all nine every time.
                    //
                    // Four intentions, two or three tiles each. The headings
                    // are verbs on purpose: a section called "Write" answers
                    // "what am I about to do", which is the question somebody
                    // opening this screen actually has.
                    const _NavSection(
                      label: 'Write',
                      tagline: 'Get the day out of your head',
                      accent: AppTheme.primary,
                      cards: [
                        _NavCard(icon: Icons.book_outlined, title: 'Journal', subtitle: 'Today, in your words', route: '/journal', color: AppTheme.primary),
                        _NavCard(icon: Icons.auto_awesome_outlined, title: 'Affirmations', subtitle: 'Steady the self-talk', route: '/affirmations', color: Color(0xFF059669)),
                        _NavCard(icon: Icons.chat_bubble_outline_outlined, title: 'Open Board', subtitle: 'Say it anonymously', route: '/thoughts', color: Color(0xFFD97706)),
                      ],
                    ),
                    const SizedBox(height: 26),

                    const _NavSection(
                      label: 'Read',
                      tagline: 'Borrow some clarity',
                      accent: Color(0xFFF59E0B),
                      cards: [
                        _NavCard(icon: Icons.menu_book_outlined, title: 'Wisdom', subtitle: 'Old answers, real situations', route: '/gita', color: Color(0xFFF59E0B)),
                        _NavCard(icon: Icons.article_outlined, title: 'Articles', subtitle: 'Written by people here', route: '/blogs', color: Color(0xFFEC4899)),
                        _NavCard(icon: Icons.shopping_bag_outlined, title: 'Library', subtitle: 'Books & long reads', route: '/products', color: Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 26),

                    const _NavSection(
                      label: 'Unwind',
                      tagline: 'Slow the whole thing down',
                      accent: Color(0xFF0891B2),
                      cards: [
                        _NavCard(icon: Icons.spa_outlined, title: 'Meditation', subtitle: 'Sit with it a while', route: '/meditation', color: Color(0xFF0891B2)),
                        _NavCard(icon: Icons.sports_esports_outlined, title: 'Game Zone', subtitle: 'Reset your focus', route: '/games', color: Color(0xFF8B5CF6)),
                      ],
                    ),
                    // No strip of individual games under this section. The
                    // Unwind tile above already opens the Game Zone, and a
                    // shuffled horizontal carousel of six of them directly
                    // beneath it said the same thing twice — the second time
                    // at six times the height.
                    const SizedBox(height: 26),

                    const _NavSection(
                      label: 'Track',
                      tagline: 'Proof that you showed up',
                      accent: Color(0xFFDC2626),
                      cards: [
                        _NavCard(icon: Icons.checklist_rounded, title: 'Deep Work', subtitle: 'Your plan, ticked daily', route: '/deep-work', color: Color(0xFF0EA5E9)),
                        _NavCard(icon: Icons.analytics_outlined, title: 'Your Patterns', subtitle: 'What the entries add up to', route: '/analytics', color: Color(0xFFDC2626)),
                        _NavCard(icon: Icons.people_outline, title: 'Streak Board', subtitle: 'Everyone still going', route: '/community', color: Color(0xFF7C3AED)),
                        _NavCard(icon: Icons.emoji_events_outlined, title: 'Game Ranks', subtitle: 'Top scores this week', route: '/games/leaderboard', color: Color(0xFFF59E0B)),
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

  /// The WhatsApp community — updates, and the place people hear that the app
  /// has reached a store.
  Future<void> _openCommunity() async {
    final url = Uri.parse(AppConstants.communityWhatsAppUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not open the community link';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the community: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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

  /// The 🤖 sheet.
  ///
  /// Two completely different jobs behind one button, because the person
  /// pressing it wants opposite things depending on who they are. A member is
  /// asking for help and gets the ways in. An admin *is* the help — showing
  /// them an intake form and a ₹299 price tag was asking the counsellor to book
  /// a session with themselves, so they get the live conversations instead.
  Widget _buildChatbotModal() {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

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
                                child: Center(
                                    child: Text(isAdmin ? '💬' : '🤖',
                                        style: const TextStyle(fontSize: 22))),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isAdmin ? 'Counselling desk' : 'InnenFlow Coach', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary)),
                                  Text(isAdmin ? 'Everyone waiting on you' : 'Psychological Analysis', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
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
                          child: isAdmin
                              ? _AdminChatsPanel(
                                  onOpen: (route) {
                                    setState(() => _showChatbot = false);
                                    context.push(route);
                                  },
                                )
                              : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // The member's own session, if they have one.
                                //
                                // This is what the bot was missing. The panel
                                // told everybody the same thing — "book a
                                // session" — including the person who had
                                // already booked one, paid for it and was
                                // waiting on a reply. "Connect Now" then pushed
                                // /counselling, which does open their session,
                                // but nothing on this sheet said so: the state
                                // of the thing they were waiting for was
                                // invisible from the icon that exists to tell
                                // them about it. So the first card is theirs.
                                _MySessionCard(
                                  onOpen: () {
                                    setState(() => _showChatbot = false);
                                    context.push('/counselling');
                                  },
                                ),

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
                                        '🚀 AI analysis is still being built',
                                        style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF818CF8), fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'In time, the coach will read your entries for emotional patterns. Until then you get the better version of this: a real human counsellor, available below.',
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
                                  'If today feels like too much, you can book a private 1-to-1 session and talk it through with someone right now.',
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
                                      _buildBulletPoint('A private, confidential one-to-one conversation.'),
                                      _buildBulletPoint('Personalized emotional assessment based on your concerns and current situation.'),
                                      _buildBulletPoint('Practical coping strategies for stress, anxiety, overthinking, relationship issues, and emotional well-being.'),
                                      _buildBulletPoint('Guidance on improving mental wellness with actionable daily practices.'),
                                      _buildBulletPoint('Opportunity to ask questions and receive personalized recommendations.'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // The two ways in. "Fill Form" is the general
                                // support form; "Connect Now" opens the
                                // counselling room with the operator — a real
                                // chat, not a WhatsApp hand-off that leaves the
                                // app and loses the thread.
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
                                        child: const Column(
                                          children: [
                                            Text('Fill Form', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.primaryLight, fontSize: 14, fontWeight: FontWeight.w600)),
                                            Text('Send us a message', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() => _showChatbot = false);
                                          context.push('/counselling');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: const Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.chat_bubble_outline, size: 15, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text('Connect Now', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            Text('Chat with a counsellor', style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: _launchWhatsApp,
                                    icon: const Icon(Icons.support_agent_outlined, size: 15, color: AppTheme.textMuted),
                                    label: const Text('Or reach us on WhatsApp',
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted)),
                                  ),
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

/// A named group of destinations on the home screen.
///
/// The heading is doing real work, not decoration. Its job is to let somebody
/// skip three quarters of the screen: a person who wants to sit quietly should
/// be able to ignore "Write" and "Track" without reading the tiles underneath
/// them, which is exactly what a single undifferentiated grid made impossible.
///
/// A section of two cards lays them out side by side; three or more falls into
/// a two-column grid. Forcing two cards into a grid leaves a hole where the
/// third would be, and a hole reads as something missing.
class _NavSection extends StatelessWidget {
  final String label;
  final String tagline;
  final Color accent;
  final List<_NavCard> cards;

  const _NavSection({
    required this.label,
    required this.tagline,
    required this.accent,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // A short colour bar rather than an icon: it ties the heading to
            // the tiles below without competing with their icons for attention.
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.space2 + 2),
            Expanded(
              child: Text(
                tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        if (cards.length == 2)
          Row(
            children: [
              Expanded(child: AspectRatio(aspectRatio: 1.2, child: cards[0])),
              const SizedBox(width: 12),
              Expanded(child: AspectRatio(aspectRatio: 1.2, child: cards[1])),
            ],
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: cards,
          ),
      ],
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

/// The member's own session, at the top of the 🤖 sheet.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What was wrong with the sheet without it
///
/// The 🤖 icon opened a panel that said the same thing to everybody: here is
/// what a session costs, here is what you get, book one. Including to the
/// member who had already booked one, already paid, and was waiting to hear
/// back — the one person for whom "Connect Now" is not the question.
///
/// Their session existed and was reachable; `/counselling` opens it rather than
/// the intake form. But nothing on the sheet said so, so the icon that exists
/// to tell somebody what is happening was the one place that did not. Somebody
/// who has just sent ₹299 and taps the assistant to find out where their
/// session went should not be sold the session again.
///
/// So the first card is theirs: what state it is in, what happens next, what
/// was last said and by whom, and a button that goes there. When there is no
/// session it renders nothing at all and the panel reads exactly as before.
class _MySessionCard extends StatefulWidget {
  final VoidCallback onOpen;

  const _MySessionCard({required this.onOpen});

  @override
  State<_MySessionCard> createState() => _MySessionCardState();
}

class _MySessionCardState extends State<_MySessionCard> {
  final _service = CounsellingService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CounsellingSession>>(
      stream: _service.streamMine(),
      builder: (context, snap) {
        // No session, still loading, or an error nobody can act on: render
        // nothing. A spinner or an error box above a panel whose whole purpose
        // is "book a session" would be noise on the common path, which is
        // somebody who has never booked one.
        final open = (snap.data ?? const <CounsellingSession>[])
            .where((s) => !s.isExpired && s.status != CounsellingStatus.ended)
            .toList();
        if (open.isEmpty) return const SizedBox.shrink();

        final session = open.first;
        final waitingOnMe = switch (session.status) {
          // The two states where the member is the one holding it up. Said
          // plainly, because "awaiting payment" reads to somebody as though
          // the app is doing something rather than waiting for them.
          CounsellingStatus.awaitingPayment => 'Pay ₹${session.amount} and send the reference — the chat opens after that.',
          CounsellingStatus.approved => 'Your payment is verified. Choose chat or a video call.',
          CounsellingStatus.paymentSubmitted => 'We are checking your payment by hand. This chat opens the moment it clears.',
          CounsellingStatus.meetRequested => 'Your call is being arranged. The link will appear here.',
          CounsellingStatus.active => 'Your session is live.',
          CounsellingStatus.rejected => 'The payment could not be verified. Reply with the reference and somebody will look again.',
          CounsellingStatus.ended => '',
        };

        // A reply from the counsellor is the thing worth surfacing on a
        // dashboard — it is why somebody taps this icon at all.
        final theyReplied = session.lastMessageBy == ChatSender.admin;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theyReplied
                  ? const Color(0xFF10B981).withOpacity(0.12)
                  : AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theyReplied
                    ? const Color(0xFF10B981).withOpacity(0.45)
                    : AppTheme.primary.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🗓️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text(
                      'Your session',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        session.status.label,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  waitingOnMe,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppTheme.textSecondary),
                ),
                if (theyReplied && session.lastMessagePreview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mark_chat_unread_outlined,
                          size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Counsellor: ${session.lastMessagePreview}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              height: 1.4,
                              color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theyReplied
                          ? const Color(0xFF10B981)
                          : AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.forum_outlined,
                        size: 17, color: Colors.white),
                    label: Text(
                      theyReplied ? 'Read the reply' : 'Open my session',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The admin's half of the 🤖 sheet: every conversation, live from Firestore.
///
/// Deliberately not a link to the inbox and nothing else. The question an
/// operator opens this for — *is anybody waiting on me right now* — should be
/// answered by the sheet itself, in one glance, before they decide whether to
/// go anywhere. Tapping a row opens that chat; the button at the bottom opens
/// the full inbox with its verify / active / all tabs.
class _AdminChatsPanel extends StatefulWidget {
  final void Function(String route) onOpen;

  const _AdminChatsPanel({required this.onOpen});

  @override
  State<_AdminChatsPanel> createState() => _AdminChatsPanelState();
}

class _AdminChatsPanelState extends State<_AdminChatsPanel> {
  final _service = CounsellingService();

  @override
  void initState() {
    super.initState();
    // Ended sessions past their two hours are destroyed on the way in, from
    // this side of the room as well as from the member's.
    _service.purgeExpired(asAdmin: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CounsellingSession>>(
      stream: _service.streamAll(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load the sessions: ${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Outfit', fontSize: 13, color: Colors.redAccent),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final all = snap.data!.where((s) => !s.isExpired).toList();
        final toVerify = all
            .where((s) => s.status == CounsellingStatus.paymentSubmitted)
            .toList();
        // Approved counts as live: the member has paid, is choosing their
        // format, and could type at any second.
        final live = all.where((s) => s.isLive).toList()
          ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
              .compareTo(a.lastMessageAt ?? a.createdAt));
        final waitingToPay = all
            .where((s) => s.status == CounsellingStatus.awaitingPayment)
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: _AdminChatStat(
                    value: '${toVerify.length}',
                    label: 'To verify',
                    color: AppTheme.accent,
                    urgent: toVerify.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminChatStat(
                    value: '${live.length}',
                    label: 'Live chats',
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminChatStat(
                    value: '$waitingToPay',
                    label: 'Awaiting pay',
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (toVerify.isNotEmpty) ...[
              const Text(
                'Payments to verify',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Approve one and the chat goes live with that member.',
                style: TextStyle(
                    fontFamily: 'Outfit', fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              ...toVerify.map((s) => _AdminChatRow(
                    session: s,
                    onTap: () => widget.onOpen('/counselling/inbox'),
                  )),
              const SizedBox(height: 18),
            ],

            const Text(
              'Active chats',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            if (live.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No live sessions right now. A chat becomes active the moment '
                  'you approve a payment.',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppTheme.textMuted),
                ),
              )
            else
              ...live.map((s) => _AdminChatRow(
                    session: s,
                    onTap: () => widget.onOpen('/counselling/inbox'),
                  )),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onOpen('/counselling/inbox'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.inbox_outlined, size: 18, color: Colors.white),
                label: const Text(
                  'Open the full inbox',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminChatStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool urgent;

  const _AdminChatStat({
    required this.value,
    required this.label,
    required this.color,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: urgent ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: urgent ? 0.55 : 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Outfit', fontSize: 10.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AdminChatRow extends StatelessWidget {
  final CounsellingSession session;
  final VoidCallback onTap;

  const _AdminChatRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // A dot only when the member spoke last: that is the difference between
    // "there is a conversation" and "somebody is waiting on a reply".
    final waitingOnMe = session.lastMessageBy == ChatSender.member;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: waitingOnMe
                ? AppTheme.accent.withValues(alpha: 0.45)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            if (waitingOnMe)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 9),
                decoration: const BoxDecoration(
                    color: AppTheme.accent, shape: BoxShape.circle),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name.isEmpty ? 'Member' : session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.lastMessagePreview.isEmpty
                        ? session.concern
                        : session.lastMessagePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session.status.label,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Yesterday is missing. Recover it?"
///
/// Silent unless there is genuinely one day to repair — which is most days, for
/// most people, and that is the point. A permanent "recover your streak" button
/// would turn a safety net into a feature people plan around; a card that only
/// appears the morning after a slip is a safety net.
///
/// It also stays visible, greyed, when the gap exists but the monthly allowance
/// has been spent. Saying "you used yours 11 days ago" is the honest version of
/// hiding the button and letting them wonder whether the feature is broken.
class _StreakRecoveryCard extends StatefulWidget {
  const _StreakRecoveryCard();

  @override
  State<_StreakRecoveryCard> createState() => _StreakRecoveryCardState();
}

class _StreakRecoveryCardState extends State<_StreakRecoveryCard> {
  final _service = StreakService();

  StreakRecovery? _status;
  bool _working = false;

  /// The entry set the current [_status] was computed from. The provider
  /// reloads whenever an entry is written, and re-checking on every rebuild
  /// would be a Firestore read per frame.
  int _checkedAgainst = -1;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final journal = context.watch<JournalProvider>();
    final uid = auth.user?.uid;

    if (uid == null || journal.loading) return const SizedBox.shrink();

    final signature = Object.hash(journal.entries.length, journal.recoveredDays.length);
    if (signature != _checkedAgainst) {
      _checkedAgainst = signature;
      _refresh(uid, journal.entryDates);
    }

    final status = _status;
    if (status == null || status.missedDay == null) return const SizedBox.shrink();

    final missed = status.missedDay!;
    final available = status.hasAllowance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: available ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B)
                .withValues(alpha: available ? 0.40 : 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🛟', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    available
                        ? 'You missed ${_dayLabel(missed)}'
                        : 'Recovery already used this month',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              available
                  ? 'One day, once a month — that is the whole allowance. Use it '
                      'and your streak carries on as if the day had not been '
                      'missed. Miss two days in a row and there is nothing to '
                      'recover; that is a fresh start, not a failure.'
                  : 'Your next recovery is available in '
                      '${status.daysUntilAllowance} '
                      '${status.daysUntilAllowance == 1 ? 'day' : 'days'}. '
                      'Until then the honest way back is to write today.',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                height: 1.55,
                color: AppTheme.textSecondary,
              ),
            ),
            if (available) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _working ? null : () => _recover(uid, missed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _working
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black54),
                        )
                      : const Icon(Icons.restore_rounded, size: 17),
                  label: Text(
                    _working ? 'Recovering…' : 'Recover my streak',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(String uid, List<DateTime> entryDates) async {
    final status = await _service.check(uid: uid, entryDates: entryDates);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _recover(String uid, DateTime day) async {
    setState(() => _working = true);
    try {
      await _service.recover(uid: uid, day: day);
      // Reload before reporting success: the number on the card behind this one
      // has to have moved by the time the message is read, or the member is
      // told it worked while looking at evidence that it did not.
      if (mounted) await context.read<JournalProvider>().loadEntries(uid);
      await ProfileService().syncProfileStats(uid);
      if (!mounted) return;
      setState(() {
        _status = null;
        _checkedAgainst = -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Streak recovered. Keep going. 🔥',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not recover the streak just now. Please try again.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _dayLabel(DateTime day) {
    final gap = daysBetween(day, DateTime.now());
    if (gap == 1) return 'yesterday';
    if (gap == 2) return 'the day before yesterday';
    return 'a day';
  }
}
