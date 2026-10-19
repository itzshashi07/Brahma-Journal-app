import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/counselling.dart';
import '../../core/theme/app_theme.dart';
import '../../models/counselling_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/counselling_service.dart';
import '../../widgets/sacred.dart';
import 'counselling_chat_view.dart';
import 'counselling_actions.dart';
import 'counselling_screen.dart' show openMeet;

/// Admin requests, live chats and recent conversations, grouped by the next
/// action so someone waiting for a first reply is easy to find.
class CounsellingInboxScreen extends StatefulWidget {
  const CounsellingInboxScreen({super.key, this.service});
  final CounsellingService? service;

  @override
  State<CounsellingInboxScreen> createState() => _CounsellingInboxScreenState();
}

class _CounsellingInboxScreenState extends State<CounsellingInboxScreen>
    with SingleTickerProviderStateMixin {
  late final _service = widget.service ?? CounsellingService();
  late final _inboxStream = _service.streamAll();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _service.purgeExpired(asAdmin: true);
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Belt and braces with the router guard and firestore.rules: an admin-only
    // screen should not render its contents just because a redirect was missed.
    if (!context.watch<AuthProvider>().isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Admins only.',
              style:
                  TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
        ),
      );
    }

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: StreamBuilder<List<CounsellingSession>>(
            stream: _inboxStream,
            builder: (context, snap) {
              final all = snap.data ?? const <CounsellingSession>[];

              final toVerify = all
                  .where((s) =>
                      s.status == CounsellingStatus.paymentSubmitted ||
                      s.status == CounsellingStatus.awaitingPayment)
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

              // "Active" means a live session, including one that has been
              // approved but not yet started — the member is choosing their
              // format and could type at any second.
              final active = all.where((s) => s.isLive).toList()
                ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
                    .compareTo(a.lastMessageAt ?? a.createdAt));

              final everything = all.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                children: [
                  SacredAppBar(
                    title: 'Counselling',
                    subtitle: snap.hasData
                        ? '${all.length} total · ${active.length} live'
                        : 'Loading…',
                    onBack: () => context.pop(),
                  ),
                  TabBar(
                    controller: _tabs,
                    indicatorColor: AppTheme.primary,
                    labelColor: AppTheme.textPrimary,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    tabs: [
                      Tab(
                        child: _TabLabel(
                          text: 'Waiting list',
                          count: toVerify.length,
                          urgent: true,
                        ),
                      ),
                      Tab(
                        child: _TabLabel(
                          text: 'Active chats',
                          count: active.length,
                        ),
                      ),
                      const Tab(text: 'All'),
                    ],
                  ),
                  Expanded(
                    child: snap.hasError
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('Could not load requests.'),
                                TextButton(
                                    onPressed: () => _service.refresh(),
                                    child: const Text('Retry')),
                              ]))
                        : !snap.hasData
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary))
                            : TabBarView(
                                controller: _tabs,
                                children: [
                                  _list(
                                    toVerify,
                                    empty: 'Nothing waiting on you. '
                                        'New support requests appear here for approval.',
                                  ),
                                  _list(
                                    active,
                                    empty: 'No live sessions right now.',
                                    asChats: true,
                                  ),
                                  _list(everything,
                                      empty: 'No counselling requests yet.'),
                                ],
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<CounsellingSession> sessions, {
    required String empty,
    bool asChats = false,
  }) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space8),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                height: 1.6,
                color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space4),
      itemCount: sessions.length,
      itemBuilder: (_, i) => asChats
          ? _ChatRow(
              session: sessions[i],
              onOpen: () => _openChat(sessions[i]),
              onEnd: () =>
                  _changeConversation(sessions[i], CounsellingAction.end),
              onDelete: () =>
                  _changeConversation(sessions[i], CounsellingAction.delete),
            )
          : _SessionTile(
              session: sessions[i],
              onEnd: () =>
                  _changeConversation(sessions[i], CounsellingAction.end),
              onDelete: () =>
                  _changeConversation(sessions[i], CounsellingAction.delete),
              onOpenChat: () => _openChat(sessions[i]),
              onVerify: () => _verify(sessions[i]),
              onApproveMeeting: () => _approveMeeting(sessions[i]),
            ),
    );
  }

  Future<void> _openChat(CounsellingSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SacredBackdrop(
            child: SafeArea(
              child: CounsellingChatView(
                sessionId: session.id,
                asAdmin: true,
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) await _service.refresh();
  }

  Future<void> _changeConversation(
      CounsellingSession session, CounsellingAction action) async {
    final changed = await confirmCounsellingAction(
        context: context, service: _service, session: session, action: action);
    if (changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == CounsellingAction.delete
            ? 'Conversation deleted.'
            : 'Session ended.'),
      ));
    }
  }

  /// Confirming a video call and issuing a room for it.
  ///
  /// The link is typed per session rather than pulled from a constant. The app
  /// used to hand every member the same fixed Meet room the moment they chose
  /// "video call", which meant anybody who had ever booked a call held a
  /// working way into everybody else's — and it went out before a human had
  /// agreed to be there at all.
  Future<void> _approveMeeting(CounsellingSession session) async {
    final ctrl = TextEditingController();
    String? error;

    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          title: const Text('Confirm the call',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.name} is waiting. Create a room, then paste the '
                'link — they will see it in the chat straight away.',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.space3),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://meet.google.com/…',
                  errorText: error,
                  hintStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final v = ctrl.text.trim();
                final uri = Uri.tryParse(v);
                // Checked here as well as in the service: a typo means a member
                // sits waiting for a call that cannot happen.
                if (v.isEmpty ||
                    uri == null ||
                    !uri.isAbsolute ||
                    !(uri.scheme == 'http' || uri.scheme == 'https')) {
                  setLocal(() => error = 'Paste a full https:// link');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Send link'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (link == null || !mounted) return;
    try {
      await _service.approveMeeting(sessionId: session.id, link: link);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e', style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  /// Review the member's request before opening or declining the chat.
  Future<void> _verify(CounsellingSession session) async {
    if (session.status != CounsellingStatus.awaitingPayment &&
        session.status != CounsellingStatus.paymentSubmitted) {
      return;
    }
    final action = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Review support request'),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${session.name} · ${session.language}'),
                    const SizedBox(height: 12),
                    Text(session.concern,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(session.details),
                    const SizedBox(height: 16),
                    const Text(
                        'Approval opens a free private chat and notifies this member. Only approve when you can respond.'),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Decline')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Approve chat')),
              ],
            ));
    if (action == null) return;
    try {
      if (action) {
        await _service.approve(session.id);
      } else {
        await _service.reject(session.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(action
                ? 'Chat opened. Member notified.'
                : 'Request declined.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update the request. Please retry.')));
      }
    }
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final int count;
  final bool urgent;

  const _TabLabel(
      {required this.text, required this.count, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: urgent
                  ? const Color(0xFFEF4444)
                  : AppTheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }
}

