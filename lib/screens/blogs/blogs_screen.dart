import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/blog_service.dart';
import '../../services/moderation_service.dart';
import '../../models/blog_post.dart';
import '../../core/constants/article_categories.dart';
import '../../core/theme/app_theme.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key});

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  final BlogService _blogService = BlogService();
  final ModerationService _moderation = ModerationService();

  /// Authors this reader has blocked.
  ///
  /// Read once when the screen opens rather than streamed: the set changes only
  /// when this member blocks somebody, which happens on the article screen and
  /// returns here through a rebuild anyway. A second live listener on every
  /// visit would cost a permanent subscription for a value that is almost
  /// always empty.
  Set<String> _blocked = const {};

  /// Null means "all". Only categories that actually have articles are shown,
  /// so the filter row never offers an empty result.
  String? _selectedCategory;

  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    final blocked = await _moderation.blockedUidsOnce();
    if (mounted) setState(() => _blocked = blocked);
  }

  /// Writes the bundled article library to Firestore under the admin's account.
  ///
  /// Behind a confirmation because it touches every article document at once —
  /// safe to repeat (same slugs, merged), but not something to trigger by a
  /// stray tap.
  Future<void> _publishLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Publish article library?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text(
          'Publishes every bundled article under your admin account. Running it '
          'again updates the same articles — it does not create duplicates, and '
          'likes and comments are kept.',
          style: TextStyle(
              fontFamily: 'Outfit', color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _publishing = true);
    try {
      final count = await _blogService.publishLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count articles published.',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publish failed: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Admin: publishes a member's article.
  Future<void> _approve(BlogPost blog) async {
    try {
      await _blogService.approveBlog(blog);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${blog.title}" is live in Sanctuary.',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not approve: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Admin: turns an article down with a reason.
  ///
  /// The reason is asked for rather than optional. A rejection with no words
  /// attached is the thing that makes somebody stop writing.
  Future<void> _reject(BlogPost blog) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Not approve this article?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${blog.title}" stays with its author and is not deleted. '
              'Tell them what would need to change.',
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(
                  fontFamily: 'Outfit', color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Please remove the personal details in paragraph two.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Send back',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;

    try {
      await _blogService.rejectBlog(blog.id, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent back to the author.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send it back: $e',
              style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BlogPost blog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this article?',
            style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: Text(
          '"${blog.title}" will be removed for everyone, along with its likes '
          'and comments. This cannot be undone.',
          style: const TextStyle(
              fontFamily: 'Outfit', color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _blogService.deleteBlog(blog.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article deleted.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete: $e',
                style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        '📖 The Reading Room',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (auth.isAdmin)
                      IconButton(
                        tooltip: 'Publish article library',
                        onPressed: _publishing ? null : _publishLibrary,
                        icon: _publishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                              )
                            : const Icon(Icons.library_add_outlined,
                                color: AppTheme.textMuted, size: 20),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),

              // Blog Feed Stream
              Expanded(
                child: StreamBuilder<List<BlogPost>>(
                  stream: _blogService.streamBlogs(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading articles: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent, fontFamily: 'Outfit'),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                    }

                    final all = snapshot.data ?? [];

                    // What this reader is allowed to see: everything published,
                    // plus their own work still in review, plus everything if
                    // they are the one reviewing it.
                    final blogs = all
                        .where((b) => b.visibleTo(
                            viewerUid: auth.user?.uid, isAdmin: auth.isAdmin))
                        .where((b) => b.isPublished)
                        // Blocking has to actually remove the writing from
                        // view. A block that leaves it in the feed is a button
                        // that lies about what it did.
                        .where((b) => !_blocked.contains(b.uid))
                        .toList();

                    // Their own drafts and the admin's queue are shown above
                    // the feed rather than mixed into it — an article that
                    // nobody else can read yet does not belong in a list of
                    // articles everybody can.
                    final inReview = all
                        .where((b) => !b.isPublished)
                        .where((b) => auth.isAdmin || b.uid == auth.user?.uid)
                        .toList();

                    if (blogs.isEmpty && inReview.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '🕊️',
                              style: TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nothing written here yet.',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.push('/blogs/create'),
                              child: const Text('Write the first article'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Only the categories present in the feed, in the order the
                    // constants declare them, so the row is stable between
                    // rebuilds instead of reordering as posts arrive.
                    final present = ArticleCategories.all
                        .where((c) => blogs.any((b) => b.category == c.id))
                        .toList();
                    if (_selectedCategory != null &&
                        !present.any((c) => c.id == _selectedCategory)) {
                      _selectedCategory = null;
                    }
                    final visible = _selectedCategory == null
                        ? blogs
                        : blogs
                            .where((b) => b.category == _selectedCategory)
                            .toList();

                    return Column(
                      children: [
                        if (present.length > 1)
                          _CategoryFilterRow(
                            categories: present,
                            selected: _selectedCategory,
                            counts: {
                              for (final c in present)
                                c.id: blogs.where((b) => b.category == c.id).length
                            },
                            total: blogs.length,
                            onChanged: (id) =>
                                setState(() => _selectedCategory = id),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: visible.length + (inReview.isEmpty ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (inReview.isNotEmpty && index == 0) {
                                return _ReviewSection(
                                  articles: inReview,
                                  isAdmin: auth.isAdmin,
                                  onApprove: _approve,
                                  onReject: _reject,
                                  onOpen: (b) => context.push('/blogs/${b.id}'),
                                );
                              }
                              final i = inReview.isEmpty ? index : index - 1;
                              return _buildBlogCard(visible[i], auth);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Writing is open to every member — the FAB is the invitation.
      floatingActionButton: auth.user != null
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Write',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              onPressed: () => context.push('/blogs/create'),
            )
          : null,
    );
  }

  Widget _buildBlogCard(BlogPost blog, AuthProvider auth) {
    final hasLiked = auth.user != null && blog.likes.contains(auth.user!.uid);
    // The listing carries an excerpt rather than the article — see
    // BlogPost.snippet, which reads whichever of the two is present.
    final snippet = blog.snippet;

    final dateStr = DateFormat('dd MMM yyyy').format(blog.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D4E), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/blogs/${blog.id}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(builder: (_) {
                      final cat = ArticleCategories.byId(blog.category);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cat.label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cat.color,
                            letterSpacing: 0.9,
                          ),
                        ),
                      );
                    }),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  blog.title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Snippet
                Text(
                  snippet,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                const Divider(color: Color(0xFF2D2D4E), height: 1),
                const SizedBox(height: 12),

                // Interactive Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Likes
                        IconButton(
                          icon: Icon(
                            hasLiked ? Icons.favorite : Icons.favorite_border,
                            color: hasLiked ? Colors.redAccent : AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            if (auth.user != null) {
                              _blogService.toggleLike(blog.id, liked: hasLiked);
                            }
                          },
                        ),
                        Text(
                          '${blog.likes.length}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Comments icon
                        const Icon(
                          Icons.chat_bubble_outline_outlined,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Read More',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // An author can remove their own article without opening it
                    // first; an admin can remove anyone's. Both are enforced
                    // again in firestore.rules — this only shows a button that
                    // would otherwise be a permission error.
                    if (auth.isAdmin ||
                        (auth.user != null && blog.uid == auth.user!.uid))
                      IconButton(
                        tooltip: 'Delete my article',
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDelete(blog),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.share_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        _blogService.recordShare(blog.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Link copied to clipboard! (Simulated)',
                              style: TextStyle(fontFamily: 'Outfit'),
                            ),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal category filter above the feed.
///
/// With seventy articles a single reverse-chronological list is a wall — most
/// people arrive wanting one subject. Counts are shown because an unlabelled
/// filter makes you tap to find out whether it was worth tapping.
class _CategoryFilterRow extends StatelessWidget {
  final List<ArticleCategory> categories;
  final String? selected;
  final Map<String, int> counts;
  final int total;
  final ValueChanged<String?> onChanged;

  const _CategoryFilterRow({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected == null ? null : ArticleCategories.byId(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(
                label: 'All',
                count: total,
                color: AppTheme.primaryLight,
                icon: Icons.grid_view_rounded,
                active: selected == null,
                onTap: () => onChanged(null),
              ),
              ...categories.map((c) => _chip(
                    label: c.label,
                    count: counts[c.id] ?? 0,
                    color: c.color,
                    icon: c.icon,
                    active: selected == c.id,
                    onTap: () => onChanged(selected == c.id ? null : c.id),
                  )),
            ],
          ),
        ),
        if (active != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              active.blurb,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.20)
                : AppTheme.bgCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: active ? color : AppTheme.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? color : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? color : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: active ? color : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The review strip above the feed.
///
/// Two audiences, one widget, because they are looking at the same documents
/// from opposite ends: the admin sees a queue with two buttons on each row, the
/// author sees where their own writing has got to. Nobody else sees any of it.
class _ReviewSection extends StatelessWidget {
  final List<BlogPost> articles;
  final bool isAdmin;
  final Future<void> Function(BlogPost) onApprove;
  final Future<void> Function(BlogPost) onReject;
  final void Function(BlogPost) onOpen;

  const _ReviewSection({
    required this.articles,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final pending =
        articles.where((a) => a.status == BlogStatus.pending).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  size: 16, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                isAdmin
                    ? (pending == 1
                        ? '1 article waiting for you'
                        : '$pending articles waiting for you')
                    : 'Your writing',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAdmin
                ? 'Nothing here is public until you approve it.'
                : 'Sanctuary is read by everyone, so an article is published '
                    'once it has been approved. You can keep reading and '
                    'editing yours in the meantime.',
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                height: 1.5,
                color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          ...articles.map((a) => _ReviewRow(
                article: a,
                isAdmin: isAdmin,
                onApprove: () => onApprove(a),
                onReject: () => onReject(a),
                onOpen: () => onOpen(a),
              )),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final BlogPost article;
  final bool isAdmin;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  const _ReviewRow({
    required this.article,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final rejected = article.status == BlogStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rejected
              ? Colors.redAccent.withValues(alpha: 0.35)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isAdmin
                            ? '${article.authorName} · ${article.status.label}'
                            : article.status.label,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rejected
                              ? Colors.redAccent
                              : AppTheme.accentLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.textMuted),
              ],
            ),
          ),

          // The reason, to whoever it is for. The author needs it to act on;
          // the admin needs it to remember what they already said.
          if (article.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                article.reviewNote,
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],

          if (isAdmin) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Send back',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Publish',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
