import 'package:cloud_firestore/cloud_firestore.dart';

class ThoughtReply {
  final String id;
  final String content;
  final String uid;
  final DateTime createdAt;
  final String anonymousName;
  final String anonymousColor;

  ThoughtReply({
    required this.id,
    required this.content,
    required this.uid,
    required this.createdAt,
    required this.anonymousName,
    required this.anonymousColor,
  });

  factory ThoughtReply.fromMap(Map<String, dynamic> data) {
    return ThoughtReply(
      id: data['id'] ?? '',
      content: data['content'] ?? '',
      uid: data['uid'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      anonymousName: data['anonymousName'] ?? 'Peaceful Soul',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'uid': uid,
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
      anonymousName: data['anonymousName'] ?? 'Peaceful Soul',
      anonymousColor: data['anonymousColor'] ?? '#8B5CF6',
    );
  }
}
