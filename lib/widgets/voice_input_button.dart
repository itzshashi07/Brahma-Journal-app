import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/dictation_service.dart';

class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final double iconSize;
  final VoidCallback? onListenStarted;
  final VoidCallback? onListenStopped;
  final String? languageCode;
  final int? maxLength;
  final String? fieldLabel;
  final bool enabled;
  final DictationService? dictation;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.iconSize = 20,
    this.onListenStarted,
    this.onListenStopped,
    this.languageCode,
    this.maxLength,
    this.fieldLabel,
    this.enabled = true,
    this.dictation,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with WidgetsBindingObserver {
  late final _dictation = widget.dictation ?? DictationService.shared;
  bool _wasListening = false;
  bool _writingTranscript = false;
  String _initialText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dictation.addListener(_changed);
    widget.controller.addListener(_edited);
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_edited);
      widget.controller.addListener(_edited);
      unawaited(_dictation.cancel(this));
    }
    if (!widget.enabled || oldWidget.languageCode != widget.languageCode) {
      unawaited(_dictation.cancel(this));
    }
  }

  void _edited() {
    // A manual edit takes priority over any late recognition result.
    if (!_writingTranscript) unawaited(_dictation.cancel(this));
  }

  void _changed() {
    if (!mounted) return;
    final listening = _dictation.listeningFor(this);
    if (listening != _wasListening) {
      _wasListening = listening;
      if (listening) {
        widget.onListenStarted?.call();
      } else {
        widget.onListenStopped?.call();
      }
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_dictation.cancel(this));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_edited);
    _dictation.removeListener(_changed);
    unawaited(_dictation.cancel(this));
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_dictation.listeningFor(this)) {
      await _dictation.finish(this);
      return;
    }
    _initialText = widget.controller.text;
    if (_initialText.isNotEmpty && !RegExp(r'\s$').hasMatch(_initialText)) {
      _initialText += ' ';
    }
    await _dictation.start(
      owner: this,
      languageCode: widget.languageCode,
      onWords: (words) {
        if (!mounted || words.isEmpty) return;
        var text = _initialText + words;
        if (widget.maxLength != null) {
          text = text.characters.take(widget.maxLength!).toString();
        }
        _writingTranscript = true;
        widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length));
        _writingTranscript = false;
      },
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listening = _dictation.listeningFor(this);
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor:
            listening ? AppTheme.primary.withValues(alpha: .2) : null,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(
          listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
          size: widget.iconSize,
          color: listening ? AppTheme.primaryLight : AppTheme.textSecondary),
      onPressed: widget.enabled && !_dictation.busy ? _toggle : null,
      tooltip: listening
          ? 'Stop voice input'
          : 'Voice input${widget.fieldLabel == null ? '' : ' for ${widget.fieldLabel}'}',
    );
  }
}
