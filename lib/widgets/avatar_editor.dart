import 'package:flutter/material.dart';
import 'avatar_picker_sheet.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/avatar_service.dart';
import 'profile_avatar.dart';

/// Tappable avatar that opens the spiritual avatar picker.
///
/// Replaces the camera/gallery upload sheet. The grid is filtered by the
/// member's stated gender so the seated figure matches — but gender is never
/// required, and someone who has not set one simply sees the whole set.
class AvatarEditor extends StatefulWidget {
  final UserProfile? profile;
  final String uid;
  final String initials;
  final String? gender;
  final VoidCallback? onUpdated;

  const AvatarEditor({
    super.key,
    required this.uid,
    required this.initials,
    this.profile,
    this.gender,
    this.onUpdated,
  });

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  final AvatarService _service = AvatarService();
  bool _busy = false;

  Future<void> _choose(String avatarId) async {
    setState(() => _busy = true);
    try {
      await _service.selectAvatar(uid: widget.uid, avatarId: avatarId);
      if (!mounted) return;
      _toast('Avatar updated ✨', AppTheme.success);
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) {
        _toast('Could not change your avatar. Please try again.', AppTheme.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      ),
    );
  }

  Future<void> _openPicker() async {
    final chosen = await AvatarPickerSheet.show(
      context,
      currentId: widget.profile?.avatarId,
      gender: widget.gender,
    );
    if (chosen != null) await _choose(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _busy ? null : _openPicker,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ProfileAvatar(
                avatarId: widget.profile?.avatarId,
                initials: widget.initials,
                size: 104,
                showRing: true,
              ),
              if (_busy)
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    border: Border.all(color: AppTheme.bgDark, width: 2.5),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        const Text(
          'Tap to build your avatar',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
