import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_thought.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';

class CommunityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<AnonymousThought>> getAnonymousThoughts() async {
    try {
      final q = _db
          .collection(AppConstants.anonymousThoughtsCollection)
          .orderBy('createdAt', descending: true);
      final snapshot = await q.get();
      return snapshot.docs.map((doc) => AnonymousThought.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> saveAnonymousThought(String content, String uid) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final identity = generateAnonymousIdentity(
        uid, timestamp, AppConstants.spiritualNames, AppConstants.spiritualColors,
      );
      final docRef = await _db.collection(AppConstants.anonymousThoughtsCollection).add({
        'content': content,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'replies': [],
        'anonymousName': identity['name'],
        'anonymousColor': identity['color'],
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
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
