import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'firebase_messaging_service.dart';

/// One place that knows whether there is anything the user has not seen.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Four open listeners became one request
///
/// This class used to hold four Firestore `snapshots()` subscriptions open for
/// as long as the app was running — the broadcast feed, the operator alerts,
/// the member's own counselling sessions, and the whole reflections board
/// cross-referenced against their watchlist. Each device paid for a live
/// connection per feed, and the unread count was derived on the handset from
/// everything those streams carried.
///
/// That was the only way to get a badge out of Firestore. It is also why the
/// app could not be told anything while it was closed, and why the reply
/// fan-out on the anonymous board was impossible: matching a reply against
/// every member's private watchlist needs a server.
///
/// Now the server counts, and the answer arrives two ways:
///
///   • **On launch and on resume** — one call to `/api/notifications/unread`,
///     which returns every feed's count in a single reply.
///   • **When something happens** — an FCM push. The message itself is the
///     signal, so [refresh] runs on arrival rather than on a timer. Nothing
///     polls.
///
/// At a hundred thousand installs the difference is four hundred thousand held
/// connections against a few requests per member per session.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Read state moved with it
///
/// It used to live in SharedPreferences, with a comment arguing that "have *I*
/// seen this on *this phone*" is a local question. That held while the badge
/// was computed on the handset. It does not hold now: the server needs to know
/// what has been seen in order to count, and a member with a phone and a tablet
/// expects reading on one to quiet the other. The API owns it; the local keys
/// are gone.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter() {
    _bind();
  }

  final ApiService _api = ApiService();

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _pushSub;

  bool _isAdmin = false;

  int _unreadBroadcast = 0;
  int _unreadAdmin = 0;
  int _unreadReplies = 0;
  int _unreadThoughtReplies = 0;

  /// Reflections this member is part of, and how many replies they have seen.
  /// Kept so the reflections screen can mark everything caught up without
  /// re-reading the board.
  Map<String, int> _watchedThreads = const {};

  int get unreadCount =>
      _unreadBroadcast + _unreadAdmin + _unreadReplies + _unreadThoughtReplies;
  bool get hasUnread => unreadCount > 0;
  int get unreadReplies => _unreadReplies;

  /// How many of the member's own reflections have unread replies.
  int get unreadThoughtReplies => _unreadThoughtReplies;

  /// Retained for call-site compatibility. The server reports counts rather
  /// than which sessions or threads are unread, because the screens that used
  /// these already re-read the list they are about to render.
  Set<String> get unreadSessionIds => const {};
  Set<String> get unreadThreadIds => const {};

  void _bind() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        _unreadBroadcast = _unreadAdmin = _unreadReplies = 0;
        _unreadThoughtReplies = 0;
        _watchedThreads = const {};
        notifyListeners();
        return;
      }

      try {
        final token = await user.getIdTokenResult(true);
        _isAdmin = token.claims?['admin'] == true;
      } catch (_) {
        _isAdmin = false;
      }

      await refresh();
    });

    // A push is the event. Re-reading the counts when one lands is what
    // replaces the four listeners — the server has already decided something
    // happened, so there is nothing to poll for.
    _pushSub = FirebaseMessagingService().messages.listen((_) => refresh());
  }

  /// Re-reads every unread count. Safe to call on resume, after opening a feed,
  /// or when a push arrives.
  Future<void> refresh() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final body = await _api.get('/api/notifications/unread');
      _unreadBroadcast = (body?['broadcast'] as num?)?.toInt() ?? 0;
      _unreadAdmin = _isAdmin ? ((body?['admin'] as num?)?.toInt() ?? 0) : 0;
      _unreadReplies = (body?['replies'] as num?)?.toInt() ?? 0;
      _unreadThoughtReplies = (body?['thoughtReplies'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      // A failed count leaves the badge as it was. Zeroing it would tell the
      // member they have nothing waiting, which is a worse lie than a stale
      // number.
      debugPrint('⚠️ Unread counts unavailable: $e');
    }
  }

  // ─────────────────────────── read state ───────────────────────────

  /// Called when the notifications screen is opened.
  Future<void> markAllRead() async {
    _unreadBroadcast = 0;
    _unreadAdmin = 0;
    notifyListeners();

    try {
      await _api.post('/api/notifications/seen/broadcast');
      if (_isAdmin) await _api.post('/api/notifications/seen/admin');
    } catch (e) {
      debugPrint('⚠️ Could not mark notifications seen: $e');
    }
  }

  /// Called when a counselling chat is opened, so the badge clears for it.
  Future<void> markRepliesRead() async {
    _unreadReplies = 0;
    notifyListeners();

    try {
      await _api.post('/api/notifications/seen/replies');
    } catch (e) {
      debugPrint('⚠️ Could not mark replies seen: $e');
    }
  }

  /// Called when the reflections feed is opened — everything on screen counts
  /// as seen from that moment.
  Future<void> markThoughtRepliesSeen() async {
    _unreadThoughtReplies = 0;
    notifyListeners();

    try {
      // The server holds the watchlist and the board, so it can work out what
      // "caught up" means without the client sending a count per thread.
      await _api.post('/api/community/watchlist/seen-all');
      await _api.post('/api/notifications/seen/thought_replies');
    } catch (e) {
      debugPrint('⚠️ Could not mark reflections seen: $e');
    }
  }

  /// The member's watchlist, as thoughtId → replies already seen.
  Future<Map<String, int>> watchedThreads() async {
    try {
      final body = await _api.get('/api/community/watchlist');
      final map = (body?['watchlist'] as Map? ?? const {});
      _watchedThreads = {
        for (final e in map.entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      };
      return _watchedThreads;
    } catch (e) {
      debugPrint('⚠️ Watchlist unavailable: $e');
      return const {};
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }
}
