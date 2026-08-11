import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Following, on the Community screen and nowhere else.
///
/// The shape of this is driven entirely by one requirement: **how many
/// followers somebody has is public, and who follows whom is nobody's
/// business.** A follower list is a social graph, and a social graph on a
/// mental-health app tells you who someone is drawn to at the moment they are
/// struggling — which is not a thing to publish next to a leaderboard.
///
/// So there are two collections and they hold deliberately different things:
///
///   • **/following/{me}/targets/{them}** — the relationship itself. Readable
///     and writable only by *me*. Nobody, including the person being followed,
///     can read this: firestore.rules keys the whole document path off the
///     follower's uid, so there is no query any other client can run that
///     returns it. It doubles as the answer to "who am I following", which is
///     one cheap collection read rather than a lookup per member.
///
///   • **/follower_counts/{them}** — a single integer, readable by every
///     signed-in member. It is written by the *follower*, which would normally
///     mean anyone could inflate anyone's number; the rule closes that by
///     tying the write to the relationship document with `existsAfter()`, so a
///     +1 is only accepted in the same commit that creates a follow that did
///     not exist, and a −1 only in the commit that removes one that did.
///
/// Everything therefore happens in a [WriteBatch]: the two writes are one
/// commit, and the rule can see both halves. `FieldValue.increment` rather than
/// a read-then-write keeps two people following the same member at the same
/// moment from losing one of the two counts.
class FollowService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _target(String me, String them) =>
      _db.collection('following').doc(me).collection('targets').doc(them);

  DocumentReference<Map<String, dynamic>> _count(String them) =>
      _db.collection('follower_counts').doc(them);

  // ─────────────────────────── reading ───────────────────────────

  /// Everyone the signed-in member follows.
  ///
  /// One read for the whole set, so the Community screen can render every
  /// row's button state without a lookup per member.
  Future<Set<String>> myFollowing() async {
    final me = _uid;
    if (me == null) return {};
    try {
      final snap =
          await _db.collection('following').doc(me).collection('targets').get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('⚠️ Could not read who you follow: $e');
      return {};
    }
  }

  /// Follower counts for the whole community, keyed by uid.
  ///
  /// A list of a public collection rather than a get per member: the Community
  /// screen needs all of them at once, and thirty document reads to render one
  /// screen is thirty round trips.
  Future<Map<String, int>> followerCounts() async {
    try {
      final snap = await _db.collection('follower_counts').get();
      return {
        for (final doc in snap.docs)
          doc.id: (doc.data()['count'] is num)
              ? (doc.data()['count'] as num).toInt()
              : 0,
      };
    } catch (e) {
      debugPrint('⚠️ Could not read follower counts: $e');
      return {};
    }
  }

  /// Live count for one member — used on their own profile.
  Stream<int> streamFollowerCount(String uid) => _count(uid).snapshots().map(
        (d) => (d.data()?['count'] is num)
            ? (d.data()!['count'] as num).toInt()
            : 0,
      );

  // ─────────────────────────── writing ───────────────────────────

  /// Follows [targetUid]. Idempotent — following twice is one follower.
  ///
  /// The idempotency is enforced by the rule, not by this method: the +1 is
  /// only accepted when the relationship document did *not* exist before the
  /// commit, so a client that re-sends the batch has the whole thing rejected
  /// rather than double-counting.
  Future<void> follow(String targetUid) async {
    final me = _uid;
    // Following yourself would be a free +1 on your own public number, so it is
    // refused here and in firestore.rules.
    if (me == null || me == targetUid) return;

    final batch = _db.batch();
    batch.set(_target(me, targetUid), {
      'follower': me,
      'following': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _count(targetUid),
      {
        'uid': targetUid,
        'count': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Unfollows [targetUid].
  Future<void> unfollow(String targetUid) async {
    final me = _uid;
    if (me == null || me == targetUid) return;

    // A count that is somehow already zero must not block the unfollow: the
    // rule refuses a negative count, which would fail the batch and leave the
    // member permanently following someone they asked to stop following. The
    // relationship is what matters, so in that case it goes on its own.
    final current = await _count(targetUid).get();
    final count = (current.data()?['count'] is num)
        ? (current.data()!['count'] as num).toInt()
        : 0;
    if (count <= 0) {
      await _target(me, targetUid).delete();
      return;
    }

    final batch = _db.batch();
    batch.delete(_target(me, targetUid));
    batch.set(
      _count(targetUid),
      {
        'uid': targetUid,
        'count': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Follows or unfollows, and reports the state it ended in.
  Future<bool> toggle(String targetUid, {required bool currentlyFollowing}) async {
    if (currentlyFollowing) {
      await unfollow(targetUid);
      return false;
    }
    await follow(targetUid);
    return true;
  }
}
