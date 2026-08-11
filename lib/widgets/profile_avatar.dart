import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/constants/modern_avatars.dart';
import '../core/constants/spiritual_avatars.dart';
import '../core/theme/app_theme.dart';
import 'modern_avatar_art.dart';

/// A member's avatar.
///
/// Renders the chosen spiritual avatar; falls back to their initials when they
/// have not picked one. There is no network image path any more — every avatar
/// is vector art bundled with the app, so it draws instantly, never fails to
/// load, and looks identical on every device.
class ProfileAvatar extends StatelessWidget {
  final String? avatarId;
  final String initials;
  final double size;
  final bool showRing;
  final Color ringColor;

  const ProfileAvatar({
    super.key,
    required this.initials,
    this.avatarId,
    this.size = 44,
    this.showRing = false,
    this.ringColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = SpiritualAvatars.byId(avatarId);

    // Two kinds of avatar share one id field: a built one ("m:…") is drawn in
    // code, anything else is a spiritual asset, and an empty id falls back to
    // initials. Checked here so every screen gets both for free.
    if (ModernAvatar.isModern(avatarId)) {
      final built = ModernAvatarArt(
        avatar: ModernAvatar.parse(avatarId),
        size: size,
      );
      return showRing ? _ring(built) : built;
    }

    final inner = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatar == null
            ? _Initials(initials: initials, size: size)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: avatar.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  // Breathing room so the art never touches the circle's edge.
                  padding: EdgeInsets.all(size * 0.18),
                  child: SvgPicture.asset(
                    avatar.asset,
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
      ),
    );

    if (!showRing) return inner;
    return _ring(inner);
  }

  Widget _ring(Widget child) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ringColor, ringColor.withValues(alpha: 0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.bgDark,
        ),
        child: child,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  final double size;
  const _Initials({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.35),
            AppTheme.primaryDark.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}
