import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/sacred.dart';

/// Admin inbox for support tickets.
///
/// Every submission is stored whether or not the mail relay is running.
/// Without this screen those tickets were only visible in the database console,
/// which is not somewhere anyone checks daily — so messages were arriving and
/// going unread.
///
/// It no longer has to be checked by hand to *find out* one arrived: filing a
/// ticket raises an operator alert through FCM, which reaches a closed app. This
/// screen is where you then read them.
///
/// Read on open and on pull-to-refresh rather than over a live listener. A
/// support queue is not something anybody watches change in real time, and the
/// listener held a socket open for as long as the screen was mounted.
class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  late Future<List<Map<String, dynamic>>> _tickets = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final body = await ApiService()
        .get('/api/support/tickets', query: {'limit': '100'});
    return ((body?['tickets'] as List?) ?? const [])
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _tickets = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SacredAppBar(
                title: 'Support Inbox',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _tickets,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const _Empty(
                        icon: Icons.lock_outline_rounded,
                        title: 'Cannot read tickets',
                        message:
                            'Support tickets are readable by admins only. Sign in with the operator account.',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      );
                    }

                    final tickets = snap.data!;
                    if (tickets.isEmpty) {
                      return const _Empty(
                        icon: Icons.mark_email_read_outlined,
                        title: 'No tickets yet',
                        message:
                            'Messages sent from the Contact Us form will appear here.',
                      );
                    }

                    // Pull-to-refresh is what replaces the listener: the
                    // operator asks for the current queue rather than holding a
                    // connection open in case one arrives.
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0,
                            AppTheme.space4, AppTheme.space8),
                        itemCount: tickets.length,
                        itemBuilder: (_, i) => _TicketCard(data: tickets[i]),
                      ),
                    );
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

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TicketCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // The API's field names, with the Firestore ones kept as a fallback: a
    // ticket migrated from Firestore carries `name` and `email`, and one filed
    // since carries `userName` and `userEmail`. Both are in the collection.
    final name =
        ((data['userName'] ?? data['name']) as String?)?.trim();
    final email =
        ((data['userEmail'] ?? data['email']) as String?)?.trim() ?? '';
    final category = data['category'] as String? ?? 'General';
    final message = data['message'] as String? ?? '';
    final emailed = data['emailed'] as bool? ?? false;
    final created = DateTime.tryParse('${data['createdAt'] ?? ''}');
    final when =
        created == null ? '' : DateFormat('d MMM, h:mm a').format(created);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space2 + 2, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
                const Spacer(),
                if (!emailed)
                  const Padding(
                    padding: EdgeInsets.only(right: AppTheme.space2),
                    child: Icon(Icons.mark_email_unread_outlined,
                        size: 14, color: AppTheme.accent),
                  ),
                Text(
                  when,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              (name?.isNotEmpty == true) ? name! : 'Friend',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (email.isNotEmpty)
              Text(
                email,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: AppTheme.textMuted),
              ),
            const SizedBox(height: AppTheme.space3),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13.5,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space3),
              Row(
                children: [
                  _Action(
                    icon: Icons.reply_rounded,
                    label: 'Reply by email',
                    onTap: () => _reply(context, email, category),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  _Action(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copied',
                              style: TextStyle(fontFamily: 'Outfit')),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the operator's own mail client with the reply prepared. This is the
  /// one way to send mail that needs no server and no credentials in the app.
  Future<void> _reply(
      BuildContext context, String to, String category) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        'subject': 'Re: $category — InnenFlow',
        'body': '\n\n—\nInnenFlow Support',
      },
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space3, vertical: AppTheme.space2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryLight),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Empty(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: AppTheme.space4),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: AppTheme.space2),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
