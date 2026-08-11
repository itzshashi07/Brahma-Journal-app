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
import 'counselling_screen.dart' show openMeet;

/// The counsellor's side of the room.
///
/// Three tabs, because the operator has three genuinely different jobs and one
/// undifferentiated list buried all of them:
///
///   • **To verify** — somebody has paid and is waiting. This is money and a
///     person in distress, so it is the tab that opens first and the only one
///     that carries a count in its label.
///   • **Active chats** — every live conversation, newest reply on top, with a
///     dot on the ones where the member spoke last. This is the "all chats"
///     view: what is running right now and who is waiting on a reply.
///   • **All** — everything, including finished sessions still inside their
///     two-hour window.
class CounsellingInboxScreen extends StatefulWidget {
  const CounsellingInboxScreen({super.key});

  @override
  State<CounsellingInboxScreen> createState() => _CounsellingInboxScreenState();
}

class _CounsellingInboxScreenState extends State<CounsellingInboxScreen>
    with SingleTickerProviderStateMixin {
  final _service = CounsellingService();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _service.purgeExpired(asAdmin: true);
  }

  @override
  void dispose() {
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
              style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
        ),
      );
    }

    return Scaffold(
      body: SacredBackdrop(
        child: SafeArea(
          child: StreamBuilder<List<CounsellingSession>>(
            stream: _service.streamAll(),
            builder: (context, snap) {
              final all = snap.data ?? const <CounsellingSession>[];

              final toVerify = all
                  .where((s) => s.status == CounsellingStatus.paymentSubmitted)
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
                          text: 'To verify',
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
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space5),
                      child: Text('Could not load sessions: ${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: Colors.redAccent,
                              fontSize: 13)),
                    ),
                  Expanded(
                    child: !snap.hasData
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary))
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _list(
                                toVerify,
                                empty: 'Nothing waiting on you. '
                                    'New payments land here the moment they are sent.',
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
              onEnd: () => _service.endSession(sessions[i].id),
            )
          : _SessionTile(
              session: sessions[i],
              service: _service,
              onOpenChat: () => _openChat(sessions[i]),
              onVerify: () => _verify(sessions[i]),
            ),
    );
  }

  void _openChat(CounsellingSession session) {
    Navigator.of(context).push(
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
  }

  /// The verification step, as its own sheet.
  ///
  /// Approving is an irreversible money decision made against a bank statement
  /// in another app, so the transaction reference is presented large and
  /// selectable, and both outcomes are one deliberate tap rather than two
  /// small buttons on a crowded card.
  Future<void> _verify(CounsellingSession session) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppTheme.space3),
          padding: const EdgeInsets.all(AppTheme.space5),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify payment',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.name} · ${session.concern}',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    color: AppTheme.textMuted),
              ),
              const SizedBox(height: AppTheme.space5),
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${session.amount == 0 ? Counselling.fee : session.amount}  ·  ${session.paymentMode}',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentLight),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    const Text('TRANSACTION ID',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 9.5,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    SelectableText(
                      session.transactionId.isEmpty
                          ? '(none sent)'
                          : session.transactionId,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    Text(
                      'Check this against ${Counselling.upiId} before approving. '
                      'Approving opens the session immediately.',
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              SacredButton(
                label: 'Payment received — open session',
                icon: Icons.verified_rounded,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _service.approve(session.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${session.name}\'s session is open.',
                            style: const TextStyle(fontFamily: 'Outfit')),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppTheme.space2),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _service.reject(session.id);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
                ),
                child: const Text('Could not find this payment',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Colors.redAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Decide later',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final int count;
  final bool urgent;

  const _TabLabel({required this.text, required this.count, this.urgent = false});

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

  const _ChatRow({
    required this.session,
    required this.onOpen,
    required this.onEnd,
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
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.22),
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
                    onPressed: () => openMeet(context),
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
  final CounsellingService service;
  final VoidCallback onOpenChat;
  final VoidCallback onVerify;

  const _SessionTile({
    required this.session,
    required this.service,
    required this.onOpenChat,
    required this.onVerify,
  });

  Color get _statusColor => switch (session.status) {
        CounsellingStatus.paymentSubmitted => AppTheme.accent,
        CounsellingStatus.active => AppTheme.success,
        CounsellingStatus.approved => AppTheme.primaryLight,
        CounsellingStatus.rejected => Colors.redAccent,
        CounsellingStatus.ended => AppTheme.textMuted,
        CounsellingStatus.awaitingPayment => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final needsVerification =
        session.status == CounsellingStatus.paymentSubmitted;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name.isEmpty ? 'Unnamed member' : session.name,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    session.status.label,
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _statusColor),
                  ),
                ),
              ],
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
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
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

            // The two things an operator ever wants to do with a request:
            // check the money, or talk to the person. Both are always here,
            // and Verify leads when there is a payment waiting.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenChat,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.7)),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppTheme.space3),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: AppTheme.primaryLight),
                    label: const Text('Chat',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight)),
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  flex: needsVerification ? 2 : 1,
                  child: needsVerification
                      ? SacredButton(
                          label: 'Verify',
                          icon: Icons.verified_outlined,
                          onTap: onVerify,
                        )
                      : OutlinedButton.icon(
                          // Still offered outside the waiting state: a member
                          // may have paid and not reported it, and the operator
                          // needs a way to open the session anyway.
                          onPressed: onVerify,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.space3),
                          ),
                          icon: const Icon(Icons.verified_outlined,
                              size: 16, color: AppTheme.textMuted),
                          label: const Text('Verify',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: AppTheme.textMuted)),
                        ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.space2),
            Row(
              children: [
                Text(
                  DateFormat('dd MMM, h:mm a').format(session.createdAt),
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppTheme.textMuted),
                ),
                const Spacer(),
                if (session.mode == CounsellingMode.meet)
                  TextButton.icon(
                    onPressed: () => openMeet(context),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.videocam_outlined, size: 15),
                    label: const Text('Join call',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5)),
                  ),
                if (session.status == CounsellingStatus.active)
                  TextButton(
                    onPressed: () => service.endSession(session.id),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('End session',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: AppTheme.textMuted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
