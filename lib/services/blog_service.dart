import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/blog_post.dart';
import 'api_feed.dart';
import 'api_service.dart';
import 'article_library.dart';

/// The Sanctuary — articles and their comments — over the API.
///
/// ─────────────────────────────────────────────────────────────────────────
/// The listing no longer carries the articles
///
/// `streamBlogs()` was an open Firestore listener on the whole `blogs`
/// collection, and every document it delivered carried the full article: up to
/// 100,000 characters of `content` and another 100,000 of `contentHinglish`. A
/// hundred articles is potentially twenty megabytes, streamed to a phone on
/// mobile data, to render a scrolling list of cards showing a title, an author
/// and a 120-character preview.
///
/// Worse, `blog_detail_screen` subscribed to that same stream to display **one**
/// article — it read the whole library and searched it in Dart for the id it
/// wanted.
///
/// Now the listing returns summaries with a server-cut excerpt, and [byId]
/// fetches the article at the moment somebody opens it. See [BlogPost.excerpt]
/// and `EXCERPT_CHARS` in the API's routes/blogs.js.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Authorship and approval moved to the server
///
/// Every write here used to stamp its own `uid`, decide its own `status` from a
/// locally-read admin flag, and raise its own admin alert. firestore.rules was
/// the only thing standing between that and a member publishing straight to the
/// Sanctuary. The API takes the author from the verified token and decides the
/// status itself, so the client no longer names either — and cannot.
class BlogService {
  final ApiService _api = ApiService();

  ApiFeed<List<BlogPost>>? _feed;
  final Map<String, ApiFeed<List<BlogComment>>> _comments = {};

  /// Every article the caller is allowed to see: the published library, plus
  /// their own work in whatever state it is in, plus everything if they are an
  /// admin. The server decides which — see [BlogPost.visibleTo] for what the UI
  /// then does with it.
  ///
  /// The posts carry no `content`. Use [byId] to read one.
  Stream<List<BlogPost>> streamBlogs() {
    _feed ??= ApiFeed(_loadBlogs, debugLabel: 'blogs');
    return _feed!.stream;
  }

  Future<void> refresh() async {
    await _feed?.refresh();
  }

