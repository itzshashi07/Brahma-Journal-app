import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme/app_theme.dart';

class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final double iconSize;
  final VoidCallback? onListenStarted;
  final VoidCallback? onListenStopped;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.iconSize = 20.0,
    this.onListenStarted,
    this.onListenStopped,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  String _initialText = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    print('DEBUG: Mic button pressed. _isListening: $_isListening, _isInitialized: $_isInitialized');
    if (!_isListening) {
      if (!_isInitialized) {
        try {
          bool available = await _speech.initialize(
            onStatus: (status) {
              print('DEBUG: Speech status change: $status');
              if (status == 'done' || status == 'notListening') {
                _stopListeningState();
              }
            },
            onError: (errorNotification) {
              print('DEBUG: Speech error notification: ${errorNotification.errorMsg}');
              _stopListeningState();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Voice error: ${errorNotification.errorMsg}',
                    style: const TextStyle(fontFamily: 'Outfit'),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
          );
          print('DEBUG: Speech initialize outcome (available): $available');
          if (available) {
            _isInitialized = true;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Speech recognition not available on this device.',
                  style: TextStyle(fontFamily: 'Outfit'),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        } catch (e) {
          print('DEBUG: Speech initialize threw exception: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initialize speech: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      _initialText = widget.controller.text;
      if (_initialText.isNotEmpty && !_initialText.endsWith(' ')) {
        _initialText += ' ';
      }

      setState(() {
        _isListening = true;
        _pulseController.repeat(reverse: true);
      });
      if (widget.onListenStarted != null) widget.onListenStarted!();

      await _speech.listen(
        onResult: (result) {
          setState(() {
            widget.controller.text = _initialText + result.recognizedWords;
          });
        },
      );
    } else {
      _speech.stop();
      _stopListeningState();
    }
  }

  void _stopListeningState() {
    if (mounted) {
      setState(() {
        _isListening = false;
        _pulseController.reset();
      });
      if (widget.onListenStopped != null) widget.onListenStopped!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _isListening
          ? Tween<double>(begin: 1.0, end: 1.15).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            )
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isListening
              ? AppTheme.primary.withOpacity(0.2)
              : Colors.transparent,
          boxShadow: _isListening
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: IconButton(
          icon: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening ? AppTheme.primaryLight : AppTheme.textMuted,
            size: widget.iconSize,
          ),
          onPressed: _toggleListening,
          tooltip: _isListening ? 'Stop listening' : 'Start voice input',
        ),
      ),
    );
  }
}
