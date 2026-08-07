import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/affirmation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/affirmation_backgrounds.dart';
import '../../core/constants/app_constants.dart';
import 'dart:math';

class AffirmationsScreen extends StatefulWidget {
  const AffirmationsScreen({super.key});

  @override
  State<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends State<AffirmationsScreen> with SingleTickerProviderStateMixin {
  final AffirmationService _service = AffirmationService();
  List<String> _affirmations = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSpeaking = false;
  final TextEditingController _newAffirmCtrl = TextEditingController();
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
    _loadAffirmations();
  }

  Future<void> _loadAffirmations() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      final affs = await _service.getUserAffirmations(auth.user!.uid);
      setState(() { _affirmations = affs; _isLoading = false; });
      _slideCtrl.forward();
    }
  }

  void _nextAffirmation() {
    _slideCtrl.reset();
    setState(() => _currentIndex = (_currentIndex + 1) % _affirmations.length);
    _slideCtrl.forward();
  }

  void _prevAffirmation() {
    _slideCtrl.reset();
    setState(() => _currentIndex = (_currentIndex - 1 + _affirmations.length) % _affirmations.length);
    _slideCtrl.forward();
  }

  Future<void> _addAffirmation() async {
    final text = _newAffirmCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final newList = [..._affirmations, text];
    await _service.saveUserAffirmations(auth.user!.uid, newList);
    setState(() { _affirmations = newList; _newAffirmCtrl.clear(); });
    if (mounted) Navigator.pop(context);
  }

  /// The practice offered with no explanation is easy to dismiss as wishful
  /// thinking. This gives the mechanisms — and the honest limits.
  void _showWhy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.border),
          ),
          child: ListView(
            controller: controller,
            children: [
              const Text('Why affirmations work',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20,
                      fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              const Text(AffirmationBenefits.intro,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13.5,
                      height: 1.6, color: AppTheme.textSecondary)),
              const SizedBox(height: 22),
              ...AffirmationBenefits.points.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(p.$3, size: 17, color: AppTheme.primaryLight),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$1, style: const TextStyle(fontFamily: 'Outfit',
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                              const SizedBox(height: 3),
                              Text(p.$2, style: const TextStyle(fontFamily: 'Outfit',
                                  fontSize: 12.5, height: 1.55, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(color: AppTheme.border, height: 28),
              const Text('How to practise',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 15,
                      fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              ...AffirmationBenefits.howTo.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('·  ', style: TextStyle(color: AppTheme.primaryLight)),
                        Expanded(child: Text(h, style: const TextStyle(
                            fontFamily: 'Outfit', fontSize: 12.5, height: 1.5,
                            color: AppTheme.textSecondary))),
                      ],
                    ),
                  )),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: const Text(AffirmationBenefits.caveat,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11.5,
                        height: 1.5, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Affirmation', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: TextField(
          controller: _newAffirmCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Outfit'),
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'I am...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addAffirmation, child: const Text('Add')),
        ],
      ),
    );
  }

  List<Color> _getCardColors(int index) {
    final colorSets = [
      [const Color(0xFF7C3AED), const Color(0xFF4338CA)],
      [const Color(0xFF0891B2), const Color(0xFF0E7490)],
      [const Color(0xFF059669), const Color(0xFF047857)],
      [const Color(0xFFD97706), const Color(0xFFB45309)],
      [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
      [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
    ];
    return colorSets[index % colorSets.length];
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _newAffirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteAffirmation(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Affirmation?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to delete this affirmation?', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary)),
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
      final auth = context.read<AuthProvider>();
      final newList = List<String>.from(_affirmations)..removeAt(index);
      await _service.saveUserAffirmations(auth.user!.uid, newList);
      setState(() {
        _affirmations = newList;
        if (_currentIndex >= newList.length && newList.isNotEmpty) {
          _currentIndex = newList.length - 1;
        } else if (newList.isEmpty) {
          _currentIndex = 0;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Affirmation removed.', style: TextStyle(fontFamily: 'Outfit'))),
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
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20), onPressed: () => context.pop()),
                    const Expanded(
                      child: Text('✨ Affirmations', style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                    ),
                    IconButton(
                      tooltip: 'Why affirmations work',
                      icon: const Icon(Icons.help_outline_rounded, color: AppTheme.textMuted),
                      onPressed: _showWhy,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                      onPressed: _showAddDialog,
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (_affirmations.isEmpty)
                const Expanded(child: Center(child: Text('No affirmations yet.\nTap + to add one.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted))))
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Counter
                        Text(
                          '${_currentIndex + 1} of ${_affirmations.length}',
                          style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),

                        // Main Card
                        Expanded(
                          child: SlideTransition(
                            position: _slideAnim,
                            child: FadeTransition(
                              opacity: _slideCtrl,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _getCardColors(_currentIndex),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getCardColors(_currentIndex)[0].withOpacity(0.4),
                                      blurRadius: 24, spreadRadius: 4, offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('✨', style: TextStyle(fontSize: 48)),
                                      const SizedBox(height: 24),
                                      Text(
                                        '"${_affirmations[_currentIndex]}"',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w600,
                                          color: Colors.white, height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _NavBtn(icon: Icons.chevron_left, onTap: _prevAffirmation),
                            const SizedBox(width: 24),
                            // Dots
                            ...List.generate(
                              _affirmations.length > 5 ? 5 : _affirmations.length,
                              (i) {
                                final active = i == (_currentIndex % (_affirmations.length > 5 ? 5 : _affirmations.length));
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: active ? 20 : 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: active ? AppTheme.primary : AppTheme.textMuted,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                            _NavBtn(icon: Icons.chevron_right, onTap: _nextAffirmation),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // All Affirmations List
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('All Affirmations', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _affirmations.length,
                            itemBuilder: (ctx, i) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: i == _currentIndex ? AppTheme.primary.withOpacity(0.15) : AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: i == _currentIndex ? AppTheme.primary.withOpacity(0.4) : const Color(0xFF2D2D4E),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                onTap: () {
                                  _slideCtrl.reset();
                                  setState(() => _currentIndex = i);
                                  _slideCtrl.forward();
                                },
                                title: Text(
                                  _affirmations[i],
                                  style: TextStyle(
                                    fontFamily: 'Outfit', fontSize: 14,
                                    color: i == _currentIndex ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteAffirmation(i),
                                ),
                              ),
                            ),
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2D2D4E)),
        ),
        child: Icon(icon, color: AppTheme.textPrimary),
      ),
    );
  }
}
