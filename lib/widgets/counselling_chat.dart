import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
            if (message.kind == ChatKind.audio)
              _VoiceNotePlayer(url: message.audioUrl, seconds: message.audioSeconds, mine: mine)
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
class _VoiceNotePlayer extends StatefulWidget {
  final String url;
  final int seconds;
  final bool mine;

  const _VoiceNotePlayer({
    required this.url,
    required this.seconds,
    required this.mine,
  });

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  double _progress = 0;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;

    if (_playing) {
      await _player?.pause();
      return;
    }

    if (_player == null) {
      setState(() => _loading = true);
      try {
        final p = AudioPlayer();
        await p.setUrl(widget.url);
        _stateSub = p.playerStateStream.listen((s) {
          if (!mounted) return;
          setState(() => _playing = s.playing &&
              s.processingState != ProcessingState.completed);
          if (s.processingState == ProcessingState.completed) {
            p.seek(Duration.zero);
            p.pause();
            setState(() => _progress = 0);
          }
        });
        _posSub = p.positionStream.listen((pos) {
          if (!mounted) return;
          final total = p.duration?.inMilliseconds ?? 0;
          setState(() =>
              _progress = total == 0 ? 0 : pos.inMilliseconds / total);
        });
        _player = p;
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not play this voice note.',
                  style: TextStyle(fontFamily: 'Outfit')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _loading = false);
    }

    await _player?.play();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppTheme.primaryLight;
    final track = widget.mine
        ? Colors.white.withValues(alpha: 0.3)
        : AppTheme.primary.withValues(alpha: 0.25);

    return SizedBox(
      width: 190,
      child: Row(
        children: [
          GestureDetector(
            onTap: _loading ? null : _toggle,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppTheme.primary.withValues(alpha: 0.2),
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20, color: fg),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: track,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatSeconds(widget.seconds),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10.5,
                    color: widget.mine
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSeconds(int s) {
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

// ─────────────────────────── composer ───────────────────────────

/// The bar at the bottom of the chat: text, emoji, voice.
///
/// Recording is tap-to-start / tap-to-stop rather than press-and-hold. Holding
/// a button steady for a minute is hard for anyone whose hands are shaking,
/// which is a real description of some of the people who will use this.
class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final void Function(File file, int seconds) onSendVoice;
  final bool enabled;
  final String disabledHint;

  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    this.enabled = true,
    this.disabledHint = 'This session has ended.',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _ctrl = TextEditingController();
  final _recorder = AudioRecorder();

  bool _emojiOpen = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _ctrl.dispose();
    _recorder.dispose();
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

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording(send: true);
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) _toast('Microphone permission is needed for voice notes.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: path,
      );
      _recordPath = path;
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _emojiOpen = false;
      });
      _recordTimer =
          Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        // Three minutes is long enough for anything anyone wants to say in one
        // breath, and short enough that an accidental recording left running in
        // a pocket does not become a 40 MB upload.
        if (_recordSeconds >= 180) await _stopRecording(send: true);
      });
    } catch (e) {
      if (mounted) _toast('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    setState(() {
      _recording = false;
      _recordSeconds = 0;
    });

    try {
      final path = await _recorder.stop() ?? _recordPath;
      if (path == null) return;
      final file = File(path);
      if (!send || seconds < 1 || !file.existsSync()) {
        if (file.existsSync()) await file.delete();
        return;
      }
      widget.onSendVoice(file, seconds);
    } catch (e) {
      if (mounted) _toast('Could not save that recording: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: Colors.redAccent,
      ),
    );
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
            if (_recording) _recordingBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.space2,
                  AppTheme.space2, AppTheme.space2, AppTheme.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: _recording
                        ? null
                        : () {
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
                        enabled: !_recording,
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
                          hintText: _recording
                              ? 'Recording…'
                              : 'Write what is on your mind…',
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

  /// One button that is the microphone until there is something to send, then
  /// becomes send. Two permanently visible buttons make the wrong one easy to
  /// hit, and this is not a screen where a mis-tap should cost anything.
  Widget _actionButton() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final isSend = hasText && !_recording;

    return GestureDetector(
      onTap: isSend ? _send : _toggleRecording,
      onLongPress: _recording ? () => _stopRecording(send: false) : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: _recording ? null : AppTheme.primaryGradient,
          color: _recording ? Colors.redAccent : null,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSend
              ? Icons.send_rounded
              : (_recording ? Icons.stop_rounded : Icons.mic_rounded),
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }

  Widget _recordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4, vertical: AppTheme.space2),
      color: Colors.redAccent.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, size: 12, color: Colors.redAccent),
          const SizedBox(width: AppTheme.space2),
          Text(
            'Recording  ${_formatSeconds(_recordSeconds)}',
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _stopRecording(send: false),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    color: AppTheme.textMuted)),
          ),
        ],
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
