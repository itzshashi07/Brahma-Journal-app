import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/blog_service.dart';
import '../../models/blog_post.dart';
import '../../core/theme/app_theme.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key});

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  final BlogService _blogService = BlogService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        '🕉️ Spiritual Sanctuary',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

                    final blogs = snapshot.data ?? [];
                    if (blogs.isEmpty) {
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
                              'No spiritual wisdom shared yet.',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (auth.isAdmin) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => context.push('/blogs/create'),
                                child: const Text('Write First Article'),
                              ),
                            ]
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: blogs.length,
                      itemBuilder: (context, index) {
                        final blog = blogs[index];
                        return _buildBlogCard(blog, auth);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add),
              onPressed: () => context.push('/blogs/create'),
            )
          : null,
    );
  }

  Widget _buildBlogCard(BlogPost blog, AuthProvider auth) {
    final hasLiked = auth.user != null && blog.likes.contains(auth.user!.uid);
    final snippet = blog.content.length > 120
        ? '${blog.content.substring(0, 120)}...'
        : blog.content;

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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'WISDOM',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
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
                              _blogService.toggleLike(blog.id, auth.user!.uid);
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
                    IconButton(
                      icon: const Icon(
                        Icons.share_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        _blogService.incrementShares(blog.id);
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
