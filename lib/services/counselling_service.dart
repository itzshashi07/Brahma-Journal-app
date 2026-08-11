import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/counselling_session.dart';
import 'api_feed.dart';
import 'api_service.dart';

/// The counselling room, over the API.
///
/// ─────────────────────────────────────────────────────────────────────────
/// What changed, and why it is not just a transport swap
///
/// This class used to talk to Firestore directly, and it held four open
/// `snapshots()` listeners: the member's sessions, every session for the admin
/// inbox, one session, and one transcript. It also *drove the flow* — it wrote
/// the scripted messages, it computed `purgeAfter` from the handset's clock,
/// and it raised its own admin alerts.
///
/// All three of those have moved to the server, and each for a reason of its
/// own:
///
///   • **The listeners** had to go: MongoDB has no client realtime channel.
///     What replaces them is [ApiFeed] — read on open, re-read when FCM says
///     something happened. Unlike the listeners, that also works when the app
///     has been killed, which is the case that mattered most here. Somebody who
///     closed the app never found out their counsellor had replied.
///
///   • **The scripted messages** were being written by whichever handset
///     happened to make the state change. If the counsellor's app died between
///     "approve" and "post the approval message", the member's session went
///     live with nothing in the chat explaining why. The server writes both in
///     one request now.
///
///   • **`purgeAfter`** was computed on the device. A wrong clock could
///     lengthen the two-hour retention window on the most sensitive data this
///     app holds. It is stamped from the server's clock and enforced by a
///     MongoDB TTL index, which deletes whether or not anybody opens the app —
///     so [purgeExpired], which used to run from both sides on every screen
///     open, has no work left to do and is gone.
///
/// What is left here is a thin client: request, parse, hand back.
class CounsellingService {
  final ApiService _api = ApiService();

  /// How long a finished conversation is kept before it is destroyed.
  ///
  /// Kept as a constant because the chat screen counts it down on screen. The
  /// server owns the actual deadline — this is for rendering, not for deciding.
  static const retention = Duration(hours: 2);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────── reading ───────────────────────────

  /// The member's own sessions, newest first.
  ///
  /// One feed per instance rather than one per call: two widgets asking for the
  /// member's sessions should share a fetch, not race each other into two.
  ApiFeed<List<CounsellingSession>>? _mine;
  ApiFeed<List<CounsellingSession>>? _all;
  final Map<String, ApiFeed<List<ChatMessage>>> _transcripts = {};

  Stream<List<CounsellingSession>> streamMine() {
    if (_uid == null) return Stream.value(const []);
    _mine ??= ApiFeed(_loadMine, debugLabel: 'counselling/mine');
    return _mine!.stream;
  }

  /// Every session, for the admin inbox. The server refuses this to anyone
  /// without the claim, so there is no privilege asserted here.
  Stream<List<CounsellingSession>> streamAll() {
    _all ??= ApiFeed(_loadAll, debugLabel: 'counselling/inbox');
    return _all!.stream;
  }

  Stream<List<ChatMessage>> streamMessages(String sessionId) {
    final feed = _transcripts.putIfAbsent(
      sessionId,
      () => ApiFeed(
        () => _loadMessages(sessionId),
        debugLabel: 'counselling/messages',
      ),
    );
    return feed.stream;
  }

  /// One session, re-read whenever a push says something moved.
  Stream<CounsellingSession?> streamSession(String id) =>
      ApiFeed<CounsellingSession?>(
        () => session(id),
        debugLabel: 'counselling/session',
      ).stream;

