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

  factory BlogComment.fromJson(Map<String, dynamic> data) {
    return BlogComment(
      id: '${data['_id'] ?? data['id'] ?? ''}',
      uid: data['uid'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorEmail: data['authorEmail'] ?? '',
      content: data['content'] ?? '',
      createdAt:
          DateTime.tryParse('${data['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  /// What `POST /api/blogs/:id/comments` accepts.
  ///
  /// `uid`, `authorName` and `authorEmail` are gone from the payload. They used
  /// to be sent and checked against `request.auth.uid` by a rule; the server now
  /// takes all three off the verified token, so there is nothing here for a
  /// client to get wrong or to lie about.
  Map<String, dynamic> toJson() => {'content': content};
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

  /// The article. **Empty on anything that came from a listing** — see
  /// [excerpt] and [isSummary].
  final String content;

  /// The opening of the article, cut by the server.
  ///
  /// `GET /api/blogs` leaves `content` out entirely: it is capped at 100,000
  /// characters and a listing of a hundred cards was shipping megabytes of
  /// prose to draw a hundred 120-character previews. The card renders this; the
  /// reader fetches the article by id when somebody actually opens it.
  final String excerpt;

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
    this.excerpt = '',
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

  /// True for a post that came from a listing and carries no article body.
  /// The reader screen refetches by id when it sees one.
  bool get isSummary => content.isEmpty && excerpt.isNotEmpty;

  /// The preview line on a card. Prefers whichever of the two is actually
  /// present, so the same widget works for a listing and for a loaded article.
  String get snippet {
    final source = content.isNotEmpty ? content : excerpt;
    return source.length > 120 ? '${source.substring(0, 120)}...' : source;
  }

  bool get isPublished => status == BlogStatus.published;

  /// Whether [uid] may see this article at all. An article in review is the
  /// author's own words, so they keep reading it; nobody else does until it is
  /// approved.
  bool visibleTo({String? viewerUid, bool isAdmin = false}) =>
      isPublished || isAdmin || (viewerUid != null && viewerUid == this.uid);

  factory BlogPost.fromJson(Map<String, dynamic> data) {
    return BlogPost(
      id: '${data['_id'] ?? data['id'] ?? ''}',
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      excerpt: data['excerpt'] ?? '',
      category: data['category'] ?? '',
      titleHinglish: data['titleHinglish'] ?? '',
      contentHinglish: data['contentHinglish'] ?? '',
      authorName: data['authorName'] ?? 'Admin',
      authorEmail: data['authorEmail'] ?? '',
      createdAt:
          DateTime.tryParse('${data['createdAt'] ?? ''}') ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? const []),
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      status: BlogStatus.parse(data['status']),
      publishedAt: DateTime.tryParse('${data['publishedAt'] ?? ''}'),
      reviewNote: data['reviewNote'] ?? '',
    );
  }

  /// What `POST`/`PATCH /api/blogs` accepts.
  ///
  /// Author, status, likes, share count and every timestamp are absent on
  /// purpose. Those are the server's — a client that could send `status:
  /// published` would be approving its own article, which is the one thing the
  /// review queue exists to prevent.
  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'category': category,
        'titleHinglish': titleHinglish,
        'contentHinglish': contentHinglish,
      };
}
