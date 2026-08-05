import 'package:cloud_firestore/cloud_firestore.dart';

class BlogComment {
  final String id;
  final String authorName;
  final String authorEmail;
  final String content;
  final DateTime createdAt;

  BlogComment({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory BlogComment.fromMap(String id, Map<String, dynamic> data) {
    return BlogComment(
      id: id,
      authorName: data['authorName'] ?? 'Anonymous',
      authorEmail: data['authorEmail'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorName': authorName,
      'authorEmail': authorEmail,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class BlogPost {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String authorEmail;
  final DateTime createdAt;
  final List<String> likes;
  final int sharesCount;

  BlogPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorEmail,
    required this.createdAt,
    this.likes = const [],
    this.sharesCount = 0,
  });

  factory BlogPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlogPost(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorName: data['authorName'] ?? 'Admin',
      authorEmail: data['authorEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      sharesCount: data['sharesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': likes,
      'sharesCount': sharesCount,
    };
  }
}
