import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/email_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _selectedCategory = 'General Query';

  bool _isSubmitting = false;

  /// Opens WhatsApp with the user's typed message pre-filled, so a failed
  /// in-app send does not cost them the text they just wrote.
  Future<void> _launchWhatsAppWithMessage(String message) async {
    final text = Uri.encodeComponent(
      message.isEmpty ? 'Hello, I need help with InnenFlow.' : message,
    );
    final url = Uri.parse('https://wa.me/918078633912?text=$text');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      await _launchWhatsApp();
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/918078633912');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How does the daily streak calculation work?',
      'a': 'Your day streak updates automatically each day you complete a new journal entry. Writing down your reflections consistently helps maintain a peaceful routine.'
    },
    {
      'q': 'Are my journal reflections secure?',
      'a': 'Yes, all entries are stored securely in your private user database on Firebase, isolated by your account credentials.'
    },
    {
      'q': 'How do I modify my monthly or annual subscription?',
      'a': 'Subscriptions are processed securely via Razorpay. You can manage or update billing mandates inside your user profile or email mandate links sent directly from Razorpay.'
    },
    {
      'q': 'Can I edit historical journal entries?',
      'a': 'InnenFlow follows a focus-forward daily policy. You can look back at past reflections at any time to analyze your path, but you can only create/edit reflections for the current day.'
    },
    {
      'q': 'Where do the meditation background sounds come from?',
      'a': 'Background ambient sound profiles (Forest, Bowls, Waves) are loaded dynamically from our Cloud Storage servers to save app storage space while delivering premium audio quality.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _submitSupportForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await EmailService().sendSupportQuery(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        category: _selectedCategory,
        message: _msgCtrl.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          _msgCtrl.clear();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Message Sent', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: const Text(
                'Thank you — your message has reached us. We read every one and will get back to you shortly.',
                style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.primary, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          );
        } else {
          // Sending goes through a Cloud Function that holds the mail
          // credentials. When it is unreachable — not deployed, or offline —
          // the message would otherwise be lost silently after the user typed
          // it out. Hand them the channel that does work instead of a dead end.
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Could not send just now',
                  style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: const Text(
                'Your message has not been sent. Please reach us on WhatsApp — we reply there fastest, and nothing you typed is lost.',
                style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _launchWhatsAppWithMessage(_msgCtrl.text.trim());
                  },
                  child: const Text('Open WhatsApp'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
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
                        'Support & Help',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              // Custom tab bar
              TabBar(
                controller: _tabCtrl,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [
                  Tab(text: 'FAQs'),
                  Tab(text: 'Contact Us'),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // FAQs Tab
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _faqs.length,
                      itemBuilder: (ctx, i) {
                        final faq = _faqs[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2D2D4E)),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: AppTheme.primary,
                              collapsedIconColor: AppTheme.textMuted,
                              title: Text(
                                faq['q']!,
                                style: const TextStyle(
                                  fontFamily: 'Outfit', fontSize: 14,
                                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                  child: Text(
                                    faq['a']!,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit', fontSize: 13,
                                      color: AppTheme.textSecondary, height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Contact Form Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Direct Support info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_outlined, size: 16, color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Call support: +91 8078633912',
                                        style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Hours: 10:00 AM - 6:00 PM',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Color(0xFF2D2D4E)),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _launchWhatsApp,
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                                    label: const Text('Chat on WhatsApp', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              dropdownColor: const Color(0xFF16162A),
                              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category_outlined, color: AppTheme.textMuted, size: 18),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'General Query', child: Text('General Query')),
                                DropdownMenuItem(value: 'General Feedback', child: Text('General Feedback')),
                                DropdownMenuItem(value: 'Technical Bug', child: Text('Technical Bug')),
                                DropdownMenuItem(value: 'Payment Issue', child: Text('Payment Issue')),
                              ],
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted, size: 20),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your name' : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted, size: 20),
                              ),
                              validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _msgCtrl,
                              maxLines: 4,
                              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                              decoration: const InputDecoration(
                                labelText: 'Your Message',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your message' : null,
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              height: 52,
                              child: _isSubmitting
                                  ? Container(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: _submitSupportForm,
                                          child: const Center(
                                            child: Text(
                                              'Send Message',
                                              style: TextStyle(
                                                fontFamily: 'Outfit', fontSize: 16,
                                                fontWeight: FontWeight.w600, color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
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
  }
}
