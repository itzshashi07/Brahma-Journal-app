import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
// The fake drives real plugin callback routing rather than saved Dart closures.
// ignore: depend_on_referenced_packages
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:brahma_app/services/dictation_service.dart';
import 'package:brahma_app/widgets/voice_input_button.dart';

class FakeSpeech extends SpeechToText {
  FakeSpeech() : super.withMethodChannel();
  bool available = true, failListen = false;
  int listens = 0, cancellations = 0;
  Completer<bool>? initialization;
  SpeechResultListener? result;
  SpeechStatusListener? status;
  SpeechListenOptions? options;
  @override
  Future<bool> initialize(
      {SpeechErrorListener? onError,
      SpeechStatusListener? onStatus,
      dynamic debugLogging = false,
      Duration finalTimeout = SpeechToText.defaultFinalTimeout,
      List<SpeechConfigOption>? options}) async {
    status = onStatus;
    return initialization == null ? available : initialization!.future;
  }

  @override
  Future<List<LocaleName>> locales() async => [
        LocaleName('en_US', 'English'),
        LocaleName('en_IN', 'English India'),
        LocaleName('hi_IN', 'Hindi')
      ];
  @override
  Future<void> listen(
      {SpeechResultListener? onResult,
      Duration? listenFor,
      Duration? pauseFor,
      String? localeId,
      SpeechSoundLevelChange? onSoundLevelChange,
      dynamic cancelOnError = false,
      dynamic partialResults = true,
      dynamic onDevice = false,
      ListenMode listenMode = ListenMode.confirmation,
      dynamic sampleRate = 0,
      SpeechListenOptions? listenOptions}) async {
    if (failListen) throw Exception('recognizer failed');
    listens++;
    result = onResult;
    options = listenOptions;
    status?.call('listening');
  }

  @override
  Future<void> stop() async {
    result?.call(SpeechRecognitionResult([], 1));
    status?.call('done');
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    status?.call('notListening');
  }

  void words(String words) => result?.call(
      SpeechRecognitionResult([SpeechRecognitionWords(words, null, 1)], 0));
}

/// Uses SpeechToText.withMethodChannel unchanged, including its single mutable
/// result listener and first-initialize status/error listeners.
class NativeSpeech extends SpeechToTextPlatform {
  int listens = 0, stops = 0, cancellations = 0;
  String? locale;
  Completer<void>? stopRequested;
  @override
  Future<bool> initialize(
          {dynamic debugLogging = false,
          List<SpeechConfigOption>? options}) async =>
      true;
  @override
  Future<List<String>> locales() async =>
      ['en_US:English', 'en_IN:English India', 'hi_IN:Hindi'];
  @override
  Future<bool> listen(
      {String? localeId,
      dynamic partialResults = true,
      dynamic onDevice = false,
      int listenMode = 0,
      dynamic sampleRate = 0,
      SpeechListenOptions? options}) async {
    listens++;
    locale = localeId;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    onStatus?.call('notListening');
    // Android may send this before a final-only result arrives.
    onStatus?.call('doneNoResult');
    if (stopRequested?.isCompleted == false) stopRequested!.complete();
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    onStatus?.call('notListening');
    onStatus?.call('doneNoResult');
  }

  void words(String text, {bool finalResult = false}) {
    onTextRecognition?.call(jsonEncode(SpeechRecognitionResult(
            [SpeechRecognitionWords(text, null, 1)], finalResult ? 1 : 0)
        .toJson()));
  }
}

