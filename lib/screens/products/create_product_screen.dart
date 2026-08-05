import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/voice_input_button.dart';

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();
  final _pdfLinkCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _coverUrlCtrl.dispose();
    _pdfLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission Denied: Only Admin can add resources.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _productService.createProduct(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: _priceCtrl.text.trim().isEmpty ? 'Free' : _priceCtrl.text.trim(),
        coverImageUrl: _coverUrlCtrl.text.trim(),
        pdfLink: _pdfLinkCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Digital resource added to Library!', style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add resource: $e', style: const TextStyle(fontFamily: 'Outfit')),
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
    final auth = context.watch<AuthProvider>();

    // Guard check inside build just in case
    if (!auth.isAdmin) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          child: const Center(
            child: Text(
              '🔒 Unauthorised Access',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 18, color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

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
                        '➕ Add Library Book / PDF',
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

              // Creation Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Upload cover, set pricing, description, and link to books/PDFs for user access.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          'Resource Title',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: const InputDecoration(hintText: 'e.g., Guide to Mindful Silence'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter a title' : null,
                        ),
                        const SizedBox(height: 20),

                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 4,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'Provide a synopsis of the book or resources...',
                            suffixIcon: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                VoiceInputButton(controller: _descCtrl, iconSize: 18),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter a description' : null,
                        ),
                        const SizedBox(height: 20),

                        // Price
                        const Text(
                          'Price Tag',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: const InputDecoration(hintText: 'e.g., Free, ₹49, ₹99'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please set a price tag' : null,
                        ),
                        const SizedBox(height: 20),

                        // Cover Image URL
                        const Text(
                          'Cover Image URL',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _coverUrlCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: const InputDecoration(hintText: 'HTTPS link to cover photo image'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter a cover image URL' : null,
                        ),
                        const SizedBox(height: 20),

                        // Drive / PDF Link
                        const Text(
                          'PDF Link (Google Drive / Direct URL)',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pdfLinkCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                          decoration: const InputDecoration(hintText: 'e.g., https://drive.google.com/...'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a PDF link';
                            if (!v.startsWith('http://') && !v.startsWith('https://')) {
                              return 'Please enter a valid URL beginning with http/https';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Save Product Button
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
                                onTap: _isSaving ? null : _publishProduct,
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
                                          '💾 Add to Library',
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
