import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blog_post.dart';
import 'notification_service.dart';

class BlogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'blogs';

  // Stream all blog posts
  Stream<List<BlogPost>> streamBlogs() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BlogPost.fromFirestore(doc)).toList();
    });
  }

  // Create a new blog post
  Future<void> createBlog({
    required String title,
    required String content,
    required String authorName,
    required String authorEmail,
  }) async {
    final docRef = _firestore.collection(_collectionPath).doc();
    final post = BlogPost(
      id: docRef.id,
      title: title,
      content: content,
      authorName: authorName,
      authorEmail: authorEmail,
      createdAt: DateTime.now(),
    );
    await docRef.set(post.toMap());

    // Trigger local push notification
    await NotificationService().sendNotification(
      title: 'New Spiritual Post 🕉️',
      body: '"$title" by $authorName has been added to Sanctuary!',
      type: 'blog',
      route: '/blogs/${docRef.id}',
    );
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
