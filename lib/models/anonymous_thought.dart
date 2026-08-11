import 'package:cloud_firestore/cloud_firestore.dart';

/// One reply on a reflection.
///
/// **Carries no `uid`, and that is the entire point.** Every reply used to
/// store its author's uid inside the parent thought document — the same
/// document every signed-in member is allowed to read. So while the reflection
/// itself was carefully anonymised (authorship was moved out to
/// /thought_authors, which no client can read), anyone could dump the feed,
/// read `replies[].uid`, and join it against /profiles to put a real name and
/// email against every reply on the board. The feature's promise held for the
/// posts and quietly failed for the conversation underneath them, which is
/// where people say the more revealing things.
///
/// Authorship now goes to /thought_reply_authors, readable only by an admin, so
/// moderation can still act on a person without the board exposing them.
class ThoughtReply {
  final String id;
  final String content;
  final DateTime createdAt;
  final String anonymousName;
  final String anonymousColor;

  ThoughtReply({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.anonymousName,
    required this.anonymousColor,
  });

  factory ThoughtReply.fromMap(Map<String, dynamic> data) {
    return ThoughtReply(
      id: data['id'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      anonymousName: data['anonymousName'] ?? 'Quiet Voice',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
    );
  }

  /// Deliberately omits `uid`. Replies written before this change still have
  /// one stored in Firestore; see [CommunityService.scrubLegacyReplyIds].
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'anonymousName': anonymousName,
      'anonymousColor': anonymousColor,
    };
  }
}

class AnonymousThought {
  final String id;
  final String content;
  final String uid;
  final DateTime createdAt;
  final List<ThoughtReply> replies;
  final String anonymousName;
  final String anonymousColor;

  AnonymousThought({
    required this.id,
    required this.content,
    required this.uid,
    required this.createdAt,
    this.replies = const [],
    required this.anonymousName,
    required this.anonymousColor,
  });

  factory AnonymousThought.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnonymousThought(
      id: doc.id,
      content: data['content'] ?? '',
      uid: data['uid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replies: (data['replies'] as List<dynamic>?)
              ?.map((r) => ThoughtReply.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      anonymousName: data['anonymousName'] ?? 'Quiet Voice',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
    );
  }

  /// How many replies this reflection has. The notification feed compares this
  /// against what the reader has already seen, so it is worth naming rather
  /// than writing `.replies.length` at four call sites.
  int get replyCount => replies.length;
}
