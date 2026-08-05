import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/blog_service.dart';
import '../../models/blog_post.dart';
import '../../core/theme/app_theme.dart';

class BlogDetailScreen extends StatefulWidget {
  final String blogId;
  const BlogDetailScreen({super.key, required this.blogId});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final BlogService _blogService = BlogService();
  final _commentCtrl = TextEditingController();
  final _firestore = BlogService();
  BlogPost? _cachedBlog;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;

    final auth = context.read<AuthProvider>();
    final commenterName = auth.profile?.name ?? 'Seeker';
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
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary, size: 20),
                          onPressed: () {
                            _blogService.incrementShares(blog.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Link copied to clipboard! (Simulated)'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
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
                                    '$dateStr • Spiritual Guide',
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

                          // Content Body
                          Text(
                            blog.content,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
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
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
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