/// A live conversation, as it appears in the "Active chats" tab.
///
/// Deliberately a messaging-app row rather than a detail card: at this point
/// the operator has already read the intake, and what they need is who is
/// waiting and what they last said.
class _ChatRow extends StatelessWidget {
  final CounsellingSession session;
  final VoidCallback onOpen;
  final VoidCallback onEnd;
  final VoidCallback onDelete;

  const _ChatRow({
    required this.session,
    required this.onOpen,
    required this.onEnd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // The member spoke last, so the ball is with the counsellor.
    final waiting = session.lastMessageBy == ChatSender.member;
    final when = session.lastMessageAt;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: waiting
              ? AppTheme.success.withValues(alpha: 0.55)
              : AppTheme.border,
          width: waiting ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.22),
                      child: Text(
                        session.name.isEmpty
                            ? '?'
                            : session.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryLight),
                      ),
                    ),
                    if (waiting)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.bgCard, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.name.isEmpty ? 'Member' : session.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14.5,
                                fontWeight:
                                    waiting ? FontWeight.w800 : FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (session.mode == CounsellingMode.meet)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.videocam_rounded,
                                  size: 14, color: AppTheme.accentLight),
                            ),
                          if (when != null)
                            Text(
                              DateFormat('h:mm a').format(when),
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10.5,
                                  color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.lastMessagePreview.isEmpty
                            ? session.status.label
                            : session.lastMessagePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: waiting
                              ? AppTheme.textSecondary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.mode == CounsellingMode.meet)
                  IconButton(
                    tooltip: 'Join the call',
                    onPressed: () => openMeet(context, session.meetLink),
                    icon: const Icon(Icons.videocam_outlined,
                        size: 19, color: AppTheme.accentLight),
                  ),
                PopupMenuButton<String>(
                  color: AppTheme.bgCard,
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 19, color: AppTheme.textMuted),
                  onSelected: (v) {
                    if (v == 'open') onOpen();
                    if (v == 'end') onEnd();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'open',
                      child: Text('Open chat',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: AppTheme.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete conversation'),
                    ),
                    PopupMenuItem(
                      value: 'end',
                      child: Text('End session',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full request, with the intake details a counsellor reads before
/// deciding anything.
class _SessionTile extends StatelessWidget {
  final CounsellingSession session;
  final VoidCallback onEnd;
  final VoidCallback onDelete;
  final VoidCallback onOpenChat;
  final VoidCallback onVerify;
  final VoidCallback onApproveMeeting;

  const _SessionTile({
    required this.session,
    required this.onEnd,
    required this.onDelete,
    required this.onOpenChat,
    required this.onVerify,
    required this.onApproveMeeting,
  });

  Color get _statusColor => switch (session.status) {
        CounsellingStatus.paymentSubmitted => AppTheme.accent,
        CounsellingStatus.active => AppTheme.success,
        CounsellingStatus.approved => AppTheme.primaryLight,
        // Amber like a payment waiting to be checked: both mean somebody is
        // waiting on the operator to do something.
        CounsellingStatus.meetRequested => AppTheme.accent,
        CounsellingStatus.rejected => Colors.redAccent,
        CounsellingStatus.ended => AppTheme.textMuted,
        CounsellingStatus.awaitingPayment => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final needsVerification =
        session.status == CounsellingStatus.paymentSubmitted ||
            session.status == CounsellingStatus.awaitingPayment;
    final needsMeetApproval = session.status == CounsellingStatus.meetRequested;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: needsVerification
              ? AppTheme.accent.withValues(alpha: 0.55)
              : AppTheme.border,
          width: needsVerification ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name.isEmpty ? 'Member' : session.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(session.status.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _statusColor)),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (session.age.isNotEmpty) '${session.age}y',
                if (session.gender.isNotEmpty) session.gender,
                if (session.language.isNotEmpty) session.language,
                if (session.phone.isNotEmpty) session.phone,
              ].join(' · '),
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              session.concern,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            if (session.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                session.details,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textMuted),
              ),
            ],
            if (session.transactionId.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space3),
              Container(
                padding: const EdgeInsets.all(AppTheme.space3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${session.amount == 0 ? Counselling.fee : session.amount} via ${session.paymentMode}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentLight),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      'Txn: ${session.transactionId}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.space4),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Open chat'),
                ),
                if (needsVerification)
                  FilledButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Review request'),
                  ),
                if (needsMeetApproval)
                  FilledButton.icon(
                    onPressed: onApproveMeeting,
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Send link'),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(DateFormat('dd MMM, h:mm a').format(session.createdAt),
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            Wrap(spacing: 8, children: [
              if (session.mode == CounsellingMode.meet &&
                  session.meetLink.isNotEmpty)
                TextButton.icon(
                    onPressed: () => openMeet(context, session.meetLink),
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Join call')),
              if (session.isLive)
                TextButton(onPressed: onEnd, child: const Text('End session')),
              TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete conversation')),
            ]),
          ],
        ),
      ),
    );
  }
}
