import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../models/user_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/avatar_editor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_update_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _selectedGender;
  bool _isSaving = false;
  bool _isLoading = true;

  Future<void> _launchWhatsApp() => _open('https://wa.me/918078633912');

  /// The WhatsApp community — where new builds are announced while the app is
  /// still off the store.
  Future<void> _openCommunity() => _open(AppConstants.communityWhatsAppUrl);

  Future<void> _open(String link) async {
    final url = Uri.parse(link);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not open the link';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      final profile = await _service.getProfile(auth.user!.uid);
      if (profile != null && mounted) {
        _nameCtrl.text = profile.name ?? '';
        _phoneCtrl.text = profile.phone ?? '';
        _ageCtrl.text = profile.age?.toString() ?? '';
        _selectedGender = profile.gender;
      }
    }
    setState(() => _isLoading = false);
  }

  /// Admin: announce the running build as the latest available.
  ///
  /// Existing installations check app_config/version on launch, so publishing
  /// here is what actually triggers the update prompt on everyone's phone.
  Future<void> _publishBuild() async {
    final notesCtrl = TextEditingController();
    var force = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Publish this build',
              style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Everyone on an older build is prompted to update next time they open the app.',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
                decoration: const InputDecoration(hintText: "What's new in this build?"),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: force,
                onChanged: (v) => setLocal(() => force = v ?? false),
                title: const Text('Required update',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: const Text('Blocks the app until they update',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.textMuted)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AppUpdateService.publishCurrentBuild(
        releaseNotes: notesCtrl.text.trim(),
        forceUpdate: force,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Published. Everyone will be prompted on next open.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not publish. Are you signed in as admin?',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        uid: auth.user!.uid,
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        email: auth.user!.email,
        age: _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text) : null,
        gender: _selectedGender,
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      );
      await _service.saveProfile(profile);
      await auth.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved!', style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

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
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20), onPressed: () => context.pop()),
                    const Expanded(child: Text('Profile', style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center)),
                    TextButton(
                      onPressed: () async {
                        await auth.signOut();
                        if (mounted) context.go('/login');
                      },
                      child: const Text('Logout', style: TextStyle(fontFamily: 'Outfit', color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Avatar — tap opens the spiritual avatar picker,
                        // filtered by the gender selected further down.
                        AvatarEditor(
                          uid: auth.user!.uid,
                          profile: profile,
                          gender: _selectedGender,
                          initials: profile?.initials ??
                              auth.user?.email?.substring(0, 1).toUpperCase() ??
                              'S',
                          onUpdated: () => auth.refreshProfile(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile?.displayName ?? 'Friend',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(
                          auth.user?.email ?? '',
                          style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 28),

                        // Form
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2D2D4E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Personal Information', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 16)),
                              const SizedBox(height: 20),

                              _ProfileField(label: 'Full Name', controller: _nameCtrl, icon: Icons.person_outlined),
                              const SizedBox(height: 14),
                              _ProfileField(label: 'Phone', controller: _phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                              const SizedBox(height: 14),
                              _ProfileField(label: 'Age', controller: _ageCtrl, icon: Icons.cake_outlined, keyboardType: TextInputType.number),
                              const SizedBox(height: 14),

                              // Gender
                              const Text('Gender', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13)),
                              const SizedBox(height: 8),
                              Row(
                                  children: [
                                    _GenderChip(label: 'Male', value: 'male', selected: _selectedGender == 'male', onTap: () => setState(() => _selectedGender = 'male')),
                                    const SizedBox(width: 12),
                                    _GenderChip(label: 'Female', value: 'female', selected: _selectedGender == 'female', onTap: () => setState(() => _selectedGender = 'female')),
                                  ],
                              ),
                              const SizedBox(height: 20),
                              // The walkthrough is worth more than a one-time
                              // first-run screen — people forget the daily loop
                              // after a week away, so it stays reachable.
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.system_update_outlined, color: AppTheme.primary),
                                title: const Text('App Updates',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: const Text('Check for a newer version',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () => context.push('/app-updates'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.auto_stories_outlined, color: AppTheme.primary),
                                title: const Text('How to use this app', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () => context.push('/how-to-use'),
                              ),
                              // Admin: announce the running build so every
                              // installation is prompted to update on next open.
                              if (auth.isAdmin)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.inbox_outlined, color: AppTheme.accent),
                                  title: const Text('Support Inbox',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: const Text('Messages from the Contact Us form',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                  onTap: () => context.push('/support-inbox'),
                                ),
                              // Admin: the counselling room. Separate from the
                              // support inbox because a payment waiting on
                              // verification is time-critical in a way a
                              // general enquiry is not.
                              if (auth.isAdmin)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.psychology_alt_outlined, color: AppTheme.accent),
                                  title: const Text('Counselling Sessions',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: const Text('Verify payments, join calls, reply in chat',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                  onTap: () => context.push('/counselling/inbox'),
                                ),
                              // The report queue. Sits beside the other admin
                              // inboxes because it is the same job: something
                              // is waiting on a human.
                              if (auth.isAdmin)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.flag_outlined, color: AppTheme.accent),
                                  title: const Text('Reported content',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: const Text('What members have flagged for review',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                  onTap: () => context.push('/reports'),
                                ),
                              if (auth.isAdmin)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.campaign_outlined, color: AppTheme.accent),
                                  title: const Text('Publish this build as latest',
                                      style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                  onTap: _publishBuild,
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.help_outline_outlined, color: AppTheme.primary),
                                title: const Text('Help & Support Center', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () => context.push('/support'),
                              ),
                              // Deliberately here, in plain sight, rather than
                              // buried behind a support email. Play requires an
                              // in-app route to deletion, and an exit somebody
                              // has to ask permission for is not an exit.
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.no_accounts_outlined, color: AppTheme.danger),
                                title: const Text('Delete my account',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: const Text('Erases everything, permanently',
                                    style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 11)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () => context.push('/delete-account'),
                              ),
                              const Divider(color: Color(0xFF2D2D4E), height: 24),
                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: _isSaving ? null : _saveProfile,
                                      child: Center(
                                        child: _isSaving
                                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('Save Profile', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (auth.isAdmin) ...[
                          const SizedBox(height: 20),
                          _buildAdminPanel(context),
                        ],
                        const SizedBox(height: 30),

                        // Was "Share Brahma with Friends". Until the app is on
                        // a store, sharing it hands someone a link they cannot
                        // install from — an invitation that fails. The
                        // community is where they can actually be told when
                        // that changes.
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openCommunity,
                            icon: const Icon(Icons.groups_outlined, size: 18, color: Colors.white),
                            label: const Text('Join our WhatsApp community',
                                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'InnenFlow is not on the Play Store yet. The community is '
                          'where new builds and updates are announced first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
                        ),

                        const SizedBox(height: 20),
                        // The legal pages, where every app puts them and where
                        // a store review will look for them.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/legal/privacy'),
                              child: const Text('Privacy Policy',
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textSecondary)),
                            ),
                            const Text('·', style: TextStyle(color: AppTheme.textMuted)),
                            TextButton(
                              onPressed: () => context.push('/legal/terms'),
                              child: const Text('Terms of Service',
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: AppTheme.textSecondary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: GestureDetector(
                            onTap: _launchWhatsApp,
                            child: Column(
                              children: [
                                const Text(
                                  'Developed by Shashi Kumar',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+91 8078633912',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: const Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildAdminPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Admin Control Panel',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPushUpdateDialog(context),
              icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
              label: const Text('Push New App Release', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPushUpdateDialog(BuildContext context) {
    final versionCtrl = TextEditingController(text: '1.0.1');
    final buildCtrl = TextEditingController(text: '2');
    final notesCtrl = TextEditingController(text: 'Bug fixes and performance improvements 🚀');
    bool forceUpdate = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Push New App Update', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: versionCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Version (e.g. 1.0.1)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: buildCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Build Number (e.g. 2)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Release Notes'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Force Update?', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 14)),
                  value: forceUpdate,
                  onChanged: (val) {
                    setDialogState(() {
                      forceUpdate = val ?? false;
                    });
                  },
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final buildNum = int.tryParse(buildCtrl.text) ?? 1;
                  // Through the API, which is admin-gated and drops its
                  // cached copy of this key in the same request. `force_update`
                  // is the one lever that can put a blocking banner on every
                  // device, and a Firestore rule could only say "an admin may
                  // write /app_config" — not what shape the value had to be.
                  //
                  // The server merges the object, matching the
                  // `SetOptions(merge: true)` this replaced: a release that
                  // omits a field must not erase the one already published.
                  await ApiService().put('/api/support/config/version', {
                    'value': {
                      'latest_version': versionCtrl.text.trim(),
                      'latest_build': buildNum,
                      'release_notes': notesCtrl.text.trim(),
                      'force_update': forceUpdate,
                      'download_url':
                          'https://appdistribution.firebase.google.com/testerapps/1:440787316408:android:38e64b73850e55b977ce4d',
                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  });

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update published successfully! 🚀', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error publishing: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Publish Release', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;

  const _ProfileField({required this.label, required this.controller, required this.icon, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.2) : AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primary : const Color(0xFF2D2D4E)),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Outfit', color: selected ? AppTheme.primary : AppTheme.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}
