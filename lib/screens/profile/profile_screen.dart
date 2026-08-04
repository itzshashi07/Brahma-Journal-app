import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../models/user_profile.dart';
import '../../core/theme/app_theme.dart';

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
                        // Avatar
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                          ),
                          child: Center(
                            child: Text(
                              profile?.initials ?? auth.user?.email?.substring(0, 1).toUpperCase() ?? 'S',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile?.displayName ?? 'Spiritual Soul',
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
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.help_outline_outlined, color: AppTheme.primary),
                                title: const Text('Help & Support Center', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                                onTap: () => context.push('/support'),
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
