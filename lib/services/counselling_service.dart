import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/counselling.dart';
import '../models/counselling_session.dart';

/// Firestore and Storage for the counselling room.
///
/// Two rules shape everything here:
///
///   1. **Nothing outlives the session by more than two hours.** That was
///      promised to the member in writing, so it cannot depend on a Cloud
///      Function that may not be deployed on a free plan. [purgeExpired] runs
///      on the client, from both sides of the conversation, whenever anyone
///      opens the feature — and the `purgeAfter` field is left on the document
///      so a scheduled function can do the same job later without a migration.
///
///   2. **The client never asserts privilege.** Approving a payment, rejecting
///      one and ending a session are admin actions; the app hides those buttons
///      from members, and firestore.rules rejects the writes regardless of what
///      the app decides to show.
class CounsellingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  static const _collection = 'counselling_sessions';

  /// How long a finished conversation is kept before it is destroyed.
  static const retention = Duration(hours: 2);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection(_collection);

  CollectionReference<Map<String, dynamic>> _messages(String sessionId) =>
      _sessions.doc(sessionId).collection('messages');

  // ─────────────────────────── reading ───────────────────────────

  /// The member's own sessions, newest first.
  Stream<List<CounsellingSession>> streamMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _sessions
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(_sortedSessions);
  }

  /// Every session, for the admin inbox.
  Stream<List<CounsellingSession>> streamAll() =>
      _sessions.snapshots().map(_sortedSessions);

  /// Sorted in Dart rather than by Firestore. `orderBy('createdAt')` combined
  /// with the `where('uid')` filter needs a composite index, and a missing
  /// index fails the query outright — which would show the member an empty
  /// screen at the exact moment they are asking for help.
  List<CounsellingSession> _sortedSessions(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(CounsellingSession.fromDoc).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<CounsellingSession?> streamSession(String id) =>
      _sessions.doc(id).snapshots().map(
          (d) => d.exists ? CounsellingSession.fromDoc(d) : null);

  Stream<List<ChatMessage>> streamMessages(String sessionId) => _messages(
        sessionId,
      ).orderBy('createdAt').snapshots().map(
            (s) => s.docs.map(ChatMessage.fromDoc).toList(),
          );

  // ─────────────────────────── intake ───────────────────────────

  /// Opens a session and seeds the conversation.
  ///
  /// The three opening messages are written here rather than rendered by the
  /// chat screen so that they are real messages: the admin sees exactly what
  /// the member was told, in order, and the member sees the same thing after
  /// closing and reopening the app.
  Future<String> createSession({
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String concern,
    required String language,
    required String details,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    final doc = _sessions.doc();
    final session = CounsellingSession(
      id: doc.id,
      uid: uid,
      name: name,
      age: age,
      gender: gender,
      phone: phone,
      concern: concern,
      language: language,
      details: details,
      amount: Counselling.fee,
      createdAt: DateTime.now(),
    );
    await doc.set(session.toMap());

    await _system(doc.id, Counselling.welcome(name));
    await _system(doc.id, Counselling.paymentAsk);

    await _alertAdmin(
      type: 'counselling_request',
      title: '🧘 New counselling request',
      body: '$name · $concern · awaiting ₹${Counselling.fee} payment',
    );

    return doc.id;
  }

  // ─────────────────────────── payment ───────────────────────────

  /// The member reports what they paid and how. Verification is a human
  /// reading a bank statement — this only records the claim.
  Future<void> submitPayment({
    required String sessionId,
    required String paymentMode,
    required String transactionId,
    required String memberName,
  }) async {
    await _sessions.doc(sessionId).update({
      'paymentMode': paymentMode,
      'transactionId': transactionId,
      'status': CounsellingStatus.paymentSubmitted.wire,
    });

    await _messages(sessionId).add({
      'sender': ChatSender.member.wire,
      'kind': ChatKind.payment.wire,
      'text': 'Paid ₹${Counselling.fee} · $paymentMode\nTransaction ID: $transactionId',
      'paymentMode': paymentMode,
      'transactionId': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _system(sessionId, Counselling.paymentReceived);

    await _alertAdmin(
      type: 'counselling_payment',
      title: '💳 Counselling payment to verify',
      body: '$memberName paid via $paymentMode · ref $transactionId',
    );
  }

  /// Admin: payment checked and confirmed.
  Future<void> approve(String sessionId) async {
    await _sessions.doc(sessionId).update({
      'status': CounsellingStatus.approved.wire,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await _system(sessionId, Counselling.approved);
  }

  /// Admin: payment could not be found. Deliberately reversible — the member
  /// is put back in front of the payment form rather than shown a dead end.
  Future<void> reject(String sessionId) async {
    await _sessions.doc(sessionId).update({
      'status': CounsellingStatus.rejected.wire,
    });
    await _system(sessionId, Counselling.rejected);
  }

  // ─────────────────────────── format ───────────────────────────

  /// The member picks a video call or chat. Either way the session goes live
  /// and the admin is told, because both formats need a human to show up.
  Future<void> chooseMode({
    required String sessionId,
    required CounsellingMode mode,
    required String memberName,
  }) async {
    await _sessions.doc(sessionId).update({
      'mode': mode.wire,
      'status': CounsellingStatus.active.wire,
    });

    if (mode == CounsellingMode.meet) {
      await _system(sessionId, Counselling.meetChosen(Counselling.meetLink));
      await _alertAdmin(
        type: 'counselling_meet',
        title: '📹 Join the counselling call',
        body: '$memberName chose a ${Counselling.sessionMinutes}-minute video call. '
            'Room: ${Counselling.meetLink}',
      );
    } else {
      await _system(sessionId, Counselling.chatChosen);
      await _alertAdmin(
        type: 'counselling_chat',
        title: '💬 Counselling chat started',
        body: '$memberName is waiting in the chat.',
      );
    }
  }

  // ─────────────────────────── messages ───────────────────────────

  Future<void> sendText({
    required String sessionId,
    required ChatSender sender,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _messages(sessionId).add({
      'sender': sender.wire,
      'kind': ChatKind.text.wire,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _touch(sessionId, trimmed, sender);

    if (sender == ChatSender.member) {
      await _alertAdmin(
        type: 'counselling_message',
        title: '💬 New counselling message',
        body: trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed,
      );
    }
  }

  /// Uploads a voice note and posts it.
  ///
  /// The object lives under `counselling/<sessionId>/` so [purgeExpired] can
  /// delete the audio along with the transcript — a voice note left behind in
  /// Storage after the messages are gone would break the same promise more
  /// badly, since it is the member's actual voice.
  Future<void> sendVoiceNote({
    required String sessionId,
    required ChatSender sender,
    required File file,
    required int seconds,
  }) async {
    final ref = _storage
        .ref()
        .child('counselling/$sessionId/${DateTime.now().millisecondsSinceEpoch}.m4a');

    await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
    final url = await ref.getDownloadURL();

    await _messages(sessionId).add({
      'sender': sender.wire,
      'kind': ChatKind.audio.wire,
      'text': '',
      'audioUrl': url,
      'audioPath': ref.fullPath,
      'audioSeconds': seconds,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // The local copy is deleted the moment it is safely uploaded. Leaving
    // recordings of a counselling session lying in the cache directory would
    // outlive the two-hour promise by however long the OS takes to clear it.
    try {
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ Could not remove the local voice note: $e');
    }

    await _touch(sessionId, '🎤 Voice note', sender);

    if (sender == ChatSender.member) {
      await _alertAdmin(
        type: 'counselling_message',
        title: '🎤 New counselling voice note',
        body: 'A member sent a ${seconds}s voice note.',
      );
    }
  }

  Future<void> _system(String sessionId, String text) async {
    await _messages(sessionId).add({
      'sender': ChatSender.system.wire,
      'kind': ChatKind.text.wire,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stamps the parent session so the inbox can sort and badge without reading
  /// every thread's subcollection.
  ///
  /// `lastMessageBy` is what lets the member's device tell "my counsellor
  /// replied" from "I sent that" — without it, sending a message would notify
  /// the sender about their own message.
  Future<void> _touch(String sessionId, String preview, ChatSender by) async {
    await _sessions.doc(sessionId).update({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': by.wire,
      'lastMessagePreview':
          preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
    });
  }

  // ─────────────────────────── ending & deletion ───────────────────────────

  /// Ends the session and starts the two-hour clock.
  ///
  /// `purgeAfter` is computed on the client, which means a device with a wrong
  /// clock could shorten or lengthen the window. That is acceptable here: the
  /// failure mode is a transcript deleted early, or late by the size of the
  /// clock skew, and both sides plus a future scheduled function all read the
  /// same field.
  Future<void> endSession(String sessionId) async {
    final now = DateTime.now();
    await _sessions.doc(sessionId).update({
      'status': CounsellingStatus.ended.wire,
      'endedAt': Timestamp.fromDate(now),
      'purgeAfter': Timestamp.fromDate(now.add(retention)),
    });
    await _system(sessionId, Counselling.ended);
  }

  /// Deletes every session whose two hours are up, including its messages and
  /// any voice notes.
  ///
  /// Called whenever either party opens the counselling screens. Firestore has
  /// no cascading delete, so the subcollection has to go first — dropping the
  /// parent alone would leave orphaned messages that no rule path can reach and
  /// no screen can show, which is the worst of both worlds.
  Future<int> purgeExpired({bool asAdmin = false}) async {
    try {
      final query = asAdmin
          ? _sessions.where('purgeAfter', isLessThan: Timestamp.now())
          : _sessions
              .where('uid', isEqualTo: _uid)
              .where('purgeAfter', isLessThan: Timestamp.now());

      final expired = await query.get();
      for (final doc in expired.docs) {
        await deleteSession(doc.id);
      }
      return expired.docs.length;
    } catch (e) {
      // A member without permission to run the admin query, an offline device,
      // a missing index: none of these should stop the screen from opening.
      debugPrint('⚠️ Counselling purge skipped: $e');
      return 0;
    }
  }

  /// Removes one conversation entirely — messages, audio, then the session.
  Future<void> deleteSession(String sessionId) async {
    final messages = await _messages(sessionId).get();

    for (final m in messages.docs) {
      final path = m.data()['audioPath'];
      if (path is String && path.isNotEmpty) {
        try {
          await _storage.ref(path).delete();
        } catch (e) {
          // An already-deleted object must not block the transcript's deletion.
          debugPrint('⚠️ Voice note already gone: $e');
        }
      }
    }

    // Batched: 500 is Firestore's limit, and a counselling session that ran
    // long can pass it.
    for (var i = 0; i < messages.docs.length; i += 400) {
      final batch = _db.batch();
      for (final m in messages.docs.skip(i).take(400)) {
        batch.delete(m.reference);
      }
      await batch.commit();
    }

    await _sessions.doc(sessionId).delete();
  }

  // ─────────────────────────── admin alerts ───────────────────────────

  /// Raises an alert in `admin_notifications`, which only an admin can read.
  ///
  /// Never allowed to throw into the caller: failing to notify the operator is
  /// bad, but failing the member's payment submission because the alert write
  /// was rejected would be worse.
  Future<void> _alertAdmin({
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      await _db.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'body': body,
        'uid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('⚠️ Could not raise admin alert: $e');
    }
  }
}