void main() {
  testWidgets(
      'dictation appends partial words without duplication; manual edit wins',
      (tester) async {
    final speech = FakeSpeech();
    final service =
        DictationService(speech: speech, cancelDrain: Duration.zero);
    final text = TextEditingController(text: 'Today');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceInputButton(
                controller: text, dictation: service, languageCode: 'hi'))));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    speech.words('I tried');
    speech.words('I tried again');
    await tester.pump();
    expect(text.text, 'Today I tried again');
    expect(text.selection.baseOffset, text.text.length);
    expect(speech.options!.localeId, 'hi_IN');
    final lateResult = speech.result;
    text.text = 'My own edit';
    lateResult!(SpeechRecognitionResult(
        [const SpeechRecognitionWords('late words', null, 1)], 1));
    await tester.pump();
    expect(text.text, 'My own edit');
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    service.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'leaving during microphone permission cannot start recording later',
      (tester) async {
    final speech = FakeSpeech()..initialization = Completer<bool>();
    final service =
        DictationService(speech: speech, cancelDrain: Duration.zero);
    final text = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceInputButton(controller: text, dictation: service))));
    await tester.tap(find.byType(IconButton));
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    speech.initialization!.complete(true);
    await tester.pump();
    expect(speech.listens, 0);
    service.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable recognizer and start failure keep typed words',
      (tester) async {
    final speech = FakeSpeech()..available = false;
    final service =
        DictationService(speech: speech, cancelDrain: Duration.zero);
    final text = TextEditingController(text: 'Keep this');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceInputButton(controller: text, dictation: service))));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voice typing is unavailable.'), findsOneWidget);
    expect(text.text, 'Keep this');
    speech.available = true;
    speech.failListen = true;
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(text.text, 'Keep this');
    expect(find.byTooltip('Voice input'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    service.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding cancels dictation and length limit handles emoji',
      (tester) async {
    final speech = FakeSpeech();
    final service =
        DictationService(speech: speech, cancelDrain: Duration.zero);
    final text = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceInputButton(
                controller: text, dictation: service, maxLength: 3))));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    speech.words('🙂🙂🙂🙂');
    expect(text.text, '🙂🙂🙂');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    speech.words('Late speech');
    expect(text.text, '🙂🙂🙂');
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    text.dispose();
    service.dispose();
    expect(tester.takeException(), isNull);
  });

  group('real plugin callback routing', () {
    late SpeechToTextPlatform original;
    late NativeSpeech native;
    late DictationService service;
    setUp(() {
      original = SpeechToTextPlatform.instance;
      native = NativeSpeech();
      SpeechToTextPlatform.instance = native;
      service = DictationService(
        speech: SpeechToText.withMethodChannel(),
        finalResultTimeout: const Duration(milliseconds: 60),
        cancelDrain: const Duration(milliseconds: 10),
      );
    });
    tearDown(() async {
      await service.cancelActive();
      service.dispose();
      SpeechToTextPlatform.instance = original;
    });

    test('Stop retains a final-only result after native done status', () async {
      final owner = Object(), received = <String>[];
      await service.start(owner: owner, onWords: received.add, onError: (_) {});
      native.stopRequested = Completer<void>();
      final finishing = service.finish(owner);
      await native.stopRequested!.future;
      expect(service.busy, true);
      expect(received, isEmpty);
      native.words('Only available after stop', finalResult: true);
      await finishing;
      expect(received, ['Only available after stop']);
      expect(service.busy, false);
    });

    test('switch waits for old native final before binding the next field',
        () async {
      final first = Object(), second = Object();
      final one = <String>[], two = <String>[];
      await service.start(owner: first, onWords: one.add, onError: (_) {});
      native.stopRequested = Completer<void>();
      final switching = service.start(
          owner: second, onWords: two.add, onError: (_) {}, languageCode: 'en');
      await native.stopRequested!.future;
      expect(native.listens, 1);
      native.words('First field final words', finalResult: true);
      await switching;
      expect(native.listens, 2);
      expect(one, ['First field final words']);
      expect(two, isEmpty);
      native.words('Second field words');
      expect(two, ['Second field words']);
      expect(native.locale, 'en_IN');
    });

    test(
        'manual edit cancellation during finalization rejects late native words',
        () async {
      final owner = Object(), received = <String>[];
      await service.start(owner: owner, onWords: received.add, onError: (_) {});
      native.stopRequested = Completer<void>();
      final finishing = service.finishActive();
      await native.stopRequested!.future;
      final cancelling = service.cancel(owner);
      native.words('Must not overwrite manual edits', finalResult: true);
      await Future.wait([finishing, cancelling]);
      expect(received, isEmpty);
      expect(service.busy, false);
    });

    test('missing final has bounded fallback and ignores drained native events',
        () async {
      final owner = Object(), received = <String>[];
      await service.start(owner: owner, onWords: received.add, onError: (_) {});
      native.words('Keep the partial words');
      await service.finishActive().timeout(const Duration(seconds: 1));
      native.words('Too late', finalResult: true);
      expect(received, ['Keep the partial words']);
      expect(native.cancellations, greaterThan(0));
      expect(service.busy, false);
    });

    test('leaving the pending next field prevents its later microphone start',
        () async {
      final first = Object(), second = Object();
      await service.start(owner: first, onWords: (_) {}, onError: (_) {});
      native.stopRequested = Completer<void>();
      final switching =
          service.start(owner: second, onWords: (_) {}, onError: (_) {});
      await native.stopRequested!.future;
      await service.cancel(second);
      native.words('Finish first', finalResult: true);
      await switching;
      expect(native.listens, 1);
      expect(service.busy, false);
    });
  });
}
