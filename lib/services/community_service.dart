import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_thought.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';

class CommunityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reflections live for one month.
  ///
  /// An admin can remove any reflection at any time (see [deleteThought]); this
  /// is what happens when nobody does. A month is long enough that a thread of
  /// replies is still worth having and short enough that the feed does not
  /// become a permanent record of what people were struggling with a year ago —
  /// which is the opposite of what an anonymous feed is for.
  ///
  /// Expiry is enforced in three places on purpose:
  ///
  ///   • Firestore's TTL policy on `expiresAt` does the actual deletion, but
  ///     Google only guarantees removal *within 24 hours* of expiry — so a post
  ///     can outlive its month by a day in the database.
  ///   • [getAnonymousThoughts] filters on read, so it disappears from the feed
  ///     on the stroke of thirty days regardless.
  ///   • [purgeMyExpiredThoughts] deletes the caller's own expired posts as
  ///     they browse, so the collection still drains even if the TTL policy is
  ///     never configured on the project.
  static const Duration thoughtLifetime = Duration(days: 30);

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

  /// Deletes every reflection older than [thoughtLifetime], from any author.
  ///
  /// Admin only — firestore.rules rejects the delete for anyone else, which is
  /// why this is separate from [purgeMyExpiredThoughts] rather than a flag on
  /// it. Runs when an admin opens the feed, so the one-month promise is kept by
  /// the app itself and does not depend on a TTL policy being configured or a
  /// Cloud Function being deployed on a plan that allows them.
  ///
  /// Returns how many were removed. Never throws: a failed sweep must not stop
  /// the feed from rendering.
  Future<int> purgeExpiredThoughts() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(thoughtLifetime));
      final expired = await _db
          .collection(AppConstants.anonymousThoughtsCollection)
          .where('createdAt', isLessThan: cutoff)
          .get();

      for (final doc in expired.docs) {
        await deleteThought(doc.id);
      }
      return expired.docs.length;
    } catch (e) {
      return 0;
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
        uid, timestamp, AppConstants.anonymousNames, AppConstants.anonymousColors,
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

      // Posting puts you in your own thread, which is what makes "somebody
      // replied to you" possible at all — /thought_authors is unreadable by
      // every client including its own author, by design, so the device cannot
      // discover its own posts by querying for them.
      //
      // This replaces a local notification that fired here announcing the new
      // reflection to the only person who could not possibly need telling: the
      // one who had just written it.
      await watchThread(
        uid: uid,
        thoughtId: docRef.id,
        seenReplies: 0,
        role: 'author',
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
      if (!thoughtDoc.exists) return;

      final currentReplies = List<dynamic>.from(thoughtDoc.data()?['replies'] ?? []);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final identity = generateAnonymousIdentity(
        uid, timestamp, AppConstants.anonymousNames, AppConstants.anonymousColors,
      );

      final newReply = ThoughtReply(
        id: timestamp.toString(),
        content: reply,
        createdAt: DateTime.now(),
        anonymousName: identity['name']!,
        anonymousColor: identity['color']!,
      );

      await thoughtRef.update({
        'replies': [...currentReplies, newReply.toMap()],
      });

      // Authorship, out of public view. See [ThoughtReply] for why the uid is
      // no longer written onto the reply itself.
      await _db
          .collection('thought_reply_authors')
          .doc('${thoughtId}_${newReply.id}')
          .set({
        'uid': uid,
        'thoughtId': thoughtId,
        'replyId': newReply.id,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Replying puts you in the thread, so later replies reach you too. Seeded
      // at the count *including* your own reply, or you would notify yourself
      // about the thing you just wrote.
      await watchThread(
        uid: uid,
        thoughtId: thoughtId,
        seenReplies: currentReplies.length + 1,
        role: 'replier',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Removes one reply from a reflection, leaving the reflection itself intact.
  ///
  /// Admin only — this is moderation, and the whole reason it exists is that a
  /// harmful reply used to force a choice between leaving it up and deleting
  /// somebody else's reflection along with it. Firestore rules enforce the
  /// privilege; hiding the button is only the first of the two checks.
  ///
  /// Matched by reply id rather than by index: the list is read, filtered and
  /// written back, and between those two moments somebody else may have
  /// appended a reply. An index would then delete the wrong one.
  Future<void> deleteReply(String thoughtId, String replyId) async {
    final thoughtRef =
        _db.collection(AppConstants.anonymousThoughtsCollection).doc(thoughtId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(thoughtRef);
      if (!snap.exists) return;

      final replies = List<dynamic>.from(snap.data()?['replies'] ?? []);
      final remaining = replies
          .where((r) => r is Map && r['id']?.toString() != replyId)
          .toList();

      // Nothing matched — already gone. Writing the identical array back would
      // be a pointless update that still counts against the quota.
      if (remaining.length == replies.length) return;

      tx.update(thoughtRef, {'replies': remaining});
    });

    await _db
        .collection('thought_reply_authors')
        .doc('${thoughtId}_$replyId')
        .delete()
        .catchError((_) {});
  }

  // ─────────────────────── thread watching ───────────────────────
  //
  // There is no per-user notification collection and no Cloud Function to fan
  // one out, so "tell me when somebody replies to my thread" is answered the
  // other way round: each member records which threads they are part of, and
  // their own device watches those for new replies. Same shape as the
  // counselling reply feed, and it needs no privilege the member does not
  // already have.
  //
  // It lives in Firestore rather than SharedPreferences because a reinstall or
  // a second device would otherwise silently drop somebody out of their own
  // conversations — and unlike a read receipt on a broadcast, that is not a
  // per-device question.

  CollectionReference<Map<String, dynamic>> _watchlist(String uid) =>
      _db.collection('thought_watch').doc(uid).collection('threads');

  /// Records that [uid] is part of [thoughtId] and has seen [seenReplies].
  Future<void> watchThread({
    required String uid,
    required String thoughtId,
    required int seenReplies,
    required String role,
  }) async {
    try {
      await _watchlist(uid).doc(thoughtId).set({
        'role': role,
        'seenReplies': seenReplies,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Losing a watch entry costs a notification, not data. Never worth
      // failing the reply that triggered it.
    }
  }

  /// Which reflections on the board are this member's own.
  ///
  /// The board carries no author, and /thought_authors is unreadable by every
  /// client including the author — so a device genuinely cannot recognise its
  /// own posts by looking at them. The watchlist is the only record it has, and
  /// it is what makes "delete my own reflection" possible at all.
  ///
  /// Firestore rules do not trust this: deletion is authorised server-side
  /// against /thought_authors. This decides which button to draw, nothing more.
  Future<Set<String>> myAuthoredThoughtIds(String uid) async {
    try {
      final snap = await _watchlist(uid).where('role', isEqualTo: 'author').get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      return const {};
    }
  }

  // The live `watchedThreads` stream that used to be here is gone.
  //
  // It was a Firestore `snapshots()` subscription on the caller's watchlist,
  // held open for the lifetime of the reflections screen. Nothing called it any
  // more: NotificationCenter.watchedThreads() reads the same map from
  // `GET /api/community/watchlist` in one request, because the unread count
  // that map feeds is computed on the server now rather than derived on the
  // handset from everything the listener carried.

  /// Catches the caller up on threads they have now looked at.
  ///
  /// Takes the counts as a map so the whole feed is settled in one batch when
  /// the screen opens, rather than one write per card.
  Future<void> markThreadsSeen(String uid, Map<String, int> replyCounts) async {
    if (replyCounts.isEmpty) return;
    try {
      final batch = _db.batch();
      replyCounts.forEach((thoughtId, seen) {
        batch.set(
          _watchlist(uid).doc(thoughtId),
          {'seenReplies': seen, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      });
      await batch.commit();
    } catch (e) {
      // Badge stays up until the next attempt. Harmless.
    }
  }

  /// Removes the author uid that older replies still carry inside the public
  /// document.
  ///
  /// New replies stopped writing it, but every reply written before that change
  /// is still sitting in Firestore with its author attached, readable by every
  /// signed-in member — so stopping the leak going forward does not close the
  /// one already there. Admin only, and safe to run repeatedly: replies with no
  /// `uid` are left exactly as they are.
  ///
  /// Returns the number of reflections it rewrote.
  Future<int> scrubLegacyReplyIds() async {
    try {
      final snap =
          await _db.collection(AppConstants.anonymousThoughtsCollection).get();
      var rewritten = 0;

      for (final doc in snap.docs) {
        final replies = List<dynamic>.from(doc.data()['replies'] ?? []);
        if (replies.isEmpty) continue;
        if (!replies.any((r) => r is Map && r.containsKey('uid'))) continue;

        final cleaned = replies.map((r) {
          if (r is! Map) return r;
          final copy = Map<String, dynamic>.from(r)..remove('uid');
          return copy;
        }).toList();

        await doc.reference.update({'replies': cleaned});
        rewritten++;
      }
      return rewritten;
    } catch (e) {
      return 0;
    }
  }
}
