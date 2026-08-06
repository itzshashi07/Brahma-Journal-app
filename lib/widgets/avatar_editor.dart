import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/constants/spiritual_avatars.dart';
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
    Navigator.of(context).pop();
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

  void _openPicker() {
    final options = SpiritualAvatars.forGender(widget.gender);
    final current = widget.profile?.avatarId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppTheme.space4),
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            const Text(
              'Choose your avatar',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space2),
            const Text(
              'Change it whenever you like.',
              style: TextStyle(
                  fontFamily: 'Outfit', fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.space5),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppTheme.space3,
                  crossAxisSpacing: AppTheme.space3,
                  childAspectRatio: 0.78,
                ),
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final a = options[i];
                  return _AvatarTile(
                    avatar: a,
                    selected: a.id == current,
                    onTap: () => _choose(a.id),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
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
          'Tap to choose your avatar',
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

class _AvatarTile extends StatelessWidget {
  final SpiritualAvatar avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: avatar.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: SvgPicture.asset(
                  avatar.asset,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space1 + 2),
          Text(
            avatar.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              height: 1.2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppTheme.primaryLight : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
