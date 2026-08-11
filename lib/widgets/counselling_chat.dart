
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/counselling.dart';
import '../core/theme/app_theme.dart';
import '../models/counselling_session.dart';

/// The chat room's parts: bubbles, the emoji panel, the voice recorder.
///
/// Split out of the screens because the member and the admin sit in the same
/// room from opposite sides. One implementation means a voice note cannot look
/// or behave differently depending on who is reading it — which, in a
/// counselling context, is the kind of asymmetry that erodes trust.

// ─────────────────────────── bubbles ───────────────────────────

/// One message.
///
/// System notes are centred and unattributed on purpose: automation must never
/// be mistaken for the counsellor. Everything a human said sits in a bubble
/// with a side and a time.
class ChatBubbleView extends StatelessWidget {
  final ChatMessage message;

  /// True when this message was sent by whoever is looking at the screen.
  final bool mine;

  const ChatBubbleView({
    super.key,
    required this.message,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    if (message.sender == ChatSender.system) return _systemNote();

    final time = DateFormat('h:mm a').format(message.createdAt);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(
            vertical: 4, horizontal: AppTheme.space4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          gradient: mine ? AppTheme.primaryGradient : null,
          color: mine ? null : AppTheme.bgCardLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          border: mine
              ? null
              : Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.sender == ChatSender.admin
                      ? 'Your counsellor'
                      : 'Member',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.primaryLight.withValues(alpha: 0.9),
                  ),
                ),
              ),
            // Voice notes were removed along with the Storage bucket they
            // required. No message of this kind can exist — none was ever
            // written successfully — but the branch stays so a stray document
            // renders as something rather than as blank space.
            if (message.kind == ChatKind.audio)
              Text(
                'Voice note (no longer supported)',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: mine ? Colors.white70 : AppTheme.textMuted,
                ),
              )
            else if (message.kind == ChatKind.payment)
              _paymentCard()
            else
              Text(
                message.text,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14.5,
                  height: 1.45,
                  color: mine ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                time,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 9.5,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 16, color: mine ? Colors.white : AppTheme.accentLight),
          const SizedBox(width: AppTheme.space2),
          Flexible(
            child: Text(
              message.text,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                height: 1.5,
                color: mine ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space5, vertical: AppTheme.space3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            height: 1.6,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A voice note, with a play button and its length.
///
/// Loads its audio the first time it is played rather than on build: a chat
/// with twenty voice notes would otherwise open twenty players and twenty
/// network requests at once.
// ─────────────────────────── composer ───────────────────────────

/// The bar at the bottom of the chat: text and emoji.
///
/// It used to record voice notes too. Those needed Cloud Storage, which this
/// project does not have provisioned, so rather than ship a microphone button
/// that silently swallowed what people recorded, the feature is gone.
class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final bool enabled;
  final String disabledHint;

  const ChatComposer({
    super.key,
    required this.onSendText,
    this.enabled = true,
    this.disabledHint = 'This session has ended.',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _ctrl = TextEditingController();

  bool _emojiOpen = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _ctrl.clear();
    setState(() {});
  }

  void _insertEmoji(String e) {
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    // Respects the caret so an emoji added mid-sentence lands where the user is
    // looking, not at the end of the line.
    if (sel.start < 0 || sel.end < 0) {
      _ctrl.text = text + e;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    } else {
      final next = text.replaceRange(sel.start, sel.end, e);
      _ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start + e.length),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Text(
          widget.disabledHint,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textMuted),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.space2,
                  AppTheme.space2, AppTheme.space2, AppTheme.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _emojiOpen = !_emojiOpen);
                    },
                    icon: Icon(
                      _emojiOpen
                          ? Icons.keyboard_alt_outlined
                          : Icons.emoji_emotions_outlined,
                      color: _emojiOpen
                          ? AppTheme.primaryLight
                          : AppTheme.textMuted,
                      size: 23,
                    ),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onTap: () => setState(() => _emojiOpen = false),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14.5,
                            color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Write what is on your mind…',
                          hintStyle: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13.5,
                              color: AppTheme.textMuted),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _actionButton(),
                ],
              ),
            ),
            if (_emojiOpen) _emojiPanel(),
          ],
        ),
      ),
    );
  }

  /// Send. It used to double as a microphone, becoming send once there was
  /// text to send; with voice notes gone it has one job and looks like it.
  Widget _actionButton() {
    final hasText = _ctrl.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasText ? _send : null,
      child: Opacity(
        opacity: hasText ? 1 : 0.45,
        child: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _emojiPanel() {
    return Container(
      height: 196,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
      color: Colors.white.withValues(alpha: 0.03),
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
        children: Counselling.emojis
            .map((e) => InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () => _insertEmoji(e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 25)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
