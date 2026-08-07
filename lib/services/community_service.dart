import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_thought.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';
import 'notification_service.dart';

class CommunityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reflections live for one week.
  ///
  /// Expiry is enforced in two places on purpose. Firestore's TTL policy on
  /// `expiresAt` does the actual deletion, but Google only guarantees removal
  /// *within 24 hours* of expiry — so a post can outlive its week by a day in
  /// the database. Filtering here means it disappears from the feed on the
  /// stroke of seven days regardless, and the TTL sweep reclaims the storage
  /// behind the scenes.
  static const Duration thoughtLifetime = Duration(days: 7);

  Future<List<AnonymousThought>> getAnonymousThoughts() async {
    try {
      final q = _db
          .collection(AppConstants.anonymousThoughtsCollection)
          .orderBy('createdAt', descending: true);
      final snapshot = await q.get();

      final cutoff = DateTime.now().subtract(thoughtLifetime);
      return snapshot.docs
          .map((doc) => AnonymousThought.fromFirestore(doc))
          .where((t) => t.createdAt.isAfter(cutoff))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Best-effort removal of the caller's own expired posts.
  ///
  /// Runs opportunistically when the feed loads. Rules only permit a member to
  /// delete their own reflections, so this cannot be used to clear anyone
  /// else's — it just means the collection does not sit full of dead documents
  /// while waiting on the TTL sweep, and it keeps working even if the TTL
  /// policy is never configured.
  Future<void> purgeMyExpiredThoughts(String uid) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(thoughtLifetime));
      final mine = await _db
          .collection('thought_authors')
          .where('uid', isEqualTo: uid)
          .get();

      for (final owner in mine.docs) {
        final thoughtRef = _db
            .collection(AppConstants.anonymousThoughtsCollection)
            .doc(owner.id);
        final thought = await thoughtRef.get();
        if (!thought.exists) continue;

        final createdAt = thought.data()?['createdAt'];
        if (createdAt is Timestamp && createdAt.compareTo(cutoff) < 0) {
          await thoughtRef.delete();
          await owner.reference.delete().catchError((_) {});
        }
      }
    } catch (e) {
      // Housekeeping only — never surface this to the user.
    }
  }

  /// Publishes an anonymous reflection.
  ///
  /// The author's `uid` used to be stored on the document itself, and every
  /// signed-in user could read the whole collection — so "anonymous" thoughts
  /// could be attributed to a named account simply by joining against the
  /// profiles collection. The feature's core promise was not actually kept.
  ///
  /// The public document now carries only the generated spiritual identity.
  /// Authorship goes to /thought_authors, which no client can read; Firestore
  /// rules consult it to authorise edits and deletes.
  Future<String> saveAnonymousThought(String content, String uid) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final identity = generateAnonymousIdentity(
        uid, timestamp, AppConstants.spiritualNames, AppConstants.spiritualColors,
      );
      final docRef = await _db.collection(AppConstants.anonymousThoughtsCollection).add({
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        // Read by the Firestore TTL policy configured on this collection, which
        // deletes the document once this moment passes. A concrete timestamp
        // rather than serverTimestamp(): TTL needs a real value it can index,
        // and a sentinel resolves too late to be useful here.
        'expiresAt': Timestamp.fromDate(DateTime.now().add(thoughtLifetime)),
        'replies': [],
        'anonymousName': identity['name'],
        'anonymousColor': identity['color'],
      });

      await _db.collection('thought_authors').doc(docRef.id).set({
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Trigger local push notification
      final bodyText = content.length > 60 ? '${content.substring(0, 57)}...' : content;
      await NotificationService().sendNotification(
        title: 'New Community Reflection ✨',
        body: '"$bodyText"',
        type: 'community',
        route: '/thoughts',
      );

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Removes a reflection and its authorship record.
  ///
  /// Rules permit this for an admin or the author. Moderation matters here in a
  /// way it does not elsewhere: the feed is anonymous, so there is no social
  /// cost to posting something harmful and nobody else can report it to a name.
  Future<void> deleteThought(String thoughtId) async {
    await _db
        .collection(AppConstants.anonymousThoughtsCollection)
        .doc(thoughtId)
        .delete();
    // Best effort — the public post is already gone, which is what matters.
    await _db.collection('thought_authors').doc(thoughtId).delete().catchError((_) {});
  }

  Future<void> addReplyToThought(String thoughtId, String reply, String uid) async {
    try {
      final thoughtRef = _db.collection(AppConstants.anonymousThoughtsCollection).doc(thoughtId);
      final thoughtDoc = await thoughtRef.get();

      if (thoughtDoc.exists) {
        final currentReplies = List<dynamic>.from(thoughtDoc.data()?['replies'] ?? []);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final identity = generateAnonymousIdentity(
          uid, timestamp, AppConstants.spiritualNames, AppConstants.spiritualColors,
        );

        final newReply = ThoughtReply(
          id: timestamp.toString(),
          content: reply,
          uid: uid,
          createdAt: DateTime.now(),
          anonymousName: identity['name']!,
          anonymousColor: identity['color']!,
        );

        await thoughtRef.update({
          'replies': [...currentReplies, newReply.toMap()],
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}
