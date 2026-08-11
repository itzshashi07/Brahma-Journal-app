import '../models/anonymous_thought.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';
import 'api_service.dart';

/// The anonymous reflections board.
///
/// ─────────────────────────────────────────────────────────────────────────
/// This used to be the last thing in the app still talking to Firestore
///
/// Everything else moved to the API; this one file kept reading and writing
/// `anonymous_thoughts` directly. The website, written after the move, posted
/// the same feature to `/api/community/thoughts`. So there were two boards:
/// somebody wrote a reflection on their phone, opened the laptop, and it was
/// not there — and answered a stranger on the web that nobody on Android could
/// see. For a feature whose entire value is that another person replies, that
/// is not a stale cache, it is two rooms with a wall between them.
///
/// Every method below is now the same request the website makes. What is left
/// here is the anonymous identity generation, because the *name* attached to a
/// post is a client concern: it is derived from the uid and the moment, so the
/// server never has to hold "this uid posts as Quiet River".
///
/// ─────────────────────────────────────────────────────────────────────────
/// What the server does now that this file used to
///
///   • **Expiry.** `purgeExpiredThoughts`, `purgeMyExpiredThoughts` and the
///     read-time cutoff are gone. A TTL index and a read filter enforce the
///     thirty days for both clients at once, which is the only way they can
///     agree about it.
///   • **Watching a thread.** Posting and replying enrol the caller
///     server-side, so there is no second write to forget.
///   • **Authorship.** `mine` arrives on each reflection, computed against the
///     caller's own uid. The app used to keep a private list for this, which a
///     reinstall or a second device silently lost — so a member could stop
///     being able to delete their own post by changing phones.
///   • **Scrubbing legacy reply uids.** The projection never returns a uid at
///     all, so there is nothing left to scrub.
class CommunityService {
  final ApiService _api = ApiService();

  /// Reflections live for one month.
  ///
  /// Kept here because the interface says so on the card — "fades in N days" —
  /// and that countdown is drawn on the device. The *enforcement* is the
  /// server's: see `THOUGHT_LIFETIME_DAYS` in the API. If one changes, both
  /// change.
  static const Duration thoughtLifetime = Duration(days: 30);

  /// The board, newest first, minus anyone this member has blocked.
  ///
  /// One page. It used to fetch the entire collection with every reply inline,
  /// which was the whole board and every conversation on it in one response;
  /// fifty is the API's ceiling and comfortably more than a screen.
  Future<List<AnonymousThought>> getAnonymousThoughts() async {
    try {
      final body = await _api.get(
        '/api/community/thoughts',
        query: {'limit': '50'},
      );
      final list = (body?['thoughts'] as List? ?? const []);
      return list
          .map((t) => AnonymousThought.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Publishes an anonymous reflection, returning its id.
  ///
  /// The identity is generated on the device from the uid and the current
  /// moment. The server accepts it rather than deriving it, so that no record
  /// anywhere maps a uid to the name it posts under.
  Future<String> saveAnonymousThought(String content, String uid) async {
    final identity = generateAnonymousIdentity(
      uid,
      DateTime.now().millisecondsSinceEpoch,
      AppConstants.anonymousNames,
      AppConstants.anonymousColors,
    );

    final body = await _api.post('/api/community/thoughts', {
      'content': content,
      'anonymousName': identity['name'],
      'anonymousColor': identity['color'],
    });

    return (body?['thought']?['_id'] ?? '').toString();
  }

  /// Removes a reflection. The author or an admin; the API decides which.
  ///
  /// Moderation matters here in a way it does not elsewhere: the board is
  /// anonymous, so there is no social cost to posting something harmful and
  /// nobody else can report it to a name.
  Future<void> deleteThought(String thoughtId) async {
    await _api.delete('/api/community/thoughts/$thoughtId');
  }

  /// Answers somebody.
  ///
  /// Replying enrols the caller in the thread server-side, so later replies
  /// reach them — and the fan-out to everyone else in it happens there too,
  /// which is what makes "somebody replied to you" possible on a board that
  /// deliberately cannot be queried for who is in a conversation.
  Future<void> addReplyToThought(
    String thoughtId,
    String reply,
    String uid,
  ) async {
    final identity = generateAnonymousIdentity(
      uid,
      DateTime.now().millisecondsSinceEpoch,
      AppConstants.anonymousNames,
      AppConstants.anonymousColors,
    );

    await _api.post('/api/community/thoughts/$thoughtId/replies', {
      'content': reply,
      'anonymousName': identity['name'],
      'anonymousColor': identity['color'],
    });
  }

  /// Removes one reply, leaving the reflection standing. Admin only.
  ///
  /// It exists because the alternative was a choice between leaving a harmful
  /// reply up and deleting the reflection it was answering — punishing the
  /// person who asked for help in order to remove the person who abused them
  /// for asking.
  Future<void> deleteReply(String thoughtId, String replyId) async {
    await _api.delete('/api/community/thoughts/$thoughtId/replies/$replyId');
  }

  /// Catches this member up on threads they have now looked at.
  ///
  /// Sent as one map when the screen settles rather than one request per card.
  Future<void> markThreadsSeen(String uid, Map<String, int> replyCounts) async {
    if (replyCounts.isEmpty) return;
    try {
      await _api.post('/api/community/watchlist/seen', {'seen': replyCounts});
    } catch (e) {
      // The badge stays up until the next attempt. Harmless.
    }
  }
}
