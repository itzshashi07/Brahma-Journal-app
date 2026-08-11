import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/counselling.dart';
import '../../core/theme/app_theme.dart';
import '../../models/counselling_session.dart';
import '../../services/counselling_service.dart';
import '../../services/notification_center.dart';
import '../../widgets/counselling_chat.dart';
import '../../widgets/sacred.dart';
import 'counselling_screen.dart' show openUpiApp, copyUpiId, openMeet;

/// The counselling room, from the member's side.
///
/// One screen for the whole journey rather than a wizard: the payment card, the
/// format choice and the conversation are all the same thread, in the order
/// they happened. Someone who closes the app mid-payment and comes back an hour
/// later sees exactly where they left off, because the state is the session
/// document rather than a step counter in memory.
class CounsellingChatView extends StatefulWidget {
  final String sessionId;

  /// True when an admin is looking. Changes which side of the room the bubbles
  /// sit on, and which controls are offered.
  final bool asAdmin;

  const CounsellingChatView({
    super.key,
    required this.sessionId,
    this.asAdmin = false,
  });

  @override
  State<CounsellingChatView> createState() => _CounsellingChatViewState();
}

class _CounsellingChatViewState extends State<CounsellingChatView> {
  final _service = CounsellingService();
  final _scroll = ScrollController();
  Timer? _countdown;

  ChatSender get _me => widget.asAdmin ? ChatSender.admin : ChatSender.member;

