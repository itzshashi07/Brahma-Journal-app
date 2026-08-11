import 'package:cloud_firestore/cloud_firestore.dart';

class BlogComment {
  final String id;
  /// Author's Firebase uid — what firestore.rules checks for edit and delete.
  final String uid;
  final String authorName;
  final String authorEmail;
  final String content;
  final DateTime createdAt;

  BlogComment({
    required this.id,
    this.uid = '',
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory BlogComment.fromMap(String id, Map<String, dynamic> data) {
    return BlogComment(
      id: id,
      uid: data['uid'] ?? '',
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
      // Stamped so a comment is attributable to its author: firestore.rules
      // uses it to let someone edit or delete their own comment and nobody
      // else's. Without it every comment write was rejected.
      'uid': uid,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Where an article is in review.
///
/// A missing value reads as [published] on purpose: every article written
/// before approval existed carries no `status` field, and treating those as
/// pending would empty the Sanctuary overnight and bury the whole library
/// behind a moderation queue nobody asked for.
enum BlogStatus {
  /// Written by a member, waiting on the admin. Visible only to its author and
  /// to the admin reviewing it.
  pending,

  /// Approved — or written by the admin, who does not queue behind themselves.
  published,

  /// Turned down. Kept rather than deleted so the author can see what happened
  /// to their work instead of watching it vanish.
  rejected;

  static BlogStatus parse(String? raw) => switch (raw) {
        'pending' => BlogStatus.pending,
        'rejected' => BlogStatus.rejected,
        _ => BlogStatus.published,
      };

  String get wire => name;

  String get label => switch (this) {
        BlogStatus.pending => 'Awaiting approval',
        BlogStatus.published => 'Published',
        BlogStatus.rejected => 'Not approved',
      };
}

class BlogPost {
  final String id;

  /// Author's uid. firestore.rules checks it: an author may delete and edit
  /// their own article, an admin may delete anyone's. Articles written before
  /// members could post carry an empty uid and are admin-only.
  final String uid;

  final String title;
  final String content;

  /// Category id from [ArticleCategories]. Empty on posts written before
  /// categories existed — the UI falls back to a neutral "Wisdom" chip.
  final String category;

  /// The same article in Hinglish, for readers who take it in faster that way.
  /// Empty means the article is English-only and no language switch is shown.
  final String titleHinglish;
  final String contentHinglish;

  final String authorName;
  final String authorEmail;
  final DateTime createdAt;
  final List<String> likes;
  final int sharesCount;

  /// Review state. Only an admin can move it — see firestore.rules.
  final BlogStatus status;

  /// When the admin approved it. Null on anything not yet approved, and on
  /// articles that predate approval.
  final DateTime? publishedAt;

  /// Why it was turned down, in the admin's words. Shown to the author only.
  final String reviewNote;

  BlogPost({
    required this.id,
    this.uid = '',
    required this.title,
    required this.content,
    this.category = '',
    this.titleHinglish = '',
    this.contentHinglish = '',
    required this.authorName,
    required this.authorEmail,
    required this.createdAt,
    this.likes = const [],
    this.sharesCount = 0,
    this.status = BlogStatus.published,
    this.publishedAt,
    this.reviewNote = '',
  });

  bool get hasHinglish => contentHinglish.trim().isNotEmpty;

  bool get isPublished => status == BlogStatus.published;

  /// Whether [uid] may see this article at all. An article in review is the
  /// author's own words, so they keep reading it; nobody else does until it is
  /// approved.
  bool visibleTo({String? viewerUid, bool isAdmin = false}) =>
      isPublished || isAdmin || (viewerUid != null && viewerUid == this.uid);

  factory BlogPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlogPost(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? '',
      titleHinglish: data['titleHinglish'] ?? '',
      contentHinglish: data['contentHinglish'] ?? '',
      authorName: data['authorName'] ?? 'Admin',
      authorEmail: data['authorEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      sharesCount: data['sharesCount'] ?? 0,
      status: BlogStatus.parse(data['status']),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      reviewNote: data['reviewNote'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'titleHinglish': titleHinglish,
      'contentHinglish': contentHinglish,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': likes,
      'sharesCount': sharesCount,
      'status': status.wire,
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
    };
  }
}
