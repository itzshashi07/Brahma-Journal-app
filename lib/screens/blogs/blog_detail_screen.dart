import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/blog_service.dart';
import '../../models/blog_post.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/article_categories.dart';
import '../../core/theme/app_theme.dart';
import '../../services/moderation_service.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/community_cta.dart';

class BlogDetailScreen extends StatefulWidget {
  final String blogId;
  const BlogDetailScreen({super.key, required this.blogId});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final BlogService _blogService = BlogService();
  final _commentCtrl = TextEditingController();
  BlogPost? _cachedBlog;

  /// Reading language. English is the written original; Hinglish is the same
  /// article, not a machine translation, and is only offered where one exists.
  bool _hinglish = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// Shares the article itself rather than a fake "link copied" message — the
  /// old button incremented the counter and told the user it was simulated.
  Future<void> _shareArticle(BlogPost blog) async {
    final title = _hinglish && blog.titleHinglish.isNotEmpty
        ? blog.titleHinglish
        : blog.title;
    final body = _hinglish && blog.hasHinglish ? blog.contentHinglish : blog.content;
    final excerpt = body.length > 400 ? '${body.substring(0, 400).trim()}…' : body;

    await Share.share(
      '$title\n\n$excerpt\n\n'
      '— InnenFlow\n'
      'Join the community: ${AppConstants.communityWhatsAppUrl}\n'
      'Instagram: ${AppConstants.instagramUrl}',
      subject: title,
    );
    await _blogService.incrementShares(blog.id);
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;

    final auth = context.read<AuthProvider>();
    final commenterName = auth.profile?.name ?? 'Friend';
    final commenterEmail = auth.user?.email ?? '';

    try {
      await _blogService.addComment(
        blogId: widget.blogId,
        authorName: commenterName,
        authorEmail: commenterEmail,
        content: _commentCtrl.text.trim(),
      );
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to comment: $e')),
      );
    }
  }

  Future<void> _confirmDeleteBlog(BuildContext context, String blogId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Article?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to permanently delete this article?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _blogService.deleteBlog(blogId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Article deleted successfully.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.green),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return StreamBuilder<List<BlogPost>>(
      stream: _blogService.streamBlogs(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          try {
            _cachedBlog = snapshot.data!.firstWhere((b) => b.id == widget.blogId);
          } catch (_) {}
        }

        if (_cachedBlog == null) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
          );
        }

        final blog = _cachedBlog!;

        // An article in review is readable by its author and by the admin
        // reviewing it, and by nobody else — including through a direct link,
        // which is the only way anyone else could arrive here.
        if (!blog.visibleTo(viewerUid: auth.user?.uid, isAdmin: auth.isAdmin)) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppTheme.textPrimary, size: 20),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'This article has not been published yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                height: 1.6,
                                color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final hasLiked = auth.user != null && blog.likes.contains(auth.user!.uid);
        final dateStr = DateFormat('dd MMM yyyy').format(blog.createdAt);

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
                        Expanded(
                          child: Text(
                            blog.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // An author can remove their own article; an admin can
                        // remove anyone's. Both paths are enforced again in
                        // firestore.rules — this only hides a button that would
                        // otherwise fail.
                        if (auth.isAdmin ||
                            (auth.user != null && blog.uid == auth.user!.uid)) ...[
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDeleteBlog(context, blog.id),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Reporting and blocking are offered on somebody
                        // else's article only: flagging your own writing is
                        // meaningless, and the delete control above is what you
                        // actually want for it.
                        if (auth.user != null && blog.uid != auth.user!.uid)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: AppTheme.textPrimary, size: 20),
                            color: AppTheme.bgCard,
                            onSelected: (value) async {
                              if (value == 'report') {
                                await ReportSheet.show(
                                  context,
                                  contentKind: 'blog',
                                  contentId: blog.id,
                                  excerpt: blog.title,
                                  reportedUid: blog.uid,
                                );
                              } else if (value == 'block') {
                                await ModerationService().blockUser(blog.uid);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Blocked. You will not see ${blog.authorName}\'s writing again.',
                                        style: const TextStyle(fontFamily: 'Outfit')),
                                    backgroundColor: AppTheme.primary,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'report',
                                child: Text('Report this article',
                                    style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: AppTheme.textPrimary)),
                              ),
                              PopupMenuItem(
                                value: 'block',
                                child: Text('Block this author',
                                    style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        color: AppTheme.textPrimary)),
                              ),
                            ],
                          ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary, size: 20),
                          onPressed: () => _shareArticle(blog),
                        ),
                      ],
                    ),
                  ),

                  // Reading Feed & Comments
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only ever seen by the author or the admin — anyone
                          // else was turned away above.
                          if (!blog.isPublished) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (blog.status == BlogStatus.rejected
                                        ? Colors.redAccent
                                        : AppTheme.accent)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (blog.status == BlogStatus.rejected
                                          ? Colors.redAccent
                                          : AppTheme.accent)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    blog.status.label,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: blog.status == BlogStatus.rejected
                                          ? Colors.redAccent
                                          : AppTheme.accentLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    blog.reviewNote.isNotEmpty
                                        ? blog.reviewNote
                                        : 'Only you and the InnenFlow team can '
                                            'read this until it is approved.',
                                    style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        height: 1.5,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Category — the app bar truncates the title, so the
                          // reader gets the subject and the full headline here.
                          _CategoryChip(category: blog.category),
                          const SizedBox(height: 12),
                          Text(
                            _hinglish && blog.titleHinglish.isNotEmpty
                                ? blog.titleHinglish
                                : blog.title,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 24,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Author & Metadata Row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primary.withOpacity(0.2),
                                child: Text(
                                  blog.authorName.isNotEmpty ? blog.authorName[0].toUpperCase() : 'A',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: AppTheme.primaryLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    blog.authorName,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Language switch — only where a Hinglish version was
                          // actually written. Offering a toggle that silently
                          // shows the same English text would be worse than no
                          // toggle at all.
                          if (blog.hasHinglish) ...[
                            _LanguageSwitch(
                              hinglish: _hinglish,
                              onChanged: (v) => setState(() => _hinglish = v),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Content Body
                          Text(
                            _hinglish && blog.hasHinglish
                                ? blog.contentHinglish
                                : blog.content,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 24),

                          const CommunityCta(),
                          const SizedBox(height: 24),

                          // Like & Share Counts
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  hasLiked ? Icons.favorite : Icons.favorite_border,
                                  color: hasLiked ? Colors.redAccent : AppTheme.textMuted,
                                  size: 22,
                                ),
                                onPressed: () {
                                  if (auth.user != null) {
                                    _blogService.toggleLike(blog.id, auth.user!.uid);
                                  }
                                },
                              ),
                              Text(
                                '${blog.likes.length} Likes',
                                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(width: 24),
                              const Icon(Icons.share_outlined, color: AppTheme.textMuted, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${blog.sharesCount} Shares',
                                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF2D2D4E), height: 1),
                          const SizedBox(height: 20),

                          // Comments Section Header
                          const Text(
                            'Comments',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Comments Feed Stream
                          StreamBuilder<List<BlogComment>>(
                            stream: _blogService.streamComments(blog.id),
                            builder: (context, commentSnapshot) {
                              if (commentSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                              }
                              final comments = commentSnapshot.data ?? [];
                              if (comments.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'No comments yet. Start the conversation!',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: comments.length,
                                itemBuilder: (context, cIdx) {
                                  final comment = comments[cIdx];
                                  final timeStr = DateFormat('h:mm a • d MMM').format(comment.createdAt);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgCardLight.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2D2D4E), width: 0.8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              comment.authorName,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryLight,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  timeStr,
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 11,
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => ReportSheet.show(
                                                    context,
                                                    contentKind: 'comment',
                                                    contentId: comment.id,
                                                    parentId: blog.id,
                                                    excerpt: comment.content,
                                                    reportedUid: comment.uid,
                                                  ),
                                                  child: const Icon(
                                                      Icons.flag_outlined,
                                                      size: 13,
                                                      color: AppTheme.textMuted),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          comment.content,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 13,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  // Comment Input Bar
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.bgCard,
                      border: Border(top: BorderSide(color: Color(0xFF2D2D4E))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.bgCardLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _postComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _postComment,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = ArticleCategories.byId(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: cat.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cat.icon, size: 13, color: cat.color),
          const SizedBox(width: 6),
          Text(
            cat.label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: cat.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// English ⇄ Hinglish, as a two-segment switch rather than a dropdown: there
/// are exactly two options and both should be visible without a tap.
class _LanguageSwitch extends StatelessWidget {
  final bool hinglish;
  final ValueChanged<bool> onChanged;

  const _LanguageSwitch({required this.hinglish, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('English', !hinglish, () => onChanged(false)),
          _seg('Hinglish', hinglish, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
