import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/anonymous_thought.dart';
import '../models/counselling_session.dart';
import 'community_service.dart';
import 'counselling_service.dart';
import 'notification_service.dart';

/// One place that knows whether there is anything the user has not seen.
///
/// Three feeds arrive on a device and none of them used to be counted:
///
///   • **/notifications** — the app-wide broadcast (a new article, a new book).
///     A system popup fired for these, but only while the app was open, and
///     nothing was left behind afterwards. Someone who missed the toast had no
///     way of knowing it had happened.
///   • **/admin_notifications** — counselling requests, payments to verify,
///     someone waiting in a chat. These had no listener at all: the operator
///     found out by opening the inbox and looking.
///   • **the member's own counselling sessions** — a counsellor's reply. There
///     is no per-user notification collection to watch, so this watches the
///     session documents the member already has permission to read, and fires
///     when `lastMessageBy` says somebody else spoke.
///
/// What it exposes is a single [unreadCount] and a red badge, so "I have not
/// looked at something" is answerable at a glance from the dashboard rather
/// than only in the second the toast is on screen.
///
/// Read state is local, in SharedPreferences, keyed by feed. That is on purpose:
/// writing a per-user read receipt to Firestore would mean a document write on
/// every glance at the bell, and the question "have *I* seen this on *this
/// phone*" is a local one.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter() {
    _bind();
  }

  final _db = FirebaseFirestore.instance;
  final _local = NotificationService();

  final _community = CommunityService();

  StreamSubscription? _authSub;
  StreamSubscription? _broadcastSub;
  StreamSubscription? _adminSub;
  StreamSubscription? _counsellingSub;
  StreamSubscription? _thoughtWatchSub;
  StreamSubscription? _thoughtFeedSub;

  /// When the app started. Anything older than this is history, not an event —
  /// without it, every listener fires for the whole backlog on launch and the
  /// user gets twelve system notifications for things from last week.
  final DateTime _startedAt = DateTime.now();

  bool _isAdmin = false;

  int _unreadBroadcast = 0;
  int _unreadAdmin = 0;
  int _unreadReplies = 0;
  int _unreadThoughtReplies = 0;

  /// Sessions whose last message was somebody else's and has not been opened.
  final _unreadSessionIds = <String>{};

  /// Reflections this member is part of, and how many replies they have seen.
  Map<String, int> _watchedThreads = const {};

  /// Live reply count per reflection, from the feed listener. Kept so the
  /// screen can mark everything caught up without re-reading the collection.
  Map<String, int> _threadReplyCounts = const {};

  /// Threads with replies the member has not seen yet.
  final _unreadThreadIds = <String>{};

  int get unreadCount =>
      _unreadBroadcast + _unreadAdmin + _unreadReplies + _unreadThoughtReplies;
  bool get hasUnread => unreadCount > 0;
  int get unreadReplies => _unreadReplies;
  Set<String> get unreadSessionIds => Set.unmodifiable(_unreadSessionIds);

  /// How many of the member's own reflections have unread replies.
  int get unreadThoughtReplies => _unreadThoughtReplies;
  Set<String> get unreadThreadIds => Set.unmodifiable(_unreadThreadIds);

  static const _kBroadcastSeen = 'notif_seen_broadcast';
  static const _kAdminSeen = 'notif_seen_admin';
  static const _kRepliesSeen = 'notif_seen_replies';

  void _bind() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _cancelFeeds();
      if (user == null) {
        _unreadBroadcast = _unreadAdmin = _unreadReplies = 0;
        _unreadThoughtReplies = 0;
        _unreadSessionIds.clear();
        _unreadThreadIds.clear();
        _watchedThreads = const {};
        _threadReplyCounts = const {};
        notifyListeners();
        return;
      }

      // The admin claim decides whether the operator feed is even readable —
      // subscribing without it produces a permission-denied stream error on
      // every member's device.
      try {
        final token = await user.getIdTokenResult(true);
        _isAdmin = token.claims?['admin'] == true ||
            user.email == 'officialshashi2023@gmail.com';
      } catch (_) {
        _isAdmin = false;
      }

      _listenBroadcast();
      _listenCounselling();
      _listenThoughtReplies(user.uid);
      if (_isAdmin) _listenAdmin();
    });
  }

  // ─────────────────────────── feeds ───────────────────────────

  void _listenBroadcast() {
    _broadcastSub = _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) async {
      final seen = await _seenAt(_kBroadcastSeen);
      var unread = 0;
      for (final doc in snap.docs) {
        final at = _stamp(doc.data()['createdAt']);
        if (at == null) continue;
        if (at.isAfter(seen)) unread++;
      }
      _unreadBroadcast = unread;
      notifyListeners();
    }, onError: (e) => debugPrint('⚠️ Broadcast feed: $e'));
  }

  void _listenAdmin() {
    _adminSub = _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) async {
      final seen = await _seenAt(_kAdminSeen);
      var unread = 0;

      for (final change in snap.docChanges) {
        final data = change.doc.data() ?? const {};
        final at = _stamp(data['createdAt']);
        if (at == null) continue;
        // Only genuinely new events raise a system notification; the initial
        // snapshot of the whole collection must stay silent.
        if (change.type == DocumentChangeType.added &&
            at.isAfter(_startedAt.subtract(const Duration(seconds: 2)))) {
          _local.showNow(
            id: change.doc.id.hashCode,
            title: data['title'] ?? 'InnenFlow',
            body: data['body'] ?? '',
            payload: '/counselling/inbox',
          );
        }
      }

      for (final doc in snap.docs) {
        final at = _stamp(doc.data()['createdAt']);
        if (at != null && at.isAfter(seen)) unread++;
      }
      _unreadAdmin = unread;
      notifyListeners();
    }, onError: (e) => debugPrint('⚠️ Admin alert feed: $e'));
  }

  /// A counsellor replying, seen from the member's own session documents.
  void _listenCounselling() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _counsellingSub = _db
        .collection('counselling_sessions')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      final seen = await _seenAt(_kRepliesSeen);
      _unreadSessionIds.clear();

      for (final doc in snap.docs) {
        final session = CounsellingSession.fromDoc(doc);

        // The two-hour promise is kept here as well as on the counselling
        // screens. This listener is bound for as long as the app is running, so
        // a transcript whose window closes while the member is anywhere in the
        // app is destroyed at that moment — rather than surviving until the
        // next time they happen to open the counselling room.
        if (session.isExpired) {
          unawaited(CounsellingService().deleteSession(session.id).catchError(
              (e) => debugPrint('⚠️ Expired session not removed: $e')));
          continue;
        }

        final at = session.lastMessageAt;
        if (at == null) continue;

        // Their own message coming back through the stream is not a reply.
        final fromSomeoneElse = session.lastMessageBy != null &&
            session.lastMessageBy != ChatSender.member;
        if (!fromSomeoneElse) continue;

        if (at.isAfter(seen)) _unreadSessionIds.add(session.id);

        if (at.isAfter(_startedAt)) {
          _local.showNow(
            // Keyed by session, so a rapid back-and-forth replaces the previous
            // line instead of stacking six identical trays.
            id: session.id.hashCode,
            title: session.lastMessageBy == ChatSender.system
                ? 'InnenFlow'
                : 'Your counsellor replied',
            body: session.lastMessagePreview.isEmpty
                ? 'Open the chat to read it.'
                : session.lastMessagePreview,
            payload: '/counselling',
          );
        }
      }

      _unreadReplies = _unreadSessionIds.length;
      notifyListeners();
    }, onError: (e) => debugPrint('⚠️ Counselling reply feed: $e'));
  }

  /// Somebody replying to a reflection this member is part of.
  ///
  /// Two streams, because participation is deliberately not discoverable from
  /// the public feed. A reflection carries no author uid and neither do its
  /// replies — that is what makes the board anonymous — so there is no query
  /// that returns "threads I am in". Instead each member keeps their own
  /// watchlist under /thought_watch/{uid}, and this cross-references it against
  /// the feed they are already allowed to read.
  ///
  /// The alternative would be a Cloud Function fanning replies out to each
  /// participant's inbox. That is the better design at scale and it is not
  /// available here: Functions do not deploy on the Spark plan, and there is no
  /// FCM in this project. The consequence is worth being honest about — these
  /// fire while the app is running, not when it has been killed.
  ///
  /// The feed listener is bounded to the newest 200 reflections. Posts are
  /// deleted after a month, so for this app that is the whole live board; if it
  /// ever is not, the cost of the miss is a missed notification on a very old
  /// thread rather than anything incorrect.
  void _listenThoughtReplies(String uid) {
    _thoughtWatchSub = _community.watchedThreads(uid).listen((watched) {
      _watchedThreads = watched;
      _recomputeThoughtReplies();
    }, onError: (e) => debugPrint('⚠️ Thought watchlist: $e'));

    _thoughtFeedSub = _db
        .collection(AppConstants.anonymousThoughtsCollection)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      _threadReplyCounts = {
        for (final doc in snap.docs)
          doc.id: AnonymousThought.fromFirestore(doc).replyCount,
      };
      _recomputeThoughtReplies();
    }, onError: (e) => debugPrint('⚠️ Thought reply feed: $e'));
  }

  /// Thread id → reply count at the moment we last raised a notification for
  /// it. Without this every unrelated snapshot — someone else posting anywhere
  /// on the board — re-fires the tray line for a reply the member already saw.
  final _notifiedAt = <String, int>{};

  /// True until the first feed snapshot has been reconciled with the watchlist.
  /// The opening snapshot is the backlog, not news, and must stay silent.
  bool _thoughtFeedPrimed = false;

  void _recomputeThoughtReplies() {
    // Both streams have to have arrived before any comparison means anything:
    // an empty watchlist against a full feed says "nothing is mine", and a full
    // watchlist against an empty feed says "everything is unread".
    if (_watchedThreads.isEmpty || _threadReplyCounts.isEmpty) {
      if (_unreadThoughtReplies != 0) {
        _unreadThoughtReplies = 0;
        _unreadThreadIds.clear();
        notifyListeners();
      }
      return;
    }

    _unreadThreadIds.clear();

    _watchedThreads.forEach((thoughtId, seen) {
      final now = _threadReplyCounts[thoughtId];
      // Not on the board any more — deleted, moderated, or aged out.
      if (now == null || now <= seen) return;

      _unreadThreadIds.add(thoughtId);

      // Raise a tray line once per genuinely new reply, and never for the
      // backlog waiting on the device at launch.
      final alreadyToldAbout = _notifiedAt[thoughtId] ?? seen;
      if (_thoughtFeedPrimed && now > alreadyToldAbout) {
        final fresh = now - seen;
        _local.showNow(
          // Keyed by thread, so a busy conversation replaces its own line
          // instead of stacking one per reply.
          id: thoughtId.hashCode,
          title: 'Someone replied to you',
          body: fresh == 1
              ? 'There is a new reply on a reflection you are part of.'
              : '$fresh new replies on a reflection you are part of.',
          payload: '/thoughts',
        );
      }
      _notifiedAt[thoughtId] = now;
    });

    _thoughtFeedPrimed = true;
    _unreadThoughtReplies = _unreadThreadIds.length;
    notifyListeners();
  }

  /// Called when the reflections feed is opened — everything on screen counts
  /// as seen from that moment.
  Future<void> markThoughtRepliesSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _watchedThreads.isEmpty) return;

    final caughtUp = <String, int>{
      for (final id in _watchedThreads.keys)
        if (_threadReplyCounts[id] != null) id: _threadReplyCounts[id]!,
    };
    if (caughtUp.isEmpty) return;

    _notifiedAt.addAll(caughtUp);
    _unreadThreadIds.clear();
    _unreadThoughtReplies = 0;
    notifyListeners();

    await _community.markThreadsSeen(uid, caughtUp);
  }

  // ─────────────────────────── read state ───────────────────────────

  /// Called when the notifications screen is opened.
  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_kBroadcastSeen, now);
    await prefs.setInt(_kAdminSeen, now);
    _unreadBroadcast = 0;
    _unreadAdmin = 0;
    notifyListeners();
  }

  /// Called when a counselling chat is opened, so the badge clears for it.
  Future<void> markRepliesRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRepliesSeen, DateTime.now().millisecondsSinceEpoch);
    _unreadSessionIds.clear();
    _unreadReplies = 0;
    notifyListeners();
  }

  Future<DateTime> _seenAt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(key);
    // A device that has never looked should not be told it has 30 unread
    // things from before it was installed.
    if (ms == null) {
      await prefs.setInt(key, _startedAt.millisecondsSinceEpoch);
      return _startedAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static DateTime? _stamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Future<void> _cancelFeeds() async {
    await _broadcastSub?.cancel();
    await _adminSub?.cancel();
    await _counsellingSub?.cancel();
    await _thoughtWatchSub?.cancel();
    await _thoughtFeedSub?.cancel();
    _broadcastSub = _adminSub = _counsellingSub = null;
    _thoughtWatchSub = _thoughtFeedSub = null;
    // A different account must not inherit the previous one's "already told
    // them about this" state.
    _notifiedAt.clear();
    _thoughtFeedPrimed = false;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelFeeds();
    super.dispose();
  }
}
