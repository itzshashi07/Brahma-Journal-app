import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One recognizer per app: the platform keeps the first initialize callbacks.
/// Ownership prevents late results from writing into another field or route.
class DictationService extends ChangeNotifier {
  DictationService({
    SpeechToText? speech,
    this.finalResultTimeout = const Duration(milliseconds: 2500),
    this.cancelDrain = const Duration(milliseconds: 150),
  }) : _speech = speech ?? SpeechToText();
  final Duration finalResultTimeout;
  final Duration cancelDrain;
  static final shared = DictationService();
  final SpeechToText _speech;
  Object? _owner, _pendingOwner;
  int _request = 0;
  Completer<void>? _finalResult;
  Future<void>? _finishFuture, _cancelFuture;
  bool _ready = false;
  bool _busy = false;
  bool _listening = false;
  int _generation = 0;
  void Function(String)? _onError;
  bool _disposed = false, _notificationQueued = false;

  void _notify() {
    if (_notificationQueued || _disposed) return;
    _notificationQueued = true;
    scheduleMicrotask(() {
      _notificationQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    _pendingOwner = null;
    final owner = _owner;
    if (owner != null) unawaited(cancel(owner));
    super.dispose();
  }

  Future<void> cancelActive() async {
    final pending = _pendingOwner;
    if (pending != null) await cancel(pending);
    final owner = _owner;
    if (owner != null) await cancel(owner);
  }

  Future<void> finishActive() async {
    final owner = _owner;
    if (owner != null) await finish(owner);
  }

  bool get busy => _busy || _finishFuture != null || _cancelFuture != null;
  bool listeningFor(Object owner) => identical(owner, _owner) && _listening;

  Future<void> start({
    required Object owner,
    required ValueChanged<String> onWords,
    required ValueChanged<String> onError,
    String? languageCode,
  }) async {
    if (busy || _disposed) return;
    _busy = true;
    final request = ++_request;
    _pendingOwner = owner;
    _notify();
    int? generation;
    try {
      // Native callbacks have no session ID. Finish the previous recognizer
      // before changing its result listener, so its final words stay in its field.
      final previous = _owner;
      if (previous != null) await finish(previous);
      if (_disposed || request != _request) return;
      _pendingOwner = null;
      _owner = owner;
      generation = ++_generation;
      _finalResult = Completer<void>();
      _onError = onError;
      _ready = await _speech.initialize(
        onStatus: (status) {
          if (_owner == null) return;
          _listening = status == 'listening';
          _notify();
        },
        onError: (error) {
          _listening = false;
          _completeFinal();
          _onError?.call(_errorMessage(error.errorMsg));
          _notify();
        },
      );
      if (generation != _generation) return;
      if (!_ready) {
        onError(
            'Voice typing is unavailable. Allow microphone access in your phone settings, or keep typing.');
        _completeFinal();
        return;
      }
      String? localeId;
      if (languageCode != null) {
        final locales = await _speech.locales();
        if (generation != _generation) return;
        final matches = locales.where((locale) =>
            locale.localeId.replaceAll('_', '-').split('-').first ==
            languageCode);
        if (matches.isEmpty) {
          onError(
              'This voice language is unavailable on your phone. Try the phone default or type your words.');
          _completeFinal();
          return;
        }
        localeId = matches.first.localeId;
        for (final locale in matches) {
          if (locale.localeId
              .replaceAll('_', '-')
              .toLowerCase()
              .endsWith('-in')) {
            localeId = locale.localeId;
          }
        }
      }
      _listening = true;
      _notify();
      await _speech.listen(
        onResult: (result) {
          if (generation == _generation && identical(owner, _owner)) {
            if (result.recognizedWords.isNotEmpty) {
              onWords(result.recognizedWords);
            }
            if (result.finalResult) {
              _listening = false;
              _completeFinal();
              _notify();
            }
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (generation == _generation) {
        _listening = false;
        _completeFinal();
        onError(
            'Voice typing could not start. Check microphone access and your connection, then try again.');
      }
    } finally {
      if (request == _request) _pendingOwner = null;
      _busy = false;
      _notify();
    }
  }

  void _completeFinal() {
    final result = _finalResult;
    if (result != null && !result.isCompleted) result.complete();
  }

  /// User Stop / Save requests a final transcript before releasing the field.
  /// A recognizer that never responds cannot leave the editor stuck waiting.
  Future<void> finish(Object owner) {
    if (!identical(owner, _owner)) return Future.value();
    return _finishFuture ??= _finish(owner);
  }

  Future<void> _finish(Object owner) async {
    final generation = _generation;
    final finalResult = _finalResult;
    _listening = false;
    _notify();
    try {
      if (_ready && finalResult != null && !finalResult.isCompleted) {
        await _speech.stop().timeout(const Duration(seconds: 1));
        await finalResult.future.timeout(finalResultTimeout);
      }
    } catch (_) {
      // Keep the newest visible partial transcript when the platform times out.
    } finally {
      if (generation == _generation) _detach();
      await _cancelNative();
      _finishFuture = null;
      _notify();
    }
  }

  void _detach() {
    ++_generation;
    _owner = null;
    _onError = null;
    _listening = false;
    _completeFinal();
    _notify();
  }

  Future<void> _cancelNative() async {
    if (!_ready) return;
    try {
      await _speech.cancel().timeout(const Duration(seconds: 1));
    } catch (_) {
      // The owner has already been detached; late callbacks cannot edit it.
    }
    // Android acknowledges cancel before posting the native cancel operation.
    // Drain its queued status/error events before a new listen binds callbacks.
    if (cancelDrain > Duration.zero) await Future<void>.delayed(cancelDrain);
  }

  /// Detach immediately, so navigating away cannot alter a disposed editor.
  /// Keep the latest visible transcript; users can review it before saving.
  Future<void> cancel(Object owner) async {
    if (identical(owner, _pendingOwner)) {
      ++_request;
      _pendingOwner = null;
    }
    if (!identical(owner, _owner)) return;
    _detach();
    final finishing = _finishFuture;
    if (finishing != null) {
      await finishing;
    } else {
      _cancelFuture ??= _cancelNative();
      _notify();
      await _cancelFuture;
      _cancelFuture = null;
      _notify();
    }
  }

  String _errorMessage(String code) {
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      return 'No words heard. Tap the mic and try a short sentence.';
    }
    if (code.contains('permission') || code.contains('permission_denied')) {
      return 'Allow microphone access in your phone settings to use voice typing.';
    }
    if (code.contains('network')) {
      return 'Voice typing needs a connection on this phone. Your typed words are safe.';
    }
    return 'Voice typing stopped. Your words are still here; tap the mic to retry.';
  }
}