  Future<CounsellingSession?> session(String id) async {
    try {
      final body = await _api.get('/api/counselling/sessions/$id');
      final raw = body?['session'];
      return raw == null
          ? null
          : CounsellingSession.fromJson(Map<String, dynamic>.from(raw));
    } on ApiException catch (e) {
      // A session that has been purged is a 404, and that is not an error — it
      // is the promise being kept.
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<CounsellingSession>> _loadMine() async {
    final body = await _api.get('/api/counselling/sessions');
    return _sessions(body?['sessions']);
  }

  Future<List<CounsellingSession>> _loadAll() async {
    final body = await _api.get('/api/counselling/inbox');
    return _sessions(body?['sessions']);
  }

  Future<List<ChatMessage>> _loadMessages(String sessionId) async {
    final body = await _api.get(
      '/api/counselling/sessions/$sessionId/messages',
      query: {'limit': '200'},
    );
    final raw = (body?['messages'] as List?) ?? const [];
    return raw
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// The server already sorts newest-first; this keeps the ordering explicit so
  /// a change at either end cannot silently reverse the inbox.
  List<CounsellingSession> _sessions(dynamic raw) {
    final list = ((raw as List?) ?? const [])
        .map((s) =>
            CounsellingSession.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Re-reads whatever is on screen. Wired to pull-to-refresh, and called after
  /// this class's own writes so the change is visible without waiting for the
  /// push that announces it.
  Future<void> refresh({String? sessionId}) async {
    await Future.wait([
      if (_mine != null) _mine!.refresh(),
      if (_all != null) _all!.refresh(),
      if (sessionId != null && _transcripts.containsKey(sessionId))
        _transcripts[sessionId]!.refresh(),
    ]);
  }

  // ─────────────────────────── intake ───────────────────────────

  /// Opens a session. The welcome and the payment instructions are written by
  /// the server in the same request — see config/counselling.js in the API.
  Future<String> createSession({
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String concern,
    required String language,
    required String details,
  }) async {
    if (_uid == null) throw StateError('Not signed in');

    final body = await _api.post('/api/counselling/sessions', {
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'concern': concern,
      'language': language,
      'details': details,
    });

    await refresh();
    return '${body?['session']?['_id'] ?? ''}';
  }

  // ─────────────────────────── payment ───────────────────────────

  /// The member reports what they paid and how. Verification is a human reading
  /// a bank statement — this only records the claim.
  ///
  /// `memberName` is no longer passed: the server reads the name off the
  /// session it is already loading, so the operator alert cannot be addressed
  /// to whatever the client felt like sending.
  Future<void> submitPayment({
    required String sessionId,
    required String paymentMode,
    required String transactionId,
  }) async {
    await _api.post('/api/counselling/sessions/$sessionId/payment', {
      'paymentMode': paymentMode,
      'transactionId': transactionId,
    });
    await refresh(sessionId: sessionId);
  }

  /// Admin: payment checked and confirmed.
  Future<void> approve(String sessionId) => _setStatus(sessionId, 'approved');

  /// Admin: payment could not be found. Deliberately reversible — the member is
  /// put back in front of the payment form rather than shown a dead end.
  Future<void> reject(String sessionId) => _setStatus(sessionId, 'rejected');

  // ─────────────────────────── format ───────────────────────────

  /// The member picks a video call or a chat.
  ///
  /// Chat goes live immediately. A call becomes a *request* and waits for a
  /// counsellor to confirm and issue a room — see the note on
  /// [CounsellingStatus.meetRequested].
  Future<void> chooseMode({
    required String sessionId,
    required CounsellingMode mode,
  }) async {
    await _api.post('/api/counselling/sessions/$sessionId/mode', {
      'mode': mode.wire,
    });
    await refresh(sessionId: sessionId);
  }

  /// Admin: confirm the call and issue a room for this session.
  ///
  /// The link is validated server-side as well. Checking it here too is not
  /// redundancy for its own sake — it is the difference between the counsellor
  /// seeing "that does not look like a meeting link" while the field is still
  /// in front of them, and a member waiting for a call that cannot happen.
  Future<void> approveMeeting({
    required String sessionId,
    required String link,
  }) async {
    final trimmed = link.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        !uri.isAbsolute ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('That does not look like a meeting link.');
    }

    await _api.patch('/api/counselling/sessions/$sessionId/status', {
      'status': 'active',
      'meetLink': trimmed,
    });
    await refresh(sessionId: sessionId);
  }

  // ─────────────────────────── messages ───────────────────────────

  /// Sends a message.
  ///
  /// The `sender` argument is gone. It was decided by the app, which meant a
  /// member's build could label its own message `admin` and impersonate a
  /// counsellor in the transcript. The server derives the role from the
  /// verified token instead, so there is nothing here to get wrong.
  Future<void> sendText({
    required String sessionId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _api.post('/api/counselling/sessions/$sessionId/messages', {
      'text': trimmed,
      'kind': 'text',
    });
    await refresh(sessionId: sessionId);
  }

  // ─────────────────────────── ending & deletion ───────────────────────────

  /// Ends the session and starts the two-hour clock.
  ///
  /// The deadline is stamped from the server's clock and enforced by a MongoDB
  /// TTL index. It used to be computed here from `DateTime.now()`, which put
  /// the retention promise at the mercy of a handset's clock.
  Future<void> endSession(String sessionId) => _setStatus(sessionId, 'ended');

  Future<void> _setStatus(String sessionId, String status) async {
    await _api.patch(
      '/api/counselling/sessions/$sessionId/status',
      {'status': status},
    );
    await refresh(sessionId: sessionId);
  }

  /// Removes one conversation entirely. The member may do this to their own; an
  /// operator to any.
  Future<void> deleteSession(String sessionId) async {
    await _api.delete('/api/counselling/sessions/$sessionId');
    await _transcripts.remove(sessionId)?.dispose();
    await refresh();
  }

  /// Retained so the screens that called it on open still compile.
  ///
  /// It does nothing, and that is the point: expiry is a TTL index in MongoDB
  /// now. Deleting expired sessions from the client was only ever necessary
  /// because Firestore had no way to do it, and it meant the two-hour promise
  /// depended on somebody opening the app.
  Future<int> purgeExpired({bool asAdmin = false}) async {
    debugPrint('▶ counselling: expiry is server-side; nothing to purge.');
    return 0;
  }

  Future<void> dispose() async {
    await _mine?.dispose();
    await _all?.dispose();
    for (final feed in _transcripts.values) {
      await feed.dispose();
    }
    _transcripts.clear();
    _mine = null;
    _all = null;
  }
}
