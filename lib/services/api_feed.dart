import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_messaging_service.dart';

/// A `Stream` backed by a REST endpoint instead of an open socket.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What this is for
///
/// Every screen in this app that shows a list used to be a `StreamBuilder` over
/// a Firestore `snapshots()` call. That is a websocket, held open for as long
/// as the widget is mounted, per query, per device. The Sanctuary, the
/// counselling inbox, the chat, the support queue, the admin alerts and the
/// reflections watchlist were six of them, and a member with the app open was
/// paying for all six whether or not anything was changing.
///
/// MongoDB has no client-side realtime channel, so those listeners have to go
/// regardless of what anyone thinks of them. The question is what replaces
/// them, and the honest answer for this app is: **fetch when something
/// happened**, because the server already knows when something happened and
/// already has a way to say so.
///
/// So a feed reloads on exactly three events:
///
///   1. **On open.** The widget subscribes, the data arrives.
///   2. **On a push.** FCM delivers a data-only message the moment the server
///      writes something worth knowing about, and [FirebaseMessagingService]
///      re-broadcasts it. That is the same signal the listener was giving,
///      arriving over a connection the device is already paying for — and
///      unlike the listener, it also arrives when the app is closed.
///   3. **On demand.** [refresh], wired to pull-to-refresh and called after the
///      screen's own writes.
///
/// Nothing polls on a timer. A timer would be strictly worse than the listener
/// it replaced: the same held resource, plus latency, plus traffic on a quiet
/// app. If a feed looks stale, the fix is a push for the event that changed it,
/// not a shorter interval.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Why it is still a Stream
///
/// Because the screens are already written against one, and rewriting a dozen
/// `StreamBuilder`s into `FutureBuilder` plus manual state is a large diff that
/// changes what the UI does as well as where the data comes from. Keeping the
/// shape means this swap is about the transport and nothing else.
class ApiFeed<T> {
  /// [load] fetches the current value. [refreshOnPush] is for feeds no push
  /// relates to — the remote config, for instance, which changes when an
  /// operator publishes a release and never announces itself.
  ApiFeed(this._load, {bool refreshOnPush = true, this.debugLabel = 'feed'})
      : _refreshOnPush = refreshOnPush;

  final Future<T> Function() _load;
  final bool _refreshOnPush;
  final String debugLabel;

  final _controller = StreamController<T>.broadcast();
  StreamSubscription? _pushSub;

  T? _value;
  bool _hasValue = false;

  /// Guards against two overlapping loads — a push landing while the initial
  /// fetch is still in flight would otherwise run the query twice and emit the
  /// results in whichever order they happened to come back.
  Future<void>? _inFlight;

  /// The most recent value, or null if nothing has arrived yet. Useful to a
  /// caller that wants to act on the data without subscribing.
  T? get value => _value;

  /// Subscribing starts the feed. A late subscriber is handed the value that is
  /// already in hand before it starts waiting for the next one, so opening a
  /// screen a second time draws immediately rather than flashing a spinner over
  /// data the app already has.
  Stream<T> get stream {
    _bind();

    return () async* {
      if (_hasValue) yield _value as T;
      yield* _controller.stream;
    }();
  }

  void _bind() {
    if (!_hasValue && _inFlight == null) unawaited(refresh());

    if (_refreshOnPush && _pushSub == null) {
      _pushSub = FirebaseMessagingService().messages.listen((_) => refresh());
    }
  }

  /// Re-reads the endpoint and emits the result.
  ///
  /// A failure is logged and swallowed rather than emitted as a stream error.
  /// An error would tear the subscription down — `StreamBuilder` reports it
  /// once and then receives nothing further — so a single dropped request on a
  /// train would leave the screen permanently dead until it was rebuilt. The
  /// last good value stays on screen instead, which is what a member expects
  /// from a list that has already loaded.
  Future<void> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final run = _load().then((data) {
      _value = data;
      _hasValue = true;
      if (!_controller.isClosed) _controller.add(data);
    }).catchError((Object e) {
      debugPrint('⚠️ $debugLabel: could not refresh: $e');
    }).whenComplete(() {
      _inFlight = null;
    });

    _inFlight = run;
    return run;
  }

  /// Throws away what is held so the next subscriber fetches afresh. Called on
  /// sign-out: the next person to use this handset must not be shown the
  /// previous one's inbox while their own is loading.
  void clear() {
    _value = null;
    _hasValue = false;
  }

  Future<void> dispose() async {
    await _pushSub?.cancel();
    _pushSub = null;
    await _controller.close();
  }
}