  @override
  void initState() {
    super.initState();
    // Only running while a session is winding down; the countdown on an active
    // session would be a rebuild a second for no reason.
    _countdown = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Reading the thread is what clears its badge — otherwise the dashboard
    // keeps claiming an unread reply the member is currently looking at.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.asAdmin) {
        context.read<NotificationCenter>().markRepliesRead();
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CounsellingSession?>(
      stream: _service.streamSession(widget.sessionId),
      builder: (context, snap) {
        final session = snap.data;
        if (session == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        return Column(
          children: [
            _header(session),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _service.streamMessages(session.id),
                builder: (context, msgSnap) {
                  final messages = msgSnap.data ?? const <ChatMessage>[];
                  _scrollToEnd();
                  return ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(
                        top: AppTheme.space3, bottom: AppTheme.space4),
                    children: [
                      for (final m in messages)
                        ChatBubbleView(message: m, mine: m.sender == _me),
                      ..._actionCards(session),
                    ],
                  );
                },
              ),
            ),
            ChatComposer(
              enabled: session.status != CounsellingStatus.ended,
              disabledHint: session.timeUntilPurge == null
                  ? 'This session has ended.'
                  : 'Session ended. This conversation disappears in '
                      '${_formatLeft(session.timeUntilPurge!)}.',
              onSendText: (text) => _service.sendText(
                sessionId: session.id,
                sender: _me,
                text: text,
              ),
              onSendVoice: (file, seconds) => _service.sendVoiceNote(
                sessionId: session.id,
                sender: _me,
                file: file,
                seconds: seconds,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────── header ───────────────────────────

  Widget _header(CounsellingSession session) {
    final left = session.timeUntilPurge;

    return Column(
      children: [
        SacredAppBar(
          title: widget.asAdmin ? session.name : 'Your counsellor',
          subtitle: session.status.label,
          // Navigator rather than context.pop(): the admin reaches this view
          // through an imperative push from the inbox, which go_router does not
          // track — its pop would be operating on the wrong stack.
          onBack: () => Navigator.of(context).maybePop(),
        ),
        // The privacy promise, stated where it can be checked rather than
        // buried in a policy nobody opens.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4, vertical: AppTheme.space2),
          color: left != null
              ? AppTheme.danger.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.03),
          child: Row(
            children: [
              Icon(
                left != null
                    ? Icons.timer_outlined
                    : Icons.lock_outline_rounded,
                size: 13,
                color: left != null ? Colors.redAccent : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  left != null
                      ? 'This conversation deletes itself in ${_formatLeft(left)}'
                      : 'Private. Deleted automatically 2 hours after the session ends.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color:
                        left != null ? Colors.redAccent : AppTheme.textMuted,
                  ),
                ),
              ),
              if (session.status == CounsellingStatus.active ||
                  session.status == CounsellingStatus.approved)
                GestureDetector(
                  onTap: () => _confirmEnd(session),
                  child: const Text(
                    'End session',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLeft(Duration d) {
    if (d.inMinutes < 1) return 'under a minute';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  Future<void> _confirmEnd(CounsellingSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End this session?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text(
          'The conversation stays readable for two more hours and is then '
          'deleted for good — messages and voice notes both.',
          style: TextStyle(
              fontFamily: 'Outfit', color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep talking')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End session')),
        ],
      ),
    );
    if (ok == true) await _service.endSession(session.id);
  }

  // ─────────────────────────── action cards ───────────────────────────

  /// What the member has to do next, pinned to the bottom of the thread.
  ///
  /// Rendered inside the message list rather than as a floating panel so the
  /// instruction and the messages that explain it stay together when scrolled.
  List<Widget> _actionCards(CounsellingSession session) {
    if (widget.asAdmin) return const [];

    return switch (session.status) {
      CounsellingStatus.awaitingPayment ||
      CounsellingStatus.rejected =>
        [_PaymentCard(session: session, service: _service)],
      CounsellingStatus.approved => [
          _ModeChoiceCard(session: session, service: _service),
        ],
      CounsellingStatus.active when session.mode == CounsellingMode.meet => [
          _MeetCard(),
        ],
      _ => const [],
    };
  }
}

// ─────────────────────────── payment ───────────────────────────

/// The fee, the QR, and the form that reports the transaction.
class _PaymentCard extends StatefulWidget {
  final CounsellingSession session;
  final CounsellingService service;

  const _PaymentCard({required this.session, required this.service});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  final _txnCtrl = TextEditingController();
  String _mode = Counselling.paymentModes.first;
  bool _reporting = false;
  bool _sending = false;

  @override
  void dispose() {
    _txnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final txn = _txnCtrl.text.trim();
    if (txn.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the transaction ID from your payment app.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.service.submitPayment(
        sessionId: widget.session.id,
        paymentMode: _mode,
        transactionId: txn,
        memberName: widget.session.name,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send those details: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded,
                    size: 18, color: AppTheme.accentLight),
                SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    'Pay the session fee',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                ),
                Text(
                  '₹${Counselling.fee}',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentLight),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),

            if (!_reporting) ...[
              // White plate behind the QR on purpose: scanners fail on an
              // inverted code, and this app is dark everywhere else.
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: QrImageView(
                    data: Counselling.qrPayload(),
                    size: 168,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF13132B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF13132B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              GestureDetector(
                onTap: () => copyUpiId(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space4, vertical: AppTheme.space3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UPI ID',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10.5,
                                    letterSpacing: 0.8,
                                    color: AppTheme.textMuted)),
                            Text(Counselling.upiId,
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      Icon(Icons.copy_rounded,
                          size: 17, color: AppTheme.primaryLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              SacredButton(
                label: 'Open my UPI app',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => openUpiApp(context),
              ),
              const SizedBox(height: AppTheme.space2),
              TextButton(
                onPressed: () => setState(() => _reporting = true),
                child: const Text(
                  'I have paid — send details',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryLight),
                ),
              ),
            ] else ...[
              const Text(
                'Send your payment details',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.space4),
              const Text('Payment mode',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mode,
                    isExpanded: true,
                    dropdownColor: AppTheme.bgCard,
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppTheme.textMuted),
                    items: Counselling.paymentModes
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: AppTheme.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _mode = v ?? _mode),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              const Text('Transaction ID',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _txnCtrl,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. 4193 8471 2205',
                  hintStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              SacredButton(
                label: 'Send to counsellor',
                icon: Icons.send_rounded,
                loading: _sending,
                onTap: _sending ? null : _submit,
              ),
              const SizedBox(height: AppTheme.space2),
              TextButton(
                onPressed: () => setState(() => _reporting = false),
                child: const Text('Back to the QR',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: AppTheme.textMuted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── format choice ───────────────────────────

/// Call or chat, once the payment clears.
class _ModeChoiceCard extends StatelessWidget {
  final CounsellingSession session;
  final CounsellingService service;

  const _ModeChoiceCard({required this.session, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How would you like to talk?',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: AppTheme.space4),
            _option(
              context,
              icon: Icons.videocam_outlined,
              title: '${Counselling.sessionMinutes} minute video call',
              blurb: 'Face to face on Google Meet. Best if you want to be heard.',
              mode: CounsellingMode.meet,
            ),
            const SizedBox(height: AppTheme.space3),
            _option(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Continue with chat',
              blurb: 'Type or send voice notes. Best if writing feels safer.',
              mode: CounsellingMode.chat,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String blurb,
    required CounsellingMode mode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => service.chooseMode(
          sessionId: session.id,
          mode: mode,
          memberName: session.name,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.primaryLight),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(blurb,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            height: 1.4,
                            color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for the rest of the session once a call was chosen, so the link is
/// never more than one scroll away.
class _MeetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.videocam_rounded, size: 18, color: AppTheme.success),
                SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    'Your video call room is ready',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            SacredButton(
              label: 'Join the call',
              icon: Icons.open_in_new_rounded,
              onTap: () => openMeet(context),
            ),
          ],
        ),
      ),
    );
  }
}