  Future<List<BlogPost>> _loadBlogs() async {
    // 100 is the server's ceiling for this endpoint. The Sanctuary is a browsing
    // surface rather than an endless feed, and a hundred summaries is a small
    // response now that the prose is not attached.
    final body = await _api.get('/api/blogs', query: {'limit': '100'});
    return ((body?['blogs'] as List?) ?? const [])
        .map((b) => BlogPost.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  /// One article, with its text.
  ///
  /// Returns null for an article that does not exist *or* that the caller may
  /// not read — the server answers both with a 404 on purpose, because a 403
  /// confirms the id is real and that is more than a stranger should learn
  /// about the moderation queue.
  Future<BlogPost?> byId(String blogId) async {
    try {
      final body = await _api.get('/api/blogs/$blogId');
      final raw = body?['blog'];
      return raw == null
          ? null
          : BlogPost.fromJson(Map<String, dynamic>.from(raw));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Submits an article.
  ///
  /// A member's goes into the review queue; an admin's is published
  /// immediately, because an admin does not queue behind themselves. That
  /// decision is the server's — the `autoPublish` argument this used to take
  /// was the client telling the server what privilege it had.
  Future<BlogStatus> createBlog({
    required String title,
    required String content,
    String category = '',
    String titleHinglish = '',
    String contentHinglish = '',
  }) async {
    final body = await _api.post('/api/blogs', {
      'title': title,
      'content': content,
      'category': category,
      'titleHinglish': titleHinglish,
      'contentHinglish': contentHinglish,
    });

    await refresh();
    return BlogStatus.parse(body?['blog']?['status']);
  }

  /// Admin: publishes an article that was waiting.
  ///
  /// The broadcast to every member fires server-side in the same request, so
  /// members are told about an article at the moment it actually becomes
  /// readable — and it cannot be sent for an article whose approval then failed
  /// to save.
  Future<void> approveBlog(BlogPost blog) async {
    await _api.patch('/api/blogs/${blog.id}/review', {
      'status': 'published',
      'reviewNote': '',
    });
    await refresh();
  }

  /// Admin: turns an article down, with a reason.
  ///
  /// Deliberately not a delete. The author keeps their draft and can see what
  /// was said about it; deleting somebody's writing without a word is how you
  /// lose the person as well as the article.
  Future<void> rejectBlog(String blogId, {String note = ''}) async {
    await _api.patch('/api/blogs/$blogId/review', {
      'status': 'rejected',
      'reviewNote': note,
    });
    await refresh();
  }

  Future<void> deleteBlog(String blogId) async {
    await _api.delete('/api/blogs/$blogId');
    await refresh();
  }

  /// How many published articles each author has, keyed by uid.
  ///
  /// Counted from the listing the caller already has rather than by re-reading
  /// the collection. This used to fetch every article — bodies and all — and
  /// tally them in Dart, which is the most expensive imaginable way to produce
  /// a map of small integers.
  Future<Map<String, int>> publishedCountsByAuthor() async {
    try {
      final posts = _feed?.value ?? await _loadBlogs();
      final counts = <String, int>{};
      for (final post in posts) {
        if (!post.isPublished || post.uid.isEmpty) continue;
        counts[post.uid] = (counts[post.uid] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('⚠️ blogs: author counts unavailable: $e');
      return const {};
    }
  }

  // ─────────────────────────── reactions ───────────────────────────

  /// Likes or unlikes, and returns the new state.
  ///
  /// Two endpoints rather than a read-modify-write of the array. The old
  /// version fetched `likes`, edited the list in Dart and wrote it back, which
  /// loses a like whenever two people tap at once — and a counter that goes
  /// backwards is exactly the kind of thing people notice.
  Future<bool> toggleLike(String blogId, {required bool liked}) async {
    final body = liked
        ? await _api.delete('/api/blogs/$blogId/like')
        : await _api.post('/api/blogs/$blogId/like');
    await refresh();
    return (body?['liked'] as bool?) ?? !liked;
  }

  Future<void> recordShare(String blogId) async {
    await _api.post('/api/blogs/$blogId/share');
  }

  // ─────────────────────────── comments ───────────────────────────

  Stream<List<BlogComment>> streamComments(String blogId) {
    final feed = _comments.putIfAbsent(
      blogId,
      () => ApiFeed(
        () => _loadComments(blogId),
        debugLabel: 'blogs/comments',
      ),
    );
    return feed.stream;
  }

  Future<List<BlogComment>> _loadComments(String blogId) async {
    final body = await _api.get(
      '/api/blogs/$blogId/comments',
      query: {'limit': '100'},
    );
    return ((body?['comments'] as List?) ?? const [])
        .map((c) => BlogComment.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
  }

  /// Adds a comment. The author's name and email come off the token
  /// server-side, so nothing here can post under somebody else's name.
  Future<void> addComment({
    required String blogId,
    required String content,
  }) async {
    await _api.post('/api/blogs/$blogId/comments', {'content': content});
    await _comments[blogId]?.refresh();
  }

  Future<void> deleteComment(String blogId, String commentId) async {
    await _api.delete('/api/blogs/$blogId/comments/$commentId');
    await _comments[blogId]?.refresh();
  }

  // ─────────────────────────── seeding ───────────────────────────

  /// Publishes the bundled article library under the admin's own account.
  ///
  /// Safe to run more than once: the server upserts nothing, so a second run
  /// would duplicate — which is why this reads the existing titles first and
  /// skips what is already there. Firestore's `set(merge: true)` keyed on the
  /// slug gave that for free; a REST create does not, and pretending otherwise
  /// would double the Sanctuary the first time somebody tapped the button
  /// twice.
  ///
  /// The API refuses a create from anybody without the admin claim, so there is
  /// no privileged path here a member could reach.
  Future<int> publishLibrary({
    void Function(int done, int total)? onProgress,
  }) async {
    final seeds = await ArticleLibrary.load();
    final existing = (await _loadBlogs()).map((b) => b.title).toSet();

    var written = 0;
    for (var i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      if (!existing.contains(seed.title)) {
        await _api.post('/api/blogs', {
          'title': seed.title,
          'content': seed.content,
          'category': seed.category,
          'titleHinglish': seed.titleHinglish,
          'contentHinglish': seed.contentHinglish,
        });
        written++;
      }
      onProgress?.call(i + 1, seeds.length);
    }

    await refresh();
    return written;
  }

  Future<void> dispose() async {
    await _feed?.dispose();
    for (final feed in _comments.values) {
      await feed.dispose();
    }
    _comments.clear();
    _feed = null;
  }
}
