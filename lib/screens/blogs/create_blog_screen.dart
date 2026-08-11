import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/blog_post.dart';
import '../../services/blog_service.dart';
import '../../core/constants/article_categories.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/voice_input_button.dart';

class CreateBlogScreen extends StatefulWidget {
  const CreateBlogScreen({super.key});

  @override
  State<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends State<CreateBlogScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _titleHiCtrl = TextEditingController();
  final _contentHiCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final BlogService _blogService = BlogService();
  bool _isSaving = false;

  String _category = ArticleCategories.all.first.id;

  /// The Hinglish fields stay collapsed until asked for: they are optional, and
  /// an empty pair of large boxes makes the form look like twice the work.
  bool _showHinglish = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleHiCtrl.dispose();
    _contentHiCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishBlog() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isSaving = true);
    try {
      final status = await _blogService.createBlog(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        category: _category,
        titleHinglish: _titleHiCtrl.text.trim(),
        contentHinglish: _contentHiCtrl.text.trim(),
        authorName: auth.profile?.displayName ?? 'Friend',
        // Was a hardcoded operator address. Only an admin reaches this screen,
        // so the signed-in account is always the right author — and baking a
        // real email into the binary just hands out a target for credential
        // stuffing against the one account that matters.
        authorEmail: auth.user?.email ?? '',
        // The admin does not queue behind themselves. firestore.rules checks
        // this independently, so a client that claims it without the claim gets
        // a permission error rather than a published article.
        autoPublish: auth.isAdmin,
      );

      if (mounted) {
        final published = status == BlogStatus.published;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              published
                  ? '✨ Article published to Sanctuary!'
                  : '✅ Sent for approval. It appears in Sanctuary once it is '
                      'approved — you can keep reading yours in the meantime.',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor:
                published ? const Color(0xFF10B981) : AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: published ? 3 : 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publishing failed: $e', style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Writing is open to every signed-in member; firestore.rules stamps the
    // author and only lets them delete or edit their own article.

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
                        '✍️ Write an Article',
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

              // Publish Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.watch<AuthProvider>().isAdmin
                              ? 'Share what you have learned — an experience, a lesson, '
                                  'something that helped you. Yours publishes straight away.'
                              : 'Anyone can write here. Share what you have learned — an '
                                  'experience, a lesson, something that helped you.\n\n'
                                  'Sanctuary is read by everyone, so an article is checked '
                                  'before it goes up. Yours appears the moment it is '
                                  'approved, and you can delete it any time.',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Category — stored on the post so the Sanctuary feed
                        // can filter; without it every article lands in one
                        // undifferentiated list.
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _category,
                              isExpanded: true,
                              dropdownColor: AppTheme.bgCard,
                              icon: const Icon(Icons.expand_more_rounded,
                                  color: AppTheme.textMuted),
                              items: ArticleCategories.all
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Row(
                                          children: [
                                            Icon(c.icon, size: 16, color: c.color),
                                            const SizedBox(width: 10),
                                            Text(
                                              c.label,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _category = v ?? _category),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title Field
                        const Text(
                          'Article Title',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'e.g., The Alchemy of Silent Meditation',
                            suffixIcon: VoiceInputButton(controller: _titleCtrl, iconSize: 18),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter a title' : null,
                        ),
                        const SizedBox(height: 24),

                        // Content Field
                        const Text(
                          'Wisdom Content',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _contentCtrl,
                          maxLines: 12,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit', height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'Share what you have been through, what you learned, what helped...',
                            suffixIcon: VoiceInputButton(controller: _contentCtrl, iconSize: 20),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please write your article contents' : null,
                        ),
                        const SizedBox(height: 20),

                        // Optional Hinglish version. Readers get a language
                        // switch only when this is filled in — a toggle that
                        // shows the same English text would be worse than none.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _showHinglish = !_showHinglish),
                            icon: Icon(
                              _showHinglish
                                  ? Icons.expand_less_rounded
                                  : Icons.translate_rounded,
                              size: 18,
                              color: AppTheme.primaryLight,
                            ),
                            label: Text(
                              _showHinglish
                                  ? 'Hide Hinglish version'
                                  : 'Add Hinglish version (optional)',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ),
                        ),
                        if (_showHinglish) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleHiCtrl,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                            decoration: InputDecoration(
                              hintText: 'Hinglish title',
                              suffixIcon:
                                  VoiceInputButton(controller: _titleHiCtrl, iconSize: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contentHiCtrl,
                            maxLines: 10,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontFamily: 'Outfit',
                                height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Wahi article, Hinglish mein...',
                              suffixIcon: VoiceInputButton(
                                  controller: _contentHiCtrl, iconSize: 20),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),

                        // Publish Button
                        SizedBox(
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _isSaving ? null : _publishBlog,
                                child: Center(
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          '🚀 Publish Article',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
