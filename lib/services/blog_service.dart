import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blog_post.dart';
import 'article_library.dart';
import 'notification_service.dart';

class BlogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'blogs';

  /// Every article, in review or not.
  ///
  /// The queue is filtered by the caller rather than by the query, because a
  /// `where('status', ...)` would exclude every article written before approval
  /// existed — those documents have no `status` field at all, and Firestore
  /// cannot match "missing" in an equality filter. Filtering in Dart means the
  /// existing library stays visible without a backfill migration.
  ///
  /// See [BlogPost.visibleTo] for what a given reader is allowed to see.
  Stream<List<BlogPost>> streamBlogs() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BlogPost.fromFirestore(doc)).toList();
    });
  }

  /// Writes an article and returns the state it landed in.
  ///
  /// A member's article goes to the admin first. That is the whole feature:
  /// /blogs is world-readable and is the app's public face, so the difference
  /// between "anyone can write" and "anyone can publish" is the difference
  /// between a community and an open comment box on the internet.
  ///
  /// The admin does not queue behind themselves — [autoPublish] is passed from
  /// the caller's own admin state, and firestore.rules independently refuses a
  /// self-published article from anyone without the claim, so a client that
  /// lies about it gets a permission error rather than a published post.
  Future<BlogStatus> createBlog({
    required String title,
    required String content,
    required String authorName,
    required String authorEmail,
    String category = '',
    String titleHinglish = '',
    String contentHinglish = '',
    bool autoPublish = false,
  }) async {
    final docRef = _firestore.collection(_collectionPath).doc();
    final status = autoPublish ? BlogStatus.published : BlogStatus.pending;
    final post = BlogPost(
      id: docRef.id,
      // From the signed-in session, never from the caller: the rule compares it
      // against request.auth.uid, so a forged author is rejected.
      uid: FirebaseAuth.instance.currentUser?.uid ?? '',
      title: title,
      content: content,
      category: category,
      titleHinglish: titleHinglish,
      contentHinglish: contentHinglish,
      authorName: authorName,
      authorEmail: authorEmail,
      createdAt: DateTime.now(),
      status: status,
      publishedAt: autoPublish ? DateTime.now() : null,
    );
    await docRef.set(post.toMap());

    if (status == BlogStatus.published) {
      await _announce(title: title, authorName: authorName, blogId: docRef.id);
    } else {
      // Nobody else is told about an article nobody else can read yet. The
      // operator is, because otherwise it sits in the queue until they happen
      // to open the Sanctuary.
      await _alertAdmin(
        title: '📝 An article is waiting for approval',
        body: '"$title" by $authorName. Approve it to publish it to Sanctuary.',
      );
    }

    return status;
  }

  /// Admin: publishes an article that was waiting.
  ///
  /// The broadcast fires here rather than at write time, so members are told
  /// about an article at the moment it actually becomes readable.
  Future<void> approveBlog(BlogPost blog) async {
    await _firestore.collection(_collectionPath).doc(blog.id).update({
      'status': BlogStatus.published.wire,
      'publishedAt': FieldValue.serverTimestamp(),
      'reviewNote': '',
    });

    await _announce(
      title: blog.title,
      authorName: blog.authorName,
      blogId: blog.id,
    );
  }

  /// Admin: turns an article down, with a reason.
  ///
  /// Deliberately not a delete. The author keeps their draft and can see what
  /// was said about it; deleting somebody's writing without a word is how you
  /// lose the person as well as the article.
  Future<void> rejectBlog(String blogId, {String note = ''}) async {
    await _firestore.collection(_collectionPath).doc(blogId).update({
      'status': BlogStatus.rejected.wire,
      'reviewNote': note,
    });
  }

  /// How many published articles each author has, keyed by uid.
  ///
  /// Read from /blogs, which is public, rather than kept as a counter on the
  /// profile: a counter is a number that can drift from the truth the moment an
  /// article is deleted, and this is one query for the whole community screen.
  Future<Map<String, int>> publishedCountsByAuthor() async {
    try {
      final snapshot = await _firestore.collection(_collectionPath).get();
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final post = BlogPost.fromFirestore(doc);
        if (!post.isPublished || post.uid.isEmpty) continue;
        counts[post.uid] = (counts[post.uid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  Future<void> _announce({
    required String title,
    required String authorName,
    required String blogId,
  }) async {
    await NotificationService().sendNotification(
      title: 'New Article Published ✍️',
      body: '"$title" by $authorName has been added to Sanctuary!',
      type: 'blog',
      route: '/blogs/$blogId',
    );
  }

  /// Raises an alert only an admin can read. Never throws into the caller —
  /// failing to notify the operator must not fail somebody's article.
  Future<void> _alertAdmin({required String title, required String body}) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'blog_review',
        'title': title,
        'body': body,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Publishes the bundled article library under the admin's own account.
  ///
  /// Writes are keyed by the article's slug and merged, so this is safe to run
  /// more than once: a second run edits the same documents rather than
  /// duplicating them, and `likes`, `sharesCount` and the comments subcollection
  /// are left untouched because they are never part of the payload.
  ///
  /// Firestore rules already restrict create and update on /blogs to admins, so
  /// there is no privileged path here that a normal member could reach.
  Future<int> publishLibrary({
    required String authorName,
    required String authorEmail,
    void Function(int done, int total)? onProgress,
  }) async {
    final seeds = await ArticleLibrary.load();
    const chunkSize = 200; // well under Firestore's 500-write batch limit

    var written = 0;
    for (var start = 0; start < seeds.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, seeds.length);
      final batch = _firestore.batch();

      for (var i = start; i < end; i++) {
        final seed = seeds[i];
        batch.set(
          _firestore.collection(_collectionPath).doc(seed.slug),
          {
            'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
            'title': seed.title,
            'content': seed.content,
            'category': seed.category,
            'titleHinglish': seed.titleHinglish,
            'contentHinglish': seed.contentHinglish,
            'authorName': authorName,
            'authorEmail': authorEmail,
            'createdAt': Timestamp.fromDate(ArticleLibrary.dateFor(i)),
            // Written by the admin, so it skips the queue it would otherwise
            // be at the front of.
            'status': BlogStatus.published.wire,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      written = end;
      onProgress?.call(written, seeds.length);
    }

    return written;
  }

  // Delete a blog post
  Future<void> deleteBlog(String blogId) async {
    await _firestore.collection(_collectionPath).doc(blogId).delete();
  }

  // Toggle like
  Future<void> toggleLike(String blogId, String userId) async {
    final docRef = _firestore.collection(_collectionPath).doc(blogId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    await docRef.update({'likes': likes});
  }

  // Stream comments for a blog post
  Stream<List<BlogComment>> streamComments(String blogId) {
    return _firestore
        .collection(_collectionPath)
        .doc(blogId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BlogComment.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Add a comment
  Future<void> addComment({
    required String blogId,
    required String authorName,
    required String authorEmail,
    required String content,
  }) async {
    final commentRef = _firestore
        .collection(_collectionPath)
        .doc(blogId)
        .collection('comments')
        .doc();

    final comment = BlogComment(
      id: commentRef.id,
      // Taken from the signed-in session, never from the caller: the rule
      // compares it against request.auth.uid, so a forged value is rejected.
      uid: FirebaseAuth.instance.currentUser?.uid ?? '',
      authorName: authorName,
      authorEmail: authorEmail,
      content: content,
      createdAt: DateTime.now(),
    );

    await commentRef.set(comment.toMap());
  }

  // Increment shares
  Future<void> incrementShares(String blogId) async {
    await _firestore.collection(_collectionPath).doc(blogId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }
}
